//
//  ProductosTabView.swift
//  AulaCRM
//

import SwiftUI
import CoreData

// MARK: - Productos Tab (tabla completa)
struct ProductosTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Producto.nombre, comparator: .localizedStandard)],
        animation: .default
    ) private var productos: FetchedResults<Producto>
    @State private var sortOrder: [SortDescriptor<Producto>] = [
        .init(\Producto.sortNombre, comparator: .localizedStandard)
    ]

    /// Binding desde ContentView para triggear el sheet de nuevo producto
    @Binding var mostrarNuevo: Bool

    @State private var productoAEditar: Producto?
    @State private var mostrarEdicion = false
    @State private var productoABorrar: Producto?
    @State private var mostrarConfirmacionBorrado = false

    private var sortedProductos: [Producto] {
        return productos.sorted(using: sortOrder)
    }

    private func precioTexto(_ p: Producto) -> String {
        let v = (p.value(forKey: "precio") as? NSNumber)?.doubleValue
            ?? (p.value(forKey: "precio") as? Double)
            ?? 0.0
        return String(format: "%.2f", v)
    }
    
    private func stockTexto(_ p: Producto) -> String {
        let intVal: Int =
            (p.value(forKey: "stock") as? NSNumber)?.intValue
            ?? (p.value(forKey: "stock") as? Int)
            ?? ((p.value(forKey: "stock") as? Int16).map { Int($0) } ?? 0)
        return String(intVal)
    }

    private var tablaDesktop: some View {
        Table(of: Producto.self, sortOrder: $sortOrder) {
            TableColumn("Nombre" as LocalizedStringKey, value: \.sortNombre) { (item: Producto) in
                Text(item.nombre ?? "—")
            }
            
            TableColumn("ISBN" as LocalizedStringKey, value: \.sortISBN) { (item: Producto) in
                SelectableText(text: item.isbn ?? "")
            }
            
            TableColumn("Depósito Legal" as LocalizedStringKey, value: \.sortDeposito) { (item: Producto) in
                Text(item.depositolegal ?? "—")
            }
            
            TableColumn("Stock" as LocalizedStringKey, value: \.sortStock) { (item: Producto) in
                Text(stockTexto(item))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
            }
            
            TableColumn("Acciones") { (item: Producto) in
                HStack(spacing: 12) {
                    Button {
                        productoAEditar = item
                        mostrarEdicion = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        productoABorrar = item
                        mostrarConfirmacionBorrado = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .width(80)
        } rows: {
            ForEach(sortedProductos) { item in
                TableRow(item)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                List(productos) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.nombre ?? "—")
                            .font(.headline)
                        
                        Text("ISBN: \(item.isbn ?? "—")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Stock: \(stockTexto(item))")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            } else {
                tablaDesktop
            }
            #else
            tablaDesktop
            #endif
        }
        .onChange(of: mostrarNuevo) { _, nuevo in
            if nuevo {
                productoAEditar = nil
                mostrarEdicion  = true
                mostrarNuevo    = false
            }
        }
        .sheet(isPresented: $mostrarEdicion) {
            SheetNuevoProducto(productoAEditar: productoAEditar)
                .environment(\.managedObjectContext, ctx)
        }
        .alert("Borrar Producto", isPresented: $mostrarConfirmacionBorrado) {
            Button("Cancelar", role: .cancel) { 
                productoABorrar = nil
            }
            Button("Borrar", role: .destructive) {
                if let p = productoABorrar {
                    let productID = p.objectID
                    productoABorrar = nil
                    
                    Task.detached {
                        let bgContext = PersistenceController.shared.container.newBackgroundContext()
                        bgContext.performAndWait {
                            if let objToDelete = try? bgContext.existingObject(with: productID) {
                                bgContext.delete(objToDelete)
                                try? bgContext.save()
                            }
                        }
                    }
                }
            }
        } message: {
            if let p = productoABorrar {
                Text("¿Estás seguro de que quieres borrar el producto '\(p.nombre ?? "Desconocido")'? Esta acción no se puede deshacer.")
            }
        }
        .task {
            // Sanear IDs nulos al abrir la pestaña (evita que SwiftUI Table se cuelgue)
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.perform {
                let req: NSFetchRequest<Producto> = Producto.fetchRequest()
                if let todos = try? bgContext.fetch(req) {
                    var hayCambios = false
                    for p in todos {
                        if p.id == nil {
                            p.id = UUID()
                            hayCambios = true
                        }
                    }
                    if hayCambios { try? bgContext.save() }
                }
            }
        }
    }
}

// MARK: - Vista Modal para Añadir / Editar Producto
struct SheetNuevoProducto: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx

    var productoAEditar: Producto?

    @State private var nombre = ""
    @State private var isbn = ""
    @State private var asignatura = ""
    @State private var curso = ""
    @State private var precio = ""
    @State private var depositolegal = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(productoAEditar == nil ? "Nuevo producto" : "Editar producto").font(.title2).bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Sección: Información Básica
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Información básica").font(.caption).bold().foregroundStyle(.secondary)
                        TextField("Nombre*", text: $nombre).textFieldStyle(.roundedBorder)
                        TextField("ISBN", text: $isbn).textFieldStyle(.roundedBorder)
                    }
                    
                    // Sección: Detalles
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detalles").font(.caption).bold().foregroundStyle(.secondary)
                        TextField("Asignatura", text: $asignatura).textFieldStyle(.roundedBorder)
                        TextField("Curso", text: $curso).textFieldStyle(.roundedBorder)
                        TextField("Depósito Legal", text: $depositolegal).textFieldStyle(.roundedBorder)
                    }
                    
                    // Sección: Inventario y Ventas
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inventario y Ventas").font(.caption).bold().foregroundStyle(.secondary)
                        TextField("Precio (€)", text: $precio).textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    }
                }
                .padding(.top, 4)
            }
            
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    let prod = productoAEditar ?? Producto(context: ctx)
                    
                    // Asegurar ID único
                    if prod.id == nil { prod.id = UUID() }
                    
                    prod.nombre = nombre
                    
                    // Normalizar ISBN antes de guardar para evitar duplicados
                    prod.isbn = CSVImporter.normalizarISBN(isbn)
                    
                    prod.setValue(asignatura, forKey: "asignatura")
                    prod.setValue(curso, forKey: "curso")
                    prod.setValue(depositolegal, forKey: "depositolegal")
                    
                    // Conversión de precio
                    let cleanedPrecio = precio.replacingOccurrences(of: ",", with: ".")
                    if let val = Double(cleanedPrecio) {
                        prod.setValue(val, forKey: "precio")
                    }
                    
                    try? ctx.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(25)
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            if let p = productoAEditar {
                nombre = p.nombre ?? ""
                isbn = p.isbn ?? ""
                asignatura = (p.value(forKey: "asignatura") as? String) ?? ""
                curso = (p.value(forKey: "curso") as? String) ?? ""
                depositolegal = (p.value(forKey: "depositolegal") as? String) ?? ""
                
                let pVal = (p.value(forKey: "precio") as? NSNumber)?.doubleValue ?? 0.0
                precio = String(format: "%.2f", pVal)
            }
        }
    }
}
