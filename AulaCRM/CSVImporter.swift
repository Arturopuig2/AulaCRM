import Foundation
import CoreData

struct CSVImporter {

    /// Importa contacto desde `nombreArchivo.csv` (separado por ';')
    static func importarContactos(desde nombreArchivo: String, contexto ctx: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: nombreArchivo, withExtension: "csv") else {
            print("⚠️ No se encontró \(nombreArchivo).csv en el bundle")
            return
        }

        do {
            let texto = try String(contentsOf: url, encoding: .utf8)
            let lineas = texto.split(whereSeparator: \.isNewline).map(String.init)
            guard let header = lineas.first else { print("⚠️ CSV sin cabecera"); return }

            // Cabecera → claves normalizadas
            let headerCols = parseCSVLine(header).map(normalizaClave)

            // Mapeo cabecera → atributo Core Data
            let map: [String: String] = [
                "cif":"cif",
                "ciudad":"ciudad",
                "cliente":"cliente",
                "codigo":"codigo",
                "cp":"cp",
                "direccion":"direccion",
                "email":"email",
                "id":"id",
                "lat":"lat",
                "lng":"lng",
                "nombre":"nombre",
                "notas":"notas",
                "provincia":"provincia",
                "regimen":"regimen",
                "telefono":"telefono",
                "teléfono":"teléfono"
            ]

            let datos = lineas.dropFirst()
            var importados = 0

            for fila in datos {
                let cols = parseCSVLine(fila)
                if cols.isEmpty { continue }

                let contacto = Contacto(context: ctx)

                for (idx, valorCrudo) in cols.enumerated() {
                    guard idx < headerCols.count else { continue }
                    let clave = headerCols[idx]
                    guard let atributo = map[clave] else { continue }

                    let valor = valorCrudo.trimmingCharacters(in: .whitespacesAndNewlines)

                    switch atributo {
                    case "id":
                        if let uuid = UUID(uuidString: valor) {
                            contacto.setValue(uuid, forKey: "id")
                        }
                    case "lat", "lng":
                        if let d = parseDouble(valor) {
                            contacto.setValue(d, forKey: atributo)
                        }
                    case "cliente":
                        let b = parseBoolFlexible(valor)
                        contacto.setValue(b, forKey: "cliente")
                    default:
                        if !valor.isEmpty {
                            contacto.setValue(valor, forKey: atributo)
                        }
                    }
                }

                if contacto.value(forKey: "id") == nil {
                    contacto.setValue(UUID(), forKey: "id")
                }

                importados += 1
            }

            try ctx.save()
            print("✅ Importación completada: \(importados) contacto")

        } catch {
            print("❌ Error importando CSV: \(error.localizedDescription)")
        }
    }

    // MARK: - Utilidades

    /// Parser CSV para separador `;` que respeta comillas dobles
    nonisolated private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == ";" && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }

    nonisolated private static func normalizaClave(_ s: String) -> String {
        let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sinTilde = lower.folding(options: .diacriticInsensitive, locale: .current)
        return sinTilde.replacingOccurrences(of: " ", with: "")
    }

    nonisolated private static func parseDouble(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: ".")
        return Double(t)
    }

    nonisolated private static func parseBoolFlexible(_ s: String) -> Bool {
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

            // Mapeo cabecera → atributo Core Data (ajústalo si tus nombres varían)
           /*
            let map: [String: String] = [
                "id":"id",
                "isbn":"isbn",
                "nombre":"nombre",
                "asignatura":"asignatura",
                "curso":"curso",
                "precio":"precio",
                "depositolegal":"depositolegal",
                "stock":"stock",
                "notas":"notas"
            ]
            */

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
    
    /// Elimina duplicados basándose en CIF (si existe) o Nombre
    static func eliminarDuplicadosReales(ctx: NSManagedObjectContext) {
        let req: NSFetchRequest<Contacto> = Contacto.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]

        do {
            let todos = try ctx.fetch(req)
            var vistos: Set<String> = []
            var eliminados = 0

            for c in todos {
                // Prioridad: CIF. Si no, Nombre.
                let rawKey = (c.cif ?? "").isEmpty ? (c.nombre ?? "") : (c.cif ?? "")
                let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                guard !key.isEmpty else { continue }

                if vistos.contains(key) {
                    // Es un duplicado -> Borrar
                    ctx.delete(c)
                    eliminados += 1
                } else {
                    vistos.insert(key)
                }
            }
            
            if ctx.hasChanges {
                try ctx.save()
            }
            if eliminados > 0 {
                print("🧹 LIMPIEZA: Se han eliminado \(eliminados) contactos duplicados.")
            } else {
                print("✨ Base de datos limpia de duplicados.")
            }

        } catch {
            print("❌ Error al eliminar duplicados:", error.localizedDescription)
        }
    }

}



//ELIMINAR DUPLICADOS

