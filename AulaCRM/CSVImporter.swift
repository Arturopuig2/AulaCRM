import Foundation
import CoreData

struct CSVImporter {

    /// Importa contacto desde `nombreArchivo.csv` (separado por ';')
    /// Implementa estrategia SYNC (Upsert):
    /// 1. Carga existentes. 2. Actualiza si ID coincide. 3. Crea si es nuevo. 4. Borra huérfanos.
    /// Esto evita duplicados y problemas con CloudKit.
    static func reemplazoTotal(desde nombreArchivo: String, contexto ctx: NSManagedObjectContext) -> String {
        print("⚠️ INICIANDO SINCRONIZACIÓN (UPSERT) DE CONTACTOS...")
        var log = ""
        
        // 1. Cargar datos existentes y LIMPIAR DUPLICADOS DE ID
        let fetchRequest: NSFetchRequest<Contacto> = Contacto.fetchRequest()
        var mapaExistentes: [UUID: Contacto] = [:]
        
        do {
            let existentes = try ctx.fetch(fetchRequest)
            for c in existentes {
                if let id = c.id {
                    if let _ = mapaExistentes[id] {
                        // YA EXISTE un contacto con este ID en el mapa -> Es un duplicado en DB
                        ctx.delete(c) // Borrar el duplicado sobrante
                    } else {
                        mapaExistentes[id] = c
                    }
                } else {
                    // Contacto sin ID? Lo borramos o lo ignoramos. Mejor borrar para limpiar.
                    ctx.delete(c) 
                }
            }
            if ctx.hasChanges { try ctx.save() } // Guardar limpieza
            log += "📊 Datos analizados: \(existentes.count). IDs Unicos: \(mapaExistentes.count).\n"
        } catch {
            log += "⚠️ Error leyendo DB actual: \(error.localizedDescription)\n"
        }

        // 2. Leer CSV
        guard let url = Bundle.main.url(forResource: nombreArchivo, withExtension: "csv") else {
            return "❌ ERROR FATAL: No se encuentra \(nombreArchivo).csv."
        }
        
        var texto: String
        var encodingName = "Desconocido"
        
        do {
            texto = try String(contentsOf: url, encoding: .utf8)
            encodingName = "UTF-8"
        } catch {
            // Intentar MacRoman primero basado en la inspección hexadecimal del CSV
            if let t = try? String(contentsOf: url, encoding: .macOSRoman) {
                texto = t
                encodingName = "Mac Roman"
            } else if let t = try? String(contentsOf: url, encoding: .windowsCP1252) {
                texto = t
                encodingName = "Windows CP1252"
            } else if let t = try? String(contentsOf: url, encoding: .isoLatin1) {
                texto = t
                encodingName = "ISO Latin 1"
            } else {
                return "❌ Error Fatal: Codificación de archivo desconocida."
            }
        }
        
        // NORMALIZACIÓN ROBUSTA (RegEx) para "Púb." independientemente de cómo se lea la tilde
        // Busca P, cualquier caracter, y b. (ej: Pœb., Pb., Pb.) y lo fuerza a Púb.
        if let regex = try? NSRegularExpression(pattern: "P.b\\.", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: texto.utf16.count)
            texto = regex.stringByReplacingMatches(in: texto, options: [], range: range, withTemplate: "Púb.")
        }
        // Tambien por si acaso se ha leido sin caracter intermedio (Pb.)
        texto = texto.replacingOccurrences(of: "Pb.", with: "Púb.")
        
        log += "🔤 Codificación: \(encodingName)\n"
        
        // 3. Procesar Líneas (UPSERT)
        let lineas = texto.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lineas.first else { return "❌ CSV vacío." }
            
        let headerCols = parseCSVLine(header).map(normalizaClave)
        let map: [String: String] = [
            "cif":"cif", "ciudad":"ciudad", "cliente":"cliente", "codigo":"codigo",
            "cp":"cp", "direccion":"direccion", "email":"email", "id":"id",
            "lat":"lat", "lng":"lng", "nombre":"nombre", "notas":"notas",
            "provincia":"provincia", "regimen":"regimen", "telefono":"telefono", "teléfono":"telefono"
        ]

        let datos = lineas.dropFirst()
        var procesados = 0
        var nuevos = 0
        var actualizados = 0
        var idsProcesados = Set<UUID>()

        for fila in datos {
            let cols = parseCSVLine(fila)
            if cols.isEmpty { continue }

            // Buscar ID en esta fila para saber si es update o insert
            var csvUUID: UUID? = nil
            // Pre-escaneo para encontrar ID
            for (idx, valorCrudo) in cols.enumerated() {
                if idx < headerCols.count {
                    let clave = headerCols[idx]
                    if map[clave] == "id", let u = UUID(uuidString: valorCrudo.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        csvUUID = u
                        break
                    }
                }
            }
            
            // Si no hay ID en CSV, generamos uno nuevo
            if csvUUID == nil { csvUUID = UUID() }
            
            // BÚSQUEDA ROBUSTA (Estable para multi-dispositivo)
            // Si el ID del CSV es nuevo o nulo, probamos por Código o CIF antes de crear
            var codigoFila = ""
            var cifFila = ""
            
            for (idx, valorCrudo) in cols.enumerated() where idx < headerCols.count {
                let clave = headerCols[idx]
                let valor = valorCrudo.trimmingCharacters(in: .whitespacesAndNewlines)
                if map[clave] == "codigo" { codigoFila = valor }
                if map[clave] == "cif" { cifFila = valor }
            }
            
            let contacto: Contacto
            if let uuid = csvUUID, let existente = mapaExistentes[uuid] {
                contacto = existente
                actualizados += 1
            } else {
                // Si no hay por UUID, buscamos por CODIGO o CIF en los datos ya cargados
                var encontradoPorAlternativa: Contacto? = nil
                
                if !codigoFila.isEmpty {
                    encontradoPorAlternativa = mapaExistentes.values.first(where: { ($0.codigo ?? "") == codigoFila })
                }
                
                if encontradoPorAlternativa == nil && !cifFila.isEmpty {
                    encontradoPorAlternativa = mapaExistentes.values.first(where: { ($0.cif ?? "") == cifFila })
                }
                
                if let existente = encontradoPorAlternativa {
                    contacto = existente
                    // Actualizamos su ID al que diga el CSV (o el generado) para unificar
                    contacto.id = csvUUID
                    actualizados += 1
                    // Actualizar mapa para futuras pasadas
                    if let uid = csvUUID { mapaExistentes[uid] = contacto }
                } else {
                    contacto = Contacto(context: ctx)
                    contacto.id = csvUUID
                    nuevos += 1
                    // Actualizar mapa para futuras pasadas
                    if let uid = csvUUID { mapaExistentes[uid] = contacto }
                }
            }
            if let uid = contacto.id { idsProcesados.insert(uid) }

            // Asignar campos
            for (idx, valorCrudo) in cols.enumerated() {
                guard idx < headerCols.count else { continue }
                let clave = headerCols[idx]
                guard let atributo = map[clave] else { continue }

                let valor = valorCrudo.trimmingCharacters(in: .whitespacesAndNewlines)
                if valor.isEmpty { continue }
                
                switch atributo {
                case "id": break // Ya gestionado
                case "lat": if let d = parseDouble(valor) { contacto.lat = d }
                case "lng": if let d = parseDouble(valor) { contacto.lng = d }
                case "cliente": contacto.cliente = parseBoolFlexible(valor)
                default: contacto.setValue(valor, forKey: atributo)
                }
            }
            procesados += 1
        }
        
        // 4. Borrar Huérfanos (estaban en DB pero NO en CSV)
        var borrados = 0
        for (uuid, contacto) in mapaExistentes {
            if !idsProcesados.contains(uuid) {
                ctx.delete(contacto)
                borrados += 1
            }
        }
        
        do {
            if ctx.hasChanges { try ctx.save() }
            log += "✅ Sincronización OK.\n🆕 Nuevos: \(nuevos)\n🔄 Actualizados: \(actualizados)\n🗑️ Borrados (huérfanos): \(borrados)"
            print(log)
            return log
        } catch {
            return "❌ Error guardando cambios: \(error.localizedDescription)"
        }
    }

    // MARK: - Utilidades

    /// Parser CSV para separador TABULADOR `\t` que respeta comillas dobles
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "\t" && !inQuotes { // CAMBIO: Usar TAB en lugar de ;
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }

    private static nonisolated func normalizaClave(_ s: String) -> String {
        let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sinTilde = lower.folding(options: .diacriticInsensitive, locale: .current)
        return sinTilde.replacingOccurrences(of: " ", with: "")
    }

    private static func parseDouble(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: ".")
        return Double(t)
    }

    private static func parseBoolFlexible(_ s: String) -> Bool {
        let v = normalizaClave(s)
        return v == "true" || v == "1" || v == "si" || v == "sí" || v == "y" || v == "yes"
    }

    /// Importa productos desde `nombreArchivo.csv` (separado por ';') con UPSERT por ISBN normalizado
    static func importarProductos(desde nombreArchivo: String, contexto ctx: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: nombreArchivo, withExtension: "csv") else {
            print("⚠️ No se encontró \(nombreArchivo).csv en el bundle")
            return
        }

        // Normaliza ISBN (minúsculas + solo alfanuméricos)
        func normalizeISBN(_ s: String) -> String {
            let lowered = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let scalars = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            return String(String.UnicodeScalarView(scalars))
        }

        do {
            let texto = try String(contentsOf: url, encoding: .utf8)
            let lineas = texto.split(whereSeparator: \.isNewline).map(String.init)
            guard let header = lineas.first else { print("⚠️ CSV de Producto sin cabecera"); return }

            // Cabecera → claves normalizadas
            let headerCols = parseCSVLine(header).map(normalizaClave)
            
            var importados = 0
            var vistosEnEstaCarga = Set<String>()

            for fila in lineas.dropFirst() {
                let cols = parseCSVLine(fila)
                if cols.isEmpty { continue }

                // Construir diccionario clave→valor de la fila
                var row: [String:String] = [:]
                for (idx, raw) in cols.enumerated() where idx < headerCols.count {
                    row[headerCols[idx]] = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Clave de upsert: ISBN normalizado
                let isbnRaw = row["isbn"] ?? ""
                let isbnKey = normalizeISBN(isbnRaw)
                if isbnKey.isEmpty { continue }
                if vistosEnEstaCarga.contains(isbnKey) { continue } // evita duplicados en el mismo CSV
                vistosEnEstaCarga.insert(isbnKey)

                // Buscar existente
                let req = NSFetchRequest<NSManagedObject>(entityName: "Producto")
                req.predicate = NSPredicate(format: "isbn == %@", isbnKey)
                req.fetchLimit = 1

                let producto: NSManagedObject
                if let existente = (try? ctx.fetch(req))?.first {
                    producto = existente
                    // UPSERT: Actualizar existente
                } else {
                    producto = NSEntityDescription.insertNewObject(forEntityName: "Producto", into: ctx)
                }

                // Setear campos
                producto.setValue(isbnKey, forKey: "isbn")
                if let v = row["nombre"], !v.isEmpty { producto.setValue(v, forKey: "nombre") }
                if let v = row["asignatura"], !v.isEmpty { producto.setValue(v, forKey: "asignatura") }
                if let v = row["curso"], !v.isEmpty { producto.setValue(v, forKey: "curso") }
                if let v = row["depositolegal"], !v.isEmpty { producto.setValue(v, forKey: "depositolegal") }
                if let v = row["notas"], !v.isEmpty { producto.setValue(v, forKey: "notas") }

                if let pText = row["precio"], let p = parseDouble(pText) {
                    producto.setValue(p, forKey: "precio")
                }
                if let sText = row["stock"], let s = Int16(sText) {
                    producto.setValue(s, forKey: "stock")
                }

                // UUID opcional si lo llevas en CSV
                if let idText = row["id"], let uuid = UUID(uuidString: idText) {
                    producto.setValue(uuid, forKey: "id")
                } else if (producto.value(forKey: "id") as? UUID) == nil {
                    producto.setValue(UUID(), forKey: "id")
                }

                importados += 1
            }

            if ctx.hasChanges { try ctx.save() }
            print("✅ Importación de productos completada: \(importados) filas procesadas")

        } catch {
            print("❌ Error importando productos: \(error.localizedDescription)")
        }
    }

    // MARK: - Limpieza de Duplicados
    
    /// Elimina duplicados basándose en CIF (prioritario) o combinación de Nombre + Ciudad
    static func eliminarDuplicadosReales(ctx: NSManagedObjectContext) {
        let req: NSFetchRequest<Contacto> = Contacto.fetchRequest()
        // Ordenamos por fecha de creación o ID para mantener el más "antiguo" o con más info si fuera posible, 
        // pero aquí solo tenemos el orden de fetch por ahora.
        
        do {
            let todos = try ctx.fetch(req)
            var vistosCIF: Set<String> = []
            var vistosNombreCiudad: Set<String> = []
            var eliminados = 0

            for c in todos {
                let cif = (c.cif ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let nombre = (c.nombre ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let ciudad = (c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                let keyNombreCiudad = "\(nombre)|\(ciudad)"
                
                var esDuplicado = false
                
                // 1. Verificar por CIF si existe
                if !cif.isEmpty {
                    if vistosCIF.contains(cif) {
                        esDuplicado = true
                    } else {
                        vistosCIF.insert(cif)
                        // Si tiene CIF, también marcamos nombre+ciudad para evitar duplicados mixtos
                        if !nombre.isEmpty { vistosNombreCiudad.insert(keyNombreCiudad) }
                    }
                } 
                // 2. Si no tiene CIF o no es duplicado por CIF, verificar por Nombre + Ciudad
                else if !nombre.isEmpty {
                    if vistosNombreCiudad.contains(keyNombreCiudad) {
                        esDuplicado = true
                    } else {
                        vistosNombreCiudad.insert(keyNombreCiudad)
                    }
                }

                if esDuplicado {
                    ctx.delete(c)
                    eliminados += 1
                }
            }
            
            if ctx.hasChanges {
                try ctx.save()
            }
            if eliminados > 0 {
                print("🧹 LIMPIEZA: Se han eliminado \(eliminados) contactos duplicados.")
            }
        } catch {
            print("❌ Error al eliminar duplicados:", error.localizedDescription)
        }
    }
}
