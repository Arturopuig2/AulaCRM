import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct FacturasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Factura.fecha, order: .reverse)],
        animation: .default
    ) private var facturas: FetchedResults<Factura>

    @State private var searchText = ""
    @State private var mostrarNuevaFactura = false
    @State private var facturaParaEditar: Factura?
    @State private var mostrarConfirmacionBorrado = false
    @State private var facturaABorrar: Factura?
    @State private var filterEmisor = "Todos"

    var filteredFacturas: [Factura] {
        var base = Array(facturas)
        
        if filterEmisor != "Todos" {
            base = base.filter { ($0.value(forKey: "emisor") as? String ?? "Aula") == filterEmisor }
        }
        
        if searchText.isEmpty {
            return base
        } else {
            return base.filter {
                ($0.numero ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.clienteNombre ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private let fechaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            HStack(spacing: 16) {
                TextField("Buscar factura...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                
                Picker("", selection: $filterEmisor) {
                    Text("Todas").tag("Todos")
                    Text("Editorial Aula").tag("Aula")
                    Text("Itbook Editorial").tag("Itbook")
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
            }
            .padding()
            #endif

            List {
                ForEach(filteredFacturas) { factura in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 8) {
                                Text(factura.numero ?? "Sin número")
                                    .font(.headline)
                                
                                // Indicador de emisor
                                let emisor = (factura.value(forKey: "emisor") as? String) ?? "Aula"
                                Text(emisor == "Itbook" ? "ITBOOK" : "AULA")
                                    .font(.system(size: 8, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(emisor == "Itbook" ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                    .foregroundStyle(emisor == "Itbook" ? Color.orange : Color.blue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(emisor == "Itbook" ? Color.orange.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 0.5)
                                    )
                                
                                if factura.numero == "Muestra" {
                                    Text("MUESTRA")
                                        .font(.system(size: 8, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(Color.green)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.green.opacity(0.5), lineWidth: 0.5)
                                        )
                                }
                            }
                            
                            Text(factura.clienteNombre ?? "Sin cliente")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(factura.fecha.map { fechaFormatter.string(from: $0) } ?? "—")
                                .font(.caption)
                            
                            if factura.numero != "Muestra" {
                                Text(String(format: "%.2f €", factura.total))
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                facturaParaEditar = factura
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            // Botón PDF: solo en macOS, usando .fileExporter (sin NSSavePanel)
                            PDFExportButton(factura: factura)

                            Button {
                                facturaABorrar = factura
                                mostrarConfirmacionBorrado = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        #if os(iOS)
        .searchable(text: $searchText, prompt: "Buscar factura...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Todas") { filterEmisor = "Todos" }
                    Button("Editorial Aula") { filterEmisor = "Aula" }
                    Button("Itbook Editorial") { filterEmisor = "Itbook" }
                } label: {
                    Label("Filtro", systemImage: filterEmisor == "Todos" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        #endif
        .sheet(isPresented: $mostrarNuevaFactura) {
            NuevaFacturaView(facturaAEditar: nil)
                .environment(\.managedObjectContext, ctx)
        }
        .sheet(item: $facturaParaEditar) { factura in
            NuevaFacturaView(facturaAEditar: factura)
                .environment(\.managedObjectContext, ctx)
        }
        .alert("Borrar Factura", isPresented: $mostrarConfirmacionBorrado) {
            Button("Cancelar", role: .cancel) { facturaABorrar = nil }
            Button("Borrar", role: .destructive) {
                if let f = facturaABorrar {
                    // 1. Buscar movimientos de almacén asociados a esta factura
                    if let idStr = f.id?.uuidString {
                        let request = NSFetchRequest<MovimientoAlmacen>(entityName: "MovimientoAlmacen")
                        request.predicate = NSPredicate(format: "notas CONTAINS %@", idStr)
                        
                        if let movimientosAsociados = try? ctx.fetch(request) {
                            for mov in movimientosAsociados {
                                // 2. Revertir el stock en el producto
                                if let prod = mov.producto {
                                    let stockActual = (prod.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(prod.stock)
                                    prod.setValue(Int16(stockActual + Int(mov.cantidad)), forKey: "stock")
                                }
                                // 3. Borrar el movimiento
                                ctx.delete(mov)
                            }
                        }
                    }
                    
                    // 4. Borrar la factura
                    ctx.delete(f)
                    try? ctx.save()
                    facturaABorrar = nil
                }
            }
        } message: {
            if let f = facturaABorrar {
                Text("¿Estás seguro de que quieres borrar la factura \(f.numero ?? "")?")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MostrarNuevaFactura"))) { _ in
            facturaParaEditar = nil
            mostrarNuevaFactura = true
        }
    }
}

// MARK: - Botón exportar PDF (macOS únicamente)
// Escribe el PDF en la carpeta temporal del sistema y lo abre en Preview.
// El usuario puede guardar desde Preview. Este enfoque evita cualquier panel
// de AppKit (NSSavePanel / .fileExporter) que crashea con AppKitBreakInDebugger.
struct PDFExportButton: View {
    let factura: Factura

    #if os(macOS)
    @State private var errorMessage: String? = nil
    @State private var mostrarError = false
    #endif

    var body: some View {
        #if os(macOS)
        Button {
            abrirEnPreview()
        } label: {
            Image(systemName: "printer")
                .foregroundColor(.green)
        }
        .buttonStyle(.plain)
        .help("Abrir factura en Preview para imprimir o guardar")
        .alert("Error al generar PDF", isPresented: $mostrarError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Error desconocido")
        }
        #else
        EmptyView()
        #endif
    }

    #if os(macOS)
    private func abrirEnPreview() {
        let facturaData = FacturaPDFGenerator.mapFacturaToData(factura)
        let pdfData    = FacturaPDFGenerator.createPDFMac(facturaData: facturaData)
        let filename   = FacturaPDFGenerator.safeFilename(factura: factura)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try pdfData.write(to: url)
            NSWorkspace.shared.open(url)
        } catch {
            errorMessage = error.localizedDescription
            mostrarError = true
        }
    }
    #endif
}
