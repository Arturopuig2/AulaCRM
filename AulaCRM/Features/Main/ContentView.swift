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
    @StateObject private var viewModel = ContentViewModel()
    @State private var selectedID: NSManagedObjectID? = nil
    @State private var selectedTab: Tab = .detalle
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
                            
    
        
    // Debug DB
    @State private var showDBAlert = false
    @State private var dbPathString = ""
    
    // Backup
    @State private var mostrarBackupShare = false
    @State private var backupShareURL: URL?

    // Acciones de pestañas (centralizadas aquí para mantener el toolbar estable)
    @State private var mostrarNuevoProducto    = false
    @State private var mostrarNuevoMovimiento  = false
    @State private var mostrarNuevoToDo        = false
    

    // Picker Detalle / Productos para la toolbar (Solo Mac / iPad)
    private var tabToolbarPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { t in
                Text(t.rawValue)
                    .tag(t)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 720) // Aumentado para acomodar la nueva pestaña Campañas
    }
    
    

    enum Tab: String, CaseIterable {
        case detalle = "Colegios"
        case productos = "Productos"
        case almacen = "Almacén"
        case facturas = "Facturas"
        case reservas = "Calendario"
        case tareas = "Tareas"
        case notas = "Notas"
        case campanas = "Campañas"
        
        var displayName: String {
            return self.rawValue
        }
    }

    private var provinciasUnicas: [String] { viewModel.provinciasUnicas(from: Array(contactos)) }
    private var ciudadesUnicas: [String] { viewModel.ciudadesUnicas(from: Array(contactos)) }
    private var cpsUnicos: [String] { viewModel.cpsUnicos(from: Array(contactos)) }
    private var regimenesUnicos: [String] { viewModel.regimenesUnicos(from: Array(contactos)) }

    private var filterSection: some View {
        FilterView(
            showFilters: $viewModel.showFilters,
            selectedProvincia: $viewModel.selectedProvincia,
            selectedCiudad: $viewModel.selectedCiudad,
            selectedCP: $viewModel.selectedCP,
            selectedRegimen: $viewModel.selectedRegimen,
            selectedCliente: $viewModel.selectedCliente,
            provinciasUnicas: provinciasUnicas,
            ciudadesUnicas: ciudadesUnicas,
            cpsUnicos: cpsUnicos,
            regimenesUnicos: regimenesUnicos
        )
    }

    @State private var showImportAlert = false
    @State private var importResultLog = ""
    @State private var isImporting = false
    @State private var importMessage = ""

    private var deleteAction: ((IndexSet) -> Void)? {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return nil
        }
        #endif
        return borrar
    }

    var body: some View {
        ZStack {
            // ... (rest of NavigationSplitView) ...
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
                            .onDelete(perform: deleteAction)
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
                            TextField("Buscar contacto…", text: $viewModel.search)
                                .textFieldStyle(.plain)
                            if !search.isEmpty {
                                Button(action: { viewModel.search = "" }) {
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
                .searchable(text: $viewModel.search, placement: .sidebar, prompt: "Buscar contacto…")
                #endif
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: crearContactoVacio) {
                                Image(systemName: "plus")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(destination: ProductosTabView(mostrarNuevo: .constant(false))) {
                                Image(systemName: "shippingbox")
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: crearContactoVacio) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    #endif
                }
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
                                                  showAllPins: $viewModel.showAllPins,
                                                  selectedContact: Binding(
                                                    get: { selectedContact },
                                                    set: { selectedID = $0?.objectID }))
                                } else {
                                    Text("Selecciona un contacto").foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            #else
                            if let contacto = selectedContact {
                                DetailTabView(contacto: contacto,
                                              contactosFiltrados: Array(filteredContacts),
                                              showAllPins: $viewModel.showAllPins,
                                              selectedContact: Binding(
                                                get: { selectedContact },
                                                set: { selectedID = $0?.objectID }))
                            } else {
                                Text("Selecciona un contacto").foregroundStyle(.secondary)
                                Spacer()
                            }
                            #endif
                        case .productos:
                            ProductosTabView(mostrarNuevo: $mostrarNuevoProducto)
                        case .almacen:
                            AlmacenView(mostrarNuevo: $mostrarNuevoMovimiento)
                        case .facturas:
                            FacturasTabView()
                        case .reservas:
                            ReservasTabView()
                        case .tareas:
                            TareasTabView(mostrarNuevoToDo: $mostrarNuevoToDo)
                        case .notas:
                            NotasTabView()
                        case .campanas:
                            CampanasTabView()
                        }
                    }
                #if os(macOS)
                .padding(.horizontal)
                #endif
                .navigationTitle("")
                .toolbar {
                    // 🔵 Selector de pestañas alineado a la izquierda
                    ToolbarItem(placement: .navigation) {
                        tabToolbarPicker
                    }

                    // 💾 Grupo de acciones de la derecha (Backup, BBDD, Plus)
                    // Usamos ToolbarItemGroup para que el sistema los trate como un bloque estable.
                    ToolbarItemGroup(placement: .primaryAction) {
                        // 1. Botón BACKUP
                        #if os(macOS)
                        Button {
                            if let url = BackupManager.generarBackupJSON(context: ctx) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        } label: {
                            Label("Backup", systemImage: "arrow.down.doc")
                        }
                        .help("Exportar Copia de Seguridad (JSON)")
                        #else
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            if let url = backupShareURL {
                                ShareLink(item: url, subject: Text("Backup AulaCRM")) {
                                    Label("Backup", systemImage: "arrow.down.doc")
                                }
                            } else {
                                Button {
                                    backupShareURL = BackupManager.generarBackupJSON(context: ctx)
                                } label: {
                                    Label("Backup", systemImage: "arrow.down.doc")
                                }
                            }
                        }
                        #endif

                        // 2. Botón BBDD
                        #if os(macOS)
                        Button {
                            if let url = PersistenceController.shared.container.persistentStoreDescriptions.first?.url {
                                dbPathString = url.path(percentEncoded: false)
                                showDBAlert = true
                            }
                        } label: {
                            Image(systemName: "cylinder.split.1x2")
                        }
                        .help("Ver ruta Base de Datos")
                        #else
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            Button {
                                if let url = PersistenceController.shared.container.persistentStoreDescriptions.first?.url {
                                    dbPathString = url.path(percentEncoded: false)
                                    showDBAlert = true
                                }
                            } label: {
                                Image(systemName: "cylinder.split.1x2")
                            }
                            .help("Ver ruta Base de Datos")
                        }
                        #endif

                        // 3. Botón PLUS (Mantener tamaño incluso si está oculto)
                        Group {
                            if selectedTab == .reservas || selectedTab == .tareas || selectedTab == .notas {
                                // Mantenemos el botón invisible y desactivado para no alterar el tamaño del contenedor
                                Button(action: {}) {
                                    Label("Añadir", systemImage: "plus")
                                }
                                .opacity(0)
                                .disabled(true)
                            } else {
                                switch selectedTab {
                                case .detalle:
                                    Button(action: crearContactoVacio) {
                                        Label("Nuevo Colegio", systemImage: "plus")
                                    }
                                    .help("Añadir nuevo colegio")
                                case .productos:
                                    Button { mostrarNuevoProducto = true } label: {
                                        Label("Nuevo Producto", systemImage: "plus")
                                    }
                                    .help("Añadir nuevo producto")
                                case .almacen:
                                    Button { mostrarNuevoMovimiento = true } label: {
                                        Label("Nuevo Movimiento", systemImage: "plus")
                                    }
                                    .help("Registrar nuevo movimiento de almacén")
                                case .facturas:
                                    Button {
                                        NotificationCenter.default.post(name: NSNotification.Name("MostrarNuevaFactura"), object: nil)
                                    } label: {
                                        Label("Nueva Factura", systemImage: "plus")
                                    }
                                    .help("Crear nueva factura")
                                case .campanas:
                                    Button {
                                        NotificationCenter.default.post(name: NSNotification.Name("CrearNuevaPlantillaEmail"), object: nil)
                                    } label: {
                                        Label("Nueva Plantilla", systemImage: "plus")
                                    }
                                    .help("Crear nueva plantilla de correo")
                                default:
                                    EmptyView()
                                }
                            }
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
            
            // Loading Overlay
            if isImporting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(importMessage)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(40)
                .background(Material.ultraThinMaterial)
                .cornerRadius(20)
            }
        }
        // ESCUCHAR CAMBIOS REMOTOS DE CLOUDKIT PARA ACTUALIZAR LA PANTALLA
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task { @MainActor in
                print("☁️ [CloudKit] Cambio remoto detectado, refrescando UI...")
                // Forzar que el contexto principal asimile los nuevos datos
                ctx.refreshAllObjects()
            }
        }
        .onAppear {
            // Toda operación con Core Data en background DEBE ir dentro de bgContext.perform{}
            // para respetar el modelo de concurrencia y evitar EXC_BAD_ACCESS.
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            bgContext.perform {
                #if os(macOS)
                // En macOS los datos pueden venir de CSV → importar si está vacío y limpiar duplicados.
                // En iPhone los datos llegan por CloudKit → NO tocar, para no borrar registros en tránsito.
                let reqProd: NSFetchRequest<Producto> = Producto.fetchRequest()
                let countProd = (try? bgContext.count(for: reqProd)) ?? 0
                if countProd == 0 {
                    CSVImporter.importarProductos(desde: "producto", contexto: bgContext)
                }
                CSVImporter.eliminarDuplicadosReales(ctx: bgContext)
                CSVImporter.eliminarDuplicadosProductos(ctx: bgContext)
                
                // MIGRACIÓN: Asignar emisor por defecto a facturas antiguas
                let reqFact: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Factura")
                if let facturasExistentes = try? bgContext.fetch(reqFact) {
                    var migrado = false
                    for f in facturasExistentes {
                        if f.value(forKey: "emisor") == nil {
                            f.setValue("Aula", forKey: "emisor")
                            migrado = true
                        }
                    }
                    if migrado { try? bgContext.save() }
                }
                #endif
            }
        }

        .alert("Resultado Importación", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importResultLog)
        }
        #if os(iOS)
        .onChange(of: backupShareURL) { _, newURL in
            // Limpiar la URL compartida tras 5s para que ShareLink se pueda reusar
            if newURL != nil {
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    backupShareURL = nil
                }
            }
        }
        #endif
        #if os(macOS)
        .frame(minWidth: 1000, minHeight: 650)
        #endif
        .onChange(of: viewModel.selectedProvincia) { _, _ in
            if !ciudadesUnicas.contains(viewModel.selectedCiudad) {
                viewModel.selectedCiudad = "Todos"
            }
            if !cpsUnicos.contains(viewModel.selectedCP) {
                viewModel.selectedCP = "Todos"
            }
        }
        .onChange(of: viewModel.selectedCiudad) { _, _ in
            if !cpsUnicos.contains(viewModel.selectedCP) {
                viewModel.selectedCP = "Todos"
            }
        }
    }

    private var filteredContacts: [Contacto] {
        viewModel.filteredContacts(from: Array(contactos))
    }

    private var selectedContact: Contacto? {
        if isImporting { return nil } // Seguridad: No mostrar nada mientras se importa/borra
        
        if let id = selectedID {
            return contactos.first(where: { $0.objectID == id })
                ?? filteredContacts.first
        }
        return filteredContacts.first
    }

    // MARK: - Acciones
    private func borrar(_ offsets: IndexSet) {
        viewModel.borrar(offsets: offsets, in: filteredContacts, context: ctx)
    }

    private func crearContactoVacio() {
        selectedID = viewModel.crearContactoVacio(context: ctx)
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
