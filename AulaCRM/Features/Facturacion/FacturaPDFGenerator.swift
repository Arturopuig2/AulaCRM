import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import CoreData
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Modelos de datos planos (sin Core Data)

struct FacturaPDFData {
    let numero: String
    let fecha: Date?
    let clienteNombre: String
    let clienteDireccion: String
    let clienteCP: String
    let clienteCiudad: String
    let clienteProvincia: String
    let clienteCIF: String
    let baseImponible: Double
    let iva: Double
    let total: Double
    let notas: String
    let emisor: String
    let lineas: [LineaFacturaPDFData]
}

struct LineaFacturaPDFData: Identifiable, Hashable {
    let id = UUID()
    let productoNombre: String
    let isbn: String
    let cantidad: Int
    let precioUnitario: Double
    let total: Double
}

// MARK: - Generador principal

struct FacturaPDFGenerator {

    // Mapeo de NSManagedObject a struct plano — llamar siempre desde el hilo principal
    static func mapFacturaToData(_ factura: Factura) -> FacturaPDFData {
        var lineasData: [LineaFacturaPDFData] = []
        if let lineas = factura.lineas as? Set<LineaFactura> {
            lineasData = lineas
                .sorted { ($0.productoNombre ?? "") < ($1.productoNombre ?? "") }
                .map { linea in
                    var isbnValue = (linea.value(forKey: "isbn") as? String) ?? ""
                    
                    // Fallback para facturas antiguas: si no tiene ISBN, lo buscamos en el catálogo de productos
                    if isbnValue.isEmpty, let nombre = linea.productoNombre {
                        let request = NSFetchRequest<NSManagedObject>(entityName: "Producto")
                        request.predicate = NSPredicate(format: "nombre == %@", nombre)
                        request.fetchLimit = 1
                        if let productos = try? linea.managedObjectContext?.fetch(request),
                           let p = productos.first {
                            isbnValue = (p.value(forKey: "isbn") as? String) ?? ""
                        }
                    }
                    
                    return LineaFacturaPDFData(
                        productoNombre: linea.productoNombre ?? "—",
                        isbn: isbnValue,
                        cantidad: Int(linea.cantidad),
                        precioUnitario: linea.precioUnitario,
                        total: linea.total
                    )
                }
        }
        return FacturaPDFData(
            numero: factura.numero ?? "S-N",
            fecha: factura.fecha,
            clienteNombre: factura.clienteNombre ?? "—",
            clienteDireccion: factura.clienteDireccion ?? "",
            clienteCP: factura.clienteCP ?? "",
            clienteCiudad: factura.clienteCiudad ?? "",
            clienteProvincia: factura.clienteProvincia ?? "",
            clienteCIF: factura.clienteCIF ?? "",
            baseImponible: factura.baseImponible,
            iva: factura.iva,
            total: factura.total,
            notas: factura.notas ?? "",
            emisor: (factura.value(forKey: "emisor") as? String) ?? "Aula",
            lineas: lineasData
        )
    }

    static func safeFilename(factura: Factura) -> String {
        let rawNum = factura.numero ?? "S-N"
        let safeNum = rawNum
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return "Factura_\(safeNum).pdf"
    }

    // MARK: macOS: CoreGraphics puro — sin NSHostingController, sin Tasks de SwiftUI
    #if os(macOS)
    static func createPDFMac(facturaData: FacturaPDFData) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.27, height: 841.89)
        let margin: CGFloat = 40
        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData) else { return Data() }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        let prevNS = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        ctx.beginPDFPage(nil)

        // Colores y fuentes macOS
        let black    = NSColor.black
        let gray     = NSColor(white: 0.5, alpha: 1)
        let lgray    = NSColor(white: 0.92, alpha: 1)
        let blue     = NSColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1)
        let f8       = NSFont.systemFont(ofSize: 8)
        let f9       = NSFont.systemFont(ofSize: 9)
        let f11      = NSFont.systemFont(ofSize: 11)
        let fb9      = NSFont.boldSystemFont(ofSize: 9)
        let fb11     = NSFont.boldSystemFont(ofSize: 11)
        let fb14     = NSFont.boldSystemFont(ofSize: 14)
        let fb18     = NSFont.boldSystemFont(ofSize: 18)

        let H = pageRect.height
        // cgY convierte "y desde arriba" a coordenada CoreGraphics (desde abajo)
        func cgY(_ fromTop: CGFloat, _ h: CGFloat = 0) -> CGFloat { H - fromTop - h }
        func txt(_ s: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                 font: NSFont, color: NSColor, align: NSTextAlignment = .left, wrap: Bool = false) {
            let ps = NSMutableParagraphStyle()
            ps.alignment = align
            ps.lineBreakMode = wrap ? .byWordWrapping : .byTruncatingTail
            NSString(string: s).draw(in: CGRect(x: x, y: cgY(y, h), width: w, height: h),
                                     withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: ps])
        }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, color: NSColor) {
            ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(0.5)
            ctx.move(to: .init(x: x1, y: y1)); ctx.addLine(to: .init(x: x2, y: y2)); ctx.strokePath()
        }

        let dateStr: String = {
            guard let d = facturaData.fecha else { return "—" }
            let f = DateFormatter(); f.dateStyle = .short; f.locale = Locale(identifier: "es_ES")
            return f.string(from: d)
        }()

        var y: CGFloat = margin
        let esItbook = facturaData.emisor == "Itbook"
        let logoName = esItbook ? "logo_itbook" : "logo_aula"

        let logoImage: NSImage? = NSImage(named: logoName)
            ?? Bundle.main.url(forResource: logoName, withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
            ?? Bundle.main.url(forResource: logoName, withExtension: "jpg")
                .flatMap { NSImage(contentsOf: $0) }

        // Logo a la DERECHA
        let lh: CGFloat = esItbook ? 50 : 120 // Itbook más pequeño (50), Aula original (120)
        let logoYOffset: CGFloat = esItbook ? -15 : -45 // Bajar Itbook para que no se corte
        if let logo = logoImage {
            let lw = lh * (logo.size.width / logo.size.height)
            logo.draw(in: CGRect(x: pageRect.width - margin - lw, y: cgY(y + logoYOffset, lh), width: lw, height: lh))
        } else {
            txt(esItbook ? "ITBOOK" : "AULA", x: pageRect.width - margin - 120, y: y, w: 120, h: 40,
                font: NSFont.boldSystemFont(ofSize: 36), color: blue, align: .right)
        }

        // Datos fiscales a la IZQUIERDA
        var ey = y
        let fiscalW: CGFloat = 260
        if esItbook {
            txt("ITBOOK EDITORIAL SL",          x: margin, y: ey, w: fiscalW, h: 14, font: fb11, color: black); ey += 15
            txt("C/ Hierros 14 D. Puerta 6",    x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("46022 València",               x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("CIF: B98263023",               x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray)
        } else {
            txt("Editorial Aula sl",          x: margin, y: ey, w: fiscalW, h: 14, font: fb11, color: black); ey += 15
            txt("C/ Hierros 14 D. Puerta 6",  x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("46022 Valencia",               x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("CIF: B19994326",               x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("Tel: 669 141 263",             x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray);  ey += 13
            txt("info@editorialaula.es",        x: margin, y: ey, w: fiscalW, h: 12, font: f9,   color: gray)
        }
        y += max(lh - 20, 100)
        // No hay llamadas a line() aquí

        // ── DATOS FACTURA + CLIENTE ───────────────────────────────────────────
        let tituloDoc = facturaData.numero == "Muestra" ? "SALIDA DE MUESTRAS" : "FACTURA"
        txt(tituloDoc, x: margin, y: y, w: 400, h: 20, font: fb18, color: black); y += 22
        txt("Nº: \(facturaData.numero)", x: margin, y: y, w: 250, h: 14, font: fb11, color: black); y += 16
        txt("Fecha: \(dateStr)",          x: margin, y: y, w: 250, h: 13, font: f11,  color: black)

        let cx = pageRect.width / 2 + 10; var cy = y - 32; let cw = pageRect.width - margin - cx
        txt("CLIENTE",                  x: cx, y: cy, w: cw, h: 12, font: fb9,  color: gray); cy += 14
        txt(facturaData.clienteNombre,  x: cx, y: cy, w: cw, h: 15, font: fb11, color: black); cy += 16
        if !facturaData.clienteDireccion.isEmpty { txt(facturaData.clienteDireccion, x: cx, y: cy, w: cw, h: 12, font: f9, color: black); cy += 13 }
        let loc = "\(facturaData.clienteCP) \(facturaData.clienteCiudad)".trimmingCharacters(in: .whitespaces)
        if !loc.isEmpty { txt(loc, x: cx, y: cy, w: cw, h: 12, font: f9, color: black); cy += 13 }
        if !facturaData.clienteProvincia.isEmpty { txt(facturaData.clienteProvincia, x: cx, y: cy, w: cw, h: 12, font: f9, color: black); cy += 13 }
        if !facturaData.clienteCIF.isEmpty { txt("CIF/NIF: \(facturaData.clienteCIF)", x: cx, y: cy, w: cw, h: 12, font: f9, color: black) }

        y += 70 // Aumentamos espacio entre cliente y tabla
        // ── TABLA ─────────────────────────────────────────────────────────────
        let c0 = margin, c1: CGFloat = 370, c2: CGFloat = 430, c3: CGFloat = 510
        let tw = pageRect.width - margin * 2
        ctx.setFillColor(lgray.cgColor); ctx.fill(CGRect(x: margin, y: cgY(y, 20), width: tw, height: 20))
        txt("Descripción", x: c0+4, y: y+4, w: 300, h: 12, font: fb9, color: black)
        txt("Cant.",   x: c1, y: y+4, w: 55,                       h: 12, font: fb9, color: black, align: .center)
        if facturaData.numero != "Muestra" {
            txt("Precio",  x: c2, y: y+4, w: 70,                       h: 12, font: fb9, color: black, align: .right)
            txt("Total",   x: c3, y: y+4, w: pageRect.width-margin-c3, h: 12, font: fb9, color: black, align: .right)
        }
        y += 20; line(margin, cgY(y), pageRect.width - margin, cgY(y), color: gray.withAlphaComponent(0.4))

        for (i, l) in facturaData.lineas.enumerated() {
            let rowH: CGFloat = l.isbn.isEmpty ? 20 : 28
            if i % 2 == 1 { ctx.setFillColor(NSColor(white: 0.97, alpha: 1).cgColor); ctx.fill(CGRect(x: margin, y: cgY(y, rowH), width: tw, height: rowH)) }
            txt(l.productoNombre, x: c0+4, y: y+4, w: 300, h: 12, font: f9, color: black)
            if !l.isbn.isEmpty {
                txt("ISBN: \(l.isbn)", x: c0+4, y: y+16, w: 300, h: 10, font: NSFont.systemFont(ofSize: 8), color: gray)
            }
            txt("\(l.cantidad)",                          x: c1, y: y+4, w: 55,                        h: 12, font: f9, color: black, align: .center)
            if facturaData.numero != "Muestra" {
                txt(String(format: "%.2f €", l.precioUnitario), x: c2, y: y+4, w: 70,                     h: 12, font: f9, color: black, align: .right)
                txt(String(format: "%.2f €", l.total),        x: c3, y: y+4, w: pageRect.width-margin-c3, h: 12, font: f9, color: black, align: .right)
            }
            y += rowH; line(margin, cgY(y), pageRect.width - margin, cgY(y), color: lgray)
        }
        y += 16

        // ── TOTALES ───────────────────────────────────────────────────────────
        if facturaData.numero != "Muestra" {
            let tx: CGFloat = 340; let tw2 = pageRect.width - margin - tx
            txt("Base Imponible:", x: tx, y: y, w: 110, h: 14, font: f11,  color: black)
            txt(String(format: "%.2f €", facturaData.baseImponible), x: tx+115, y: y, w: tw2-115, h: 14, font: fb11, color: black, align: .right); y += 17
            txt("IVA (\(Int(facturaData.iva*100))%):", x: tx, y: y, w: 110, h: 14, font: f11, color: black)
            txt(String(format: "%.2f €", facturaData.iva * facturaData.baseImponible), x: tx+115, y: y, w: tw2-115, h: 14, font: fb11, color: black, align: .right)
            y += 4; line(tx, cgY(y+14), pageRect.width-margin, cgY(y+14), color: gray.withAlphaComponent(0.5)); y += 18
            txt("TOTAL:", x: tx, y: y, w: 110, h: 18, font: fb14, color: black)
            txt(String(format: "%.2f €", facturaData.total), x: tx+115, y: y, w: tw2-115, h: 18, font: fb14, color: blue, align: .right)
        }

        // ── PIE ───────────────────────────────────────────────────────────────
        // line(margin, footerTop, pageRect.width - margin, footerTop, color: NSColor.orange) // Línea naranja eliminada a petición del usuario
        if !facturaData.notas.isEmpty {
            txt("NOTAS: \(facturaData.notas)", x: margin, y: H-margin-88,
                w: pageRect.width-margin*2, h: 14, font: f8, color: gray)
        }
        txt("FORMA DE PAGO: Transferencia bancaria",  x: margin, y: H-margin-60, w: 400, h: 12, font: fb9, color: black)
        let cuenta = esItbook ? "ES10 0075 0164 92 0600701155" : "ES52 0049 5444 1120 1675 1590"
        txt("Nº DE CUENTA: \(cuenta)", x: margin, y: H-margin-44, w: 430, h: 14, font: fb11, color: black)
        // Texto LOPD con wrap y altura suficiente para las 2 líneas
        let nombreEmisorLOPD = esItbook ? "Itbook Editorial SL" : "Editorial Aula SL"
        let lopdText = "De acuerdo con la normativa vigente en materia de protección de datos personales (RGPD y LOPDGDD), le informamos que sus datos serán tratados por \(nombreEmisorLOPD) con la finalidad de gestionar la relación comercial establecida."
        txt(lopdText, x: margin, y: H-margin-30,
            w: pageRect.width - margin * 2, h: 28, font: f8, color: gray, wrap: true)

        ctx.endPDFPage(); ctx.closePDF()
        NSGraphicsContext.current = prevNS
        return mutableData as Data
    }
    #endif

    // MARK: iOS: generar URL con CoreGraphics puro (sin SwiftUI)
    #if os(iOS)
    @MainActor // mantenemos @MainActor solo aquí porque accede a Core Data (Factura es NSManagedObject del viewContext)
    static func generatePDFURL(factura: Factura) -> URL? {
        let data = mapFacturaToData(factura)
        let pdfData = createPDFiOS(facturaData: data)
        let filename = safeFilename(factura: factura)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    /// Genera el PDF usando únicamente CoreGraphics — sin SwiftUI, sin UIHostingController,
    /// sin dependencias de escena o ventana. Es la única forma garantizada de no crashear en iOS.
    static func createPDFiOS(facturaData: FacturaPDFData) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.27, height: 841.89)
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let dateStr: String = {
            guard let d = facturaData.fecha else { return "—" }
            let f = DateFormatter()
            f.dateStyle = .short
            f.locale = Locale(identifier: "es_ES")
            return f.string(from: d)
        }()

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext

            // Colores
            let black = UIColor.black
            let gray  = UIColor(white: 0.5, alpha: 1)
            let lightGray = UIColor(white: 0.92, alpha: 1)
            let blue  = UIColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1)

            // Fuentes
            let fontBold14 = UIFont.boldSystemFont(ofSize: 14)
            let fontBold11 = UIFont.boldSystemFont(ofSize: 11)
            let fontBold9  = UIFont.boldSystemFont(ofSize: 9)
            let font11 = UIFont.systemFont(ofSize: 11)
            let font9  = UIFont.systemFont(ofSize: 9)
            let font8  = UIFont.systemFont(ofSize: 8)

            var y = margin

            // ─── CABECERA: datos fiscales IZQUIERDA, logo DERECHA ──────────────────
            let esItbook = facturaData.emisor == "Itbook"
            let logoName = esItbook ? "logo_itbook" : "logo_aula"
            
            let logoH: CGFloat = esItbook ? 50 : 120
            let logoYOffset: CGFloat = esItbook ? -15 : -45
            if let logo = UIImage(named: logoName) {
                let ratio = logo.size.width / logo.size.height
                let logoW = logoH * ratio
                let logoRect = CGRect(x: pageRect.width - margin - logoW, y: y + logoYOffset, width: logoW, height: logoH)
                logo.draw(in: logoRect)
            } else {
                draw(esItbook ? "ITBOOK" : "AULA", in: CGRect(x: pageRect.width - margin - 120, y: y, width: 120, height: 40),
                     font: UIFont.boldSystemFont(ofSize: 36), color: blue, align: .right)
            }

            // Datos emisor (izquierda)
            var emisorY = y
            let emisorW: CGFloat = 260
            if esItbook {
                draw("ITBOOK EDITORIAL SL", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 14),
                     font: fontBold11, color: black)
                emisorY += 15
                draw("C/ Hierros 14 D. Puerta 6", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("46022 València", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("CIF: B98263023", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
            } else {
                draw("Editorial Aula sl", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 14),
                     font: fontBold11, color: black)
                emisorY += 15
                draw("C/ Hierros 14 D. Puerta 6", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("46022 Valencia", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("CIF: B19994326", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("Tel: 669 141 263", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
                emisorY += 13
                draw("info@editorialaula.es", in: CGRect(x: margin, y: emisorY, width: emisorW, height: 12),
                     font: font9, color: gray)
            }

            y += max(logoH - 20, 100)
            
            // ─── DATOS FACTURA + CLIENTE ──────────────────────────────
            // Izquierda: número y fecha
            let tituloDoc = facturaData.numero == "Muestra" ? "SALIDA DE MUESTRAS" : "FACTURA"
            draw(tituloDoc, in: CGRect(x: margin, y: y, width: 400, height: 20),
                 font: UIFont.boldSystemFont(ofSize: 18), color: black)
            y += 22
            draw("Nº: \(facturaData.numero)", in: CGRect(x: margin, y: y, width: 250, height: 14),
                 font: fontBold11, color: black)
            y += 16
            draw("Fecha: \(dateStr)", in: CGRect(x: margin, y: y, width: 250, height: 13),
                 font: font11, color: black)

            // Derecha: datos del cliente
            let clienteX = pageRect.width / 2 + 10
            var clienteY = y - 32
            let clienteW = pageRect.width - margin - clienteX

            draw("CLIENTE", in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 12),
                 font: fontBold9, color: gray)
            clienteY += 14
            draw(facturaData.clienteNombre, in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 15),
                 font: fontBold11, color: black)
            clienteY += 16
            if !facturaData.clienteDireccion.isEmpty {
                draw(facturaData.clienteDireccion, in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 12),
                     font: font9, color: black)
                clienteY += 13
            }
            let localidad = "\(facturaData.clienteCP) \(facturaData.clienteCiudad)".trimmingCharacters(in: .whitespaces)
            if !localidad.isEmpty {
                draw(localidad, in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 12),
                     font: font9, color: black)
                clienteY += 13
            }
            if !facturaData.clienteProvincia.isEmpty {
                draw(facturaData.clienteProvincia, in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 12),
                     font: font9, color: black)
                clienteY += 13
            }
            if !facturaData.clienteCIF.isEmpty {
                draw("CIF/NIF: \(facturaData.clienteCIF)", in: CGRect(x: clienteX, y: clienteY, width: clienteW, height: 12),
                     font: font9, color: black)
            }

            y += 60 // Más espacio entre cliente y tabla

            // ─── TABLA DE PRODUCTOS ───────────────────────────────────
            y += 10
            let col0x = margin          // Descripción
            let col1x: CGFloat = 370    // Cant.
            let col2x: CGFloat = 430    // Precio
            let col3x: CGFloat = 510    // Total
            let tableW = pageRect.width - margin * 2

            // Header row
            let headerRect = CGRect(x: margin, y: y, width: tableW, height: 20)
            cgCtx.setFillColor(lightGray.cgColor)
            cgCtx.fill(headerRect)

            draw("Descripción", in: CGRect(x: col0x + 4, y: y + 4, width: 300, height: 12),
                 font: fontBold9, color: black)
            draw("Cant.", in: CGRect(x: col1x, y: y + 4, width: 55, height: 12),
                 font: fontBold9, color: black, align: .center)
            
            if facturaData.numero != "Muestra" {
                draw("Precio", in: CGRect(x: col2x, y: y + 4, width: 70, height: 12),
                     font: fontBold9, color: black, align: .right)
                draw("Total", in: CGRect(x: col3x, y: y + 4, width: pageRect.width - margin - col3x, height: 12),
                     font: fontBold9, color: black, align: .right)
            }
            y += 20
            drawLine(cgCtx, x1: margin, y1: y, x2: pageRect.width - margin, y2: y, color: gray.withAlphaComponent(0.4))

            // Filas
            for (i, linea) in facturaData.lineas.enumerated() {
                let rowY = y
                let rowH: CGFloat = linea.isbn.isEmpty ? 20 : 28
                if i % 2 == 1 {
                    cgCtx.setFillColor(UIColor(white: 0.97, alpha: 1).cgColor)
                    cgCtx.fill(CGRect(x: margin, y: rowY, width: tableW, height: rowH))
                }
                draw(linea.productoNombre, in: CGRect(x: col0x + 4, y: rowY + 4, width: 300, height: 12),
                     font: font9, color: black)
                if !linea.isbn.isEmpty {
                    draw("ISBN: \(linea.isbn)", in: CGRect(x: col0x + 4, y: rowY + 16, width: 300, height: 10),
                         font: font8, color: gray)
                }
                draw("\(linea.cantidad)", in: CGRect(x: col1x, y: rowY + 4, width: 55, height: 12),
                     font: font9, color: black, align: .center)
                if facturaData.numero != "Muestra" {
                    draw(String(format: "%.2f €", linea.precioUnitario),
                         in: CGRect(x: col2x, y: rowY + 4, width: 70, height: 12),
                         font: font9, color: black, align: .right)
                    draw(String(format: "%.2f €", linea.total),
                         in: CGRect(x: col3x, y: rowY + 4, width: pageRect.width - margin - col3x, height: 12),
                         font: font9, color: black, align: .right)
                }
                y += rowH
                drawLine(cgCtx, x1: margin, y1: y, x2: pageRect.width - margin, y2: y,
                         color: lightGray)
            }
            y += 16

            // ─── TOTALES ──────────────────────────────────────────────
            if facturaData.numero != "Muestra" {
                let totalesX: CGFloat = 340
                let totalesW = pageRect.width - margin - totalesX

                draw("Base Imponible:", in: CGRect(x: totalesX, y: y, width: 110, height: 14),
                     font: font11, color: black)
                draw(String(format: "%.2f €", facturaData.baseImponible),
                     in: CGRect(x: totalesX + 115, y: y, width: totalesW - 115, height: 14),
                     font: fontBold11, color: black, align: .right)
                y += 17

                let ivaPct = Int(facturaData.iva * 100)
                draw("IVA (\(ivaPct)%):", in: CGRect(x: totalesX, y: y, width: 110, height: 14),
                     font: font11, color: black)
                draw(String(format: "%.2f €", facturaData.iva * facturaData.baseImponible),
                     in: CGRect(x: totalesX + 115, y: y, width: totalesW - 115, height: 14),
                     font: fontBold11, color: black, align: .right)
                y += 4
                drawLine(cgCtx, x1: totalesX, y1: y + 14, x2: pageRect.width - margin, y2: y + 14, color: gray.withAlphaComponent(0.5))
                y += 18

                draw("TOTAL:", in: CGRect(x: totalesX, y: y, width: 110, height: 18),
                     font: fontBold14, color: black)
                draw(String(format: "%.2f €", facturaData.total),
                     in: CGRect(x: totalesX + 115, y: y, width: totalesW - 115, height: 18),
                     font: fontBold14, color: blue, align: .right)
            }
            y += 30

            // ─── PIE DE PÁGINA ────────────────────────────────────────
            let footerY: CGFloat = pageRect.height - margin - 80

            if !facturaData.notas.isEmpty {
                // drawLine(cgCtx, x1: margin, y1: footerY - 10, x2: pageRect.width - margin, y2: footerY - 10, color: lightGray)
                draw("NOTAS:", in: CGRect(x: margin, y: footerY - 5, width: 200, height: 12),
                     font: fontBold9, color: black)
                draw(facturaData.notas, in: CGRect(x: margin, y: footerY + 8, width: pageRect.width - margin * 2, height: 28),
                     font: font8, color: gray)
            }

            drawLine(cgCtx, x1: margin, y1: pageRect.height - margin - 50,
                     x2: pageRect.width - margin, y2: pageRect.height - margin - 50, color: lightGray)

            let cuenta = esItbook ? "ES10 0075 0164 92 0600701155" : "ES52 0049 5444 1120 1675 1590"
            draw("FORMA DE PAGO: Transferencia bancaria", in: CGRect(x: margin, y: footerY + 40, width: 400, height: 12),
                 font: fontBold9, color: black)
            draw("Nº DE CUENTA: \(cuenta)", in: CGRect(x: margin, y: footerY + 54, width: 450, height: 14),
                 font: fontBold11, color: black)
            
            let nombreEmisorLOPD = esItbook ? "Itbook Editorial SL" : "Editorial Aula SL"
            let lopdText = "De acuerdo con la normativa vigente en materia de protección de datos personales (RGPD y LOPDGDD), le informamos que sus datos serán tratados por \(nombreEmisorLOPD) con la finalidad de gestionar la relación comercial establecida."
            draw(lopdText, in: CGRect(x: margin, y: pageRect.height - margin - 16, width: pageRect.width - margin * 2, height: 28),
                 font: font8, color: gray, wrap: true)
        }
    }

    // MARK: - Helpers CoreGraphics

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, align: NSTextAlignment = .left, wrap: Bool = false) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = wrap ? .byWordWrapping : .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        text.draw(in: rect, withAttributes: attrs)
    }

    private static func drawLine(_ ctx: CGContext, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, color: UIColor) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }
    #endif
}

// MARK: - Vista SwiftUI para macOS (solo se usa en macOS)
#if os(macOS)
struct FacturaPDFView: View {
    let factura: FacturaPDFData

    private let fechaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cabecera
            HStack(alignment: .top) {
                if let nsImage = NSImage(named: "logo_aula") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                } else {
                    Text("AULA")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Editorial Aula sl").bold()
                    Text("C/ Hierros 14 D. Puerta 6")
                    Text("46022 Valencia")
                    Text("B19994326")
                }
                .font(.caption)
            }

            Divider()

            // Datos factura y cliente
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    let tituloDoc = factura.numero == "Muestra" ? "SALIDA DE MUESTRAS" : "FACTURA"
                    Text(tituloDoc).font(.title).bold()
                    Text("Nº: \(factura.numero)")
                    Text("Fecha: \(factura.fecha.map { fechaFormatter.string(from: $0) } ?? "—")")
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLIENTE").bold().font(.caption)
                    Text(factura.clienteNombre).font(.headline)
                    Text(factura.clienteDireccion)
                    Text("\(factura.clienteCP) \(factura.clienteCiudad)")
                    Text(factura.clienteProvincia)
                    if !factura.clienteCIF.isEmpty {
                        Text("CIF/NIF: \(factura.clienteCIF)")
                    }
                }
                .font(.subheadline)
                .frame(width: 250, alignment: .leading)
            }

            // Tabla de productos
            VStack(spacing: 0) {
                HStack {
                    Text("Descripción").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Cant.").frame(width: 50, alignment: .center)
                    if factura.numero != "Muestra" {
                        Text("Precio").frame(width: 80, alignment: .trailing)
                        Text("Total").frame(width: 80, alignment: .trailing)
                    }
                }
                .font(.caption).bold()
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))

                Divider()

                ForEach(factura.lineas) { linea in
                    HStack {
                        Text(linea.productoNombre).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(linea.cantidad)").frame(width: 50, alignment: .center)
                        if factura.numero != "Muestra" {
                            Text(String(format: "%.2f €", linea.precioUnitario)).frame(width: 80, alignment: .trailing)
                            Text(String(format: "%.2f €", linea.total)).frame(width: 80, alignment: .trailing)
                        }
                    }
                   .font(.caption)
                    .padding(.vertical, 4)
                    Divider()
                }
            }

            // Totales
            if factura.numero != "Muestra" {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack {
                            Text("Base Imponible:")
                            Text(String(format: "%.2f €", factura.baseImponible)).bold()
                        }
                        HStack {
                            Text("IVA (\(Int(factura.iva * 100))%):")
                            Text(String(format: "%.2f €", factura.iva * factura.baseImponible)).bold()
                        }
                        HStack {
                            Text("TOTAL:")
                            Text(String(format: "%.2f €", factura.total)).font(.title3).bold()
                        }
                    }
                    .font(.subheadline)
                }
            }

            Spacer()

            // Pie de página
            VStack(alignment: .leading, spacing: 10) {
                if !factura.notas.isEmpty {
                    Text("NOTAS:").font(.caption).bold()
                    Text(factura.notas).font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORMA DE PAGO: Transferencia bancaria").bold()
                    Text("Nº DE CUENTA: ES5200495444112016751590")
                }
                .font(.caption)

                Text("De acuerdo con la normativa vigente en materia de protección de datos personales, le informamos que sus datos serán tratados por Editorial Aula SL con la finalidad de gestionar la relación comercial.")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
        }
        .padding(40)
        .frame(width: 600)
        .background(Color.white)
    }
}
#endif
