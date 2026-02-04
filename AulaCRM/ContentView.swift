//
//  ContentView.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import CoreData
import MapKit
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.managedObjectContext) private var ctx

    // Datos
    @FetchRequest(sortDescriptors: [SortDescriptor(\Contacto.nombre, comparator: .localizedStandard)])
    private var contactos: FetchedResults<Contacto>

    // Estado UI
    @State private var search = ""
    @State private var selectedID: NSManagedObjectID? = nil
    @State private var selectedTab: Tab = .detalle
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    @State private var selectedProvincia = "Todos"
    @State private var selectedCiudad    = "Todos"
    @State private var selectedCP        = "Todos"
    @State private var selectedRegimen   = "Todos"
    @State private var selectedCliente   = "Todos" // opciones: Todos / Sí / No
    @State private var showAllPins = false
    
    
    @State private var showFilters: Bool = false
    
    // Debug DB
    @State private var showDBAlert = false
    @State private var dbPathString = ""
    
    // Backup
    @State private var backupURL: URL?
    
    
    // Picker Detalle / Productos para la toolbar
    private var tabToolbarPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { t in
                Text(t.rawValue)
                    .tag(t)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 320)
        .fixedSize()
    }
    
    

    enum Tab: String, CaseIterable { case detalle = "Detalle", productos = "Productos" }

    private var provinciasUnicas: [String] { ["Todos"] + Array(Set(contactos.compactMap { $0.provincia?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted() }
    private var ciudadesUnicas:   [String] {
        let filteredByProv = Array(contactos).filter { c in
            // Si la provincia seleccionada es "Todos", no filtramos; si no, solo ciudades de esa provincia
            if selectedProvincia == "Todos" { return true }
            return ((c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                .caseInsensitiveCompare(selectedProvincia) == .orderedSame
        }
        let ciudades = filteredByProv
            .compactMap { $0.ciudad?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(ciudades)).sorted()
    }
    private var cpsUnicos: [String] {
        // Filtra por provincia seleccionada (si no es "Todos") y por ciudad seleccionada (si no es "Todos")
        let filtered = Array(contactos).filter { c in
            let provOK: Bool = {
                if selectedProvincia == "Todos" { return true }
                return ((c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .caseInsensitiveCompare(selectedProvincia) == .orderedSame
            }()
            let cityOK: Bool = {
                if selectedCiudad == "Todos" { return true }
                return ((c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .caseInsensitiveCompare(selectedCiudad) == .orderedSame
            }()
            return provOK && cityOK
        }
        let cps = filtered
            .compactMap { $0.cp?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(cps)).sorted()
    }
    private var regimenesUnicos:  [String] { ["Todos"] + Array(Set(contactos.compactMap { $0.regimen?.trimmingCharacters(in: .whitespacesAndNewlines)  }.filter { !$0.isEmpty })).sorted() }
    
    private var filterSection: some View {
        FilterView(
            showFilters: $showFilters,
            selectedProvincia: $selectedProvincia,
            selectedCiudad: $selectedCiudad,
            selectedCP: $selectedCP,
            selectedRegimen: $selectedRegimen,
            selectedCliente: $selectedCliente,
            provinciasUnicas: provinciasUnicas,
            ciudadesUnicas: ciudadesUnicas,
            cpsUnicos: cpsUnicos,
            regimenesUnicos: regimenesUnicos
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            VStack(spacing: 0) {
                #if os(iOS)
                // (Filtros movidos abajo)
                #endif
                
                List(selection: $selectedID) {
                    #if os(macOS)
                    // En Mac: Filtros dentro de la lista (estilo clásico Sidebar)
                    filterSection
                        .listRowSeparator(.hidden)
                    #endif

                    // Contactos
                    Section {
                        ForEach(filteredContacts) { c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.nombre ?? "—").font(.body).fontWeight(.regular)
                                Text((c.direccion ?? "").isEmpty ? (c.ciudad ?? "") : (c.direccion ?? ""))
                                    .font(.body).fontWeight(.light)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(c.objectID)
                        }
                        .onDelete(perform: borrar)
                    }
                }
                #if os(iOS)
                .listStyle(.plain) // Estilo plano para quitar cabeceras
                .padding(.top, 0)
                #else
                .listStyle(.sidebar)
                #endif
                
                #if os(iOS)
                // En iPhone: Barra de búsqueda y Filtros ABAJO (Thumb Zone)
                Divider()
                VStack(spacing: 12) {
                    // 🔍 Buscador Custom
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Buscar contacto…", text: $search)
                            .textFieldStyle(.plain)
                        if !search.isEmpty {
                            Button(action: { search = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // 📌 Filtros
                    filterSection
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                }
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                #endif
            }
            .navigationTitle("Contactos")
            #if os(macOS)
            .searchable(text: $search, placement: .sidebar, prompt: "Buscar contacto…")
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .frame(minWidth: 240)
            .navigationSplitViewColumnWidth(min: 200, ideal: 270, max: 345)

        } detail: {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .detalle:
                        #if os(macOS)
                        ScrollView {
                            if let contacto = selectedContact {
                                DetailTabView(contacto: contacto,
                                              contactosFiltrados: Array(filteredContacts),
                                              showAllPins: $showAllPins,
                                              selectedContact: Binding(
                                                get: { selectedContact },
                                                set: { selectedID = $0?.objectID }
                                              ))
                            } else {
                                Text("Selecciona un contacto").foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        #else
                        if let contacto = selectedContact {
                            DetailTabView(contacto: contacto,
                                          contactosFiltrados: Array(filteredContacts),
                                          showAllPins: $showAllPins,
                                          selectedContact: Binding(
                                            get: { selectedContact },
                                            set: { selectedID = $0?.objectID }
                                          ))
                        } else {
                            Text("Selecciona un contacto").foregroundStyle(.secondary)
                            Spacer()
                        }
                        #endif
                    case .productos:
                        ProductosTabView()
                    }
                }
            #if os(macOS)
            .padding(.horizontal)
            #endif
            .toolbar {
                // 🔵 Selector DETALLE / PRODUCTOS en la barra superior
                ToolbarItem(placement: .automatic) {
                    tabToolbarPicker
                }

                // 💾 Botón BACKUP
                ToolbarItem(placement: .automatic) {
                    Button {
                        if let url = BackupManager.generarBackupJSON(context: ctx) {
                            #if os(iOS)
                            backupURL = url
                            #else
                            // En Mac, abrimos Finder con el archivo seleccionado
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                            #endif
                        }
                    } label: {
                        Label("Backup", systemImage: "arrow.down.doc")
                    }
                    .help("Exportar Copia de Seguridad (JSON)")
                }

                // 🟢 Botón AÑADIR contacto (derecha)
                ToolbarItem(placement: .primaryAction) {
                    Button { crearContactoVacio() } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                }
                
                // 🛠 Botón DEBUG: Ver ruta BBDD
                ToolbarItem(placement: .automatic) {
                    Button {
                        if let url = PersistenceController.shared.container.persistentStoreDescriptions.first?.url {
                            dbPathString = url.path(percentEncoded: false)
                            showDBAlert = true
                        }
                    } label: {
                        Image(systemName: "cylinder.split.1x2")
                        .help("Ver ruta Base de Datos")
                    }
                }
            }
            .background(Color.clear)
            .alert("Ruta de la Base de Datos", isPresented: $showDBAlert) {
                #if os(macOS)
                Button("Mostrar en Finder") {
                    let url = URL(fileURLWithPath: dbPathString)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                #endif
                Button("Copiar Ruta") {
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(dbPathString, forType: .string)
                    #else
                    UIPasteboard.general.string = dbPathString
                    #endif
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(dbPathString)
            }
        }
        #if os(iOS)
        .sheet(item: $backupURL) { url in
            ShareSheet(activityItems: [url])
        }
        #endif
        #if os(macOS)
        .frame(minWidth: 1000, minHeight: 650)
        #endif
        .onChange(of: selectedProvincia) { _, _ in
            if !ciudadesUnicas.contains(selectedCiudad) {
                selectedCiudad = "Todos"
            }
            if !cpsUnicos.contains(selectedCP) {
                selectedCP = "Todos"
            }
        }
        .onChange(of: selectedCiudad) { _, _ in
            if !cpsUnicos.contains(selectedCP) {
                selectedCP = "Todos"
            }
        }
    }

    private var filteredContacts: [Contacto] {
        let buscado = search.trimmingCharacters(in: .whitespacesAndNewlines)

        return Array(contactos).filter { c in
            // Filtros: solo aplican si no es "Todos"
            if selectedProvincia != "Todos",
               (c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedProvincia) != .orderedSame { return false }

            if selectedCiudad != "Todos",
               (c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedCiudad) != .orderedSame { return false }

            if selectedCP != "Todos",
               (c.cp ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedCP) != .orderedSame { return false }

            if selectedRegimen != "Todos",
               (c.regimen ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedRegimen) != .orderedSame { return false }

            // Cliente (booleano): "Todos" / "Sí" / "No"
            if selectedCliente != "Todos" {
                let isCliente: Bool = {
                    if let b = c.value(forKey: "cliente") as? Bool { return b }
                    if let n = c.value(forKey: "cliente") as? NSNumber { return n.boolValue }
                    if let s = c.value(forKey: "cliente") as? String {
                        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return v == "true" || v == "1" || v == "si" || v == "sí" || v == "yes" || v == "y"
                    }
                    return false
                }()
                if selectedCliente == "Sí" && !isCliente { return false }
                if selectedCliente == "No" && isCliente  { return false }
            }

            // Búsqueda libre
            if buscado.isEmpty { return true }
            return (c.nombre ?? "").localizedCaseInsensitiveContains(buscado)
                || (c.ciudad ?? "").localizedCaseInsensitiveContains(buscado)
                || (c.direccion ?? "").localizedCaseInsensitiveContains(buscado)
        }
    }
    
    
    
    
    
    // MARK: - Computados

    
    private var selectedContact: Contacto? {
        if let id = selectedID {
            return contactos.first(where: { $0.objectID == id })
                ?? filteredContacts.first
        }
        return filteredContacts.first
    }

    // MARK: - Acciones
    private func borrar(_ offsets: IndexSet) {
        offsets.map { filteredContacts[$0] }.forEach(ctx.delete)
        try? ctx.save()
    }

    private func crearContactoVacio() {
        let c = Contacto(context: ctx)
        c.id = UUID()
        c.nombre = "Nuevo contacto"
        try? ctx.save()
        selectedID = c.objectID
        selectedTab = .detalle
    }

    // Export CSV para Google My Maps
    private func exportarCSV(_ contactos: [Contacto]) {
        let header = "Name,Address,Latitude,Longitude,Notes\n"
        let rows = contactos.compactMap { c -> String? in
            let name = (c.nombre ?? "").replacingOccurrences(of: "\"", with: "”")
            let addr = (c.direccion ?? "").replacingOccurrences(of: "\"", with: "”")
            let lat = (c.value(forKey: "lat") as? NSNumber)?.stringValue ?? ""
            let lng = (c.value(forKey: "lng") as? NSNumber)?.stringValue ?? ""
            let notes = (c.notas ?? "").replacingOccurrences(of: "\"", with: "”").replacingOccurrences(of: "\n", with: " ")
            return "\"\(name)\",\"\(addr)\",\(lat),\(lng),\"\(notes)\""
        }.joined(separator: "\n")

        let csv = header + rows
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AulaCRM_MyMaps.csv")
        try? csv.data(using: .utf8)?.write(to: url)
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

#if os(macOS)
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
#endif
}

// MARK: - Editor mínimo embebido para crear contactos (incluye 'notas')
struct ContactEditorInline: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (_ nombre: String, _ ciudad: String, _ direccion: String, _ email: String, _ telefono: String, _ notas: String) -> Void

    @State private var nombre = ""
    @State private var ciudad = ""
    @State private var direccion = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var notas = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nuevo contacto").font(.title2).bold()
            Form {
                TextField("Nombre*", text: $nombre)
                TextField("Ciudad", text: $ciudad)
                TextField("Dirección", text: $direccion)
                TextField("Email", text: $email)
                TextField("Teléfono", text: $telefono)

                TextField("Notas", text: $notas, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    onSave(nombre, ciudad, direccion, email, telefono, notas)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }
}

// MARK: - Productos Tab (tabla completa)
private struct ProductosTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Producto.nombre, comparator: .localizedStandard)],
        animation: .default
    ) private var productos: FetchedResults<Producto>
    @State private var sortOrder: [KeyPathComparator<Producto>] = [
        .init(\Producto.nombre, comparator: .localizedStandard)
    ]

    // Formateador numérico para stock
    private let stockFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 0
        f.maximum = 999999
        return f
    }()

    // Binding editable del stock (Int) con guardado automático en Core Data
    private func bindingStockInt(_ p: Producto) -> Binding<Int> {
        Binding(
            get: {
                (p.value(forKey: "stock") as? NSNumber)?.intValue
                ?? (p.value(forKey: "stock") as? Int)
                ?? Int(p.stock)
            },
            set: { newVal in
                p.setValue(Int16(newVal), forKey: "stock")
                try? ctx.save()
            }
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Table(productos) {
                TableColumn("Nombre") { item in Text(item.nombre ?? "—") }
                
                //TableColumn("ISBN") { item in Text(item.isbn ?? "—") }
                
                TableColumn("ISBN") { item in
                    SelectableText(text: item.isbn ?? "")
                }
                
                
                TableColumn("Depósito Legal") { item in Text(item.depositolegal ?? "—") }
                TableColumn("Stock") { item in
                    HStack(spacing: 6) {
                        TextField("", value: bindingStockInt(item), formatter: stockFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Stepper("", value: bindingStockInt(item), in: 0...999_999)
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    let ctx = PersistenceController.preview.container.viewContext

    let _ = {
        // Contacto demo con notas
        let c = Contacto(context: ctx)
        c.id = UUID()
        c.nombre = "Colegio Demo"
        c.provincia = "València" // Match default
        c.ciudad = "VALÈNCIA"    // Match default
        c.direccion = "C/ Ejemplo, 123"
        c.email = "info@demo.es"
        c.telefono = "600 000 000"
        c.notas = "Cliente con interés en Aula Matemáticas. Llamar la próxima semana."

        // Tipo demo con notas
        let t = Tipo(context: ctx)
        t.nombre = "Colegio"
        t.notas = "Centro concertado"
        c.tipo = t

        // Persona demo con notas
        let p = Persona(context: ctx)
        p.id = UUID()
        p.nombre = "María Pérez"
        p.notas = "Directora de estudios; prefiere email."
        c.mutableSetValue(forKey: "personas").add(p)

        // Compra demo con notas
        let comp = Compra(context: ctx)
        comp.id = UUID()
        comp.fecha = Date()
        comp.notas = "Licencias Aula Matemáticas (20 uds)."
        c.mutableSetValue(forKey: "compras").add(comp)

        // Conversación demo con notas
        let conv = Conversacion(context: ctx)
        conv.id = UUID()
        conv.fecha = Date()
        conv.setValue("teléfono", forKey: "canal")
        conv.notas = "Llamada inicial; piden demo y lista de precios."
        c.mutableSetValue(forKey: "conversaciones").add(conv)
    }()

    ContentView().environment(\.managedObjectContext, ctx)
}
