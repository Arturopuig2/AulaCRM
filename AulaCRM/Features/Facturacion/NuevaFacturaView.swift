import SwiftUI
import CoreData

struct NuevaFacturaView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    
    var facturaAEditar: Factura?
    
    @State private var numero = ""
    @State private var fecha = Date()
    @State private var fechaCobro: Date? = nil
    @State private var clienteID: NSManagedObjectID?
    @State private var clienteNombre = ""
    @State private var clienteDireccion = ""
    @State private var clienteCP = ""
    @State private var clienteCiudad = ""
    @State private var clienteProvincia = ""
    @State private var clienteCIF = ""
    @State private var clienteOtro = ""
    @State private var notas = ""
    @State private var lineas: [LineaTemp] = []
    @State private var porcIva: Double = 0.04
    @State private var descuento: Double = 0.0
    @State private var emisor = "Aula"
    @State private var esMuestra = false
    
    // Para búsqueda de productos
    @State private var mostrarSelectorProductos = false
    
    // Para búsqueda de clientes
    @State private var mostrarSelectorClientes = false
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\Contacto.nombre)])
    private var contactos: FetchedResults<Contacto>
    
    struct LineaTemp: Identifiable {
        let id = UUID()
        var productoNombre: String
        var isbn: String
        var cantidad: Int
        var precioUnitario: Double
        var producto: Producto?
        var total: Double { Double(cantidad) * precioUnitario }
    }
    
    var importeBruto: Double {
        lineas.reduce(0) { $0 + $1.total }
    }
    
    var baseImponible: Double {
        importeBruto * (1.0 - (descuento / 100.0))
    }
    
    var iva: Double {
        baseImponible * porcIva
    }
    
    var totalFactura: Double {
        baseImponible + iva
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    datosGeneralesSection
                    productosSection
                    notasYResumenSection
                }
                .padding(24)
            }
            .navigationTitle(facturaAEditar == nil ? "Nueva Factura" : "Editar Factura")
            #if os(macOS)
            .frame(minWidth: 700, minHeight: 650)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar Factura") {
                        guardarFactura()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(numero.isEmpty || clienteNombre.isEmpty || lineas.isEmpty)
                }
            }
            .sheet(isPresented: $mostrarSelectorProductos) {
                SelectorProductoView { producto in
                    // El catálogo tiene el precio con IVA del 4% incluido. 
                    // Para la factura, necesitamos la base imponible sin IVA.
                    let base = producto.precio / 1.04
                    lineas.append(LineaTemp(productoNombre: producto.nombre ?? "", isbn: producto.isbn ?? "", cantidad: 1, precioUnitario: base, producto: producto))
                }
            }
            .sheet(isPresented: $mostrarSelectorClientes) {
                SelectorContactoView(seleccion: $clienteNombre, contactos: Array(contactos)) { contacto in
                    clienteID = contacto.objectID
                    clienteNombre = contacto.nombre ?? ""
                    clienteDireccion = contacto.direccion ?? ""
                    clienteCP = contacto.cp ?? ""
                    clienteCiudad = contacto.ciudad ?? ""
                    clienteProvincia = contacto.provincia ?? ""
                    clienteCIF = contacto.cif ?? ""
                }
            }
            .onAppear {
                if let f = facturaAEditar {
                    numero = f.numero ?? ""
                    fecha = f.fecha ?? Date()
                    fechaCobro = f.fechaCobro
                    clienteNombre = f.clienteNombre ?? ""
                    clienteDireccion = f.clienteDireccion ?? ""
                    clienteCP = f.clienteCP ?? ""
                    clienteCiudad = f.clienteCiudad ?? ""
                    clienteProvincia = f.clienteProvincia ?? ""
                    clienteCIF = f.clienteCIF ?? ""
                    clienteOtro = f.clienteOtro ?? ""
                    if let savedIva = f.value(forKey: "iva") as? Double {
                        porcIva = savedIva
                    } else {
                        porcIva = 0.04
                    }
                    if let savedDescuento = f.value(forKey: "descuento") as? Double {
                        descuento = savedDescuento
                    } else {
                        descuento = 0.0
                    }
                    notas = f.notas ?? ""
                    if let lines = f.lineas as? Set<LineaFactura> {
                        lineas = lines.map { LineaTemp(productoNombre: $0.productoNombre ?? "", isbn: ($0.value(forKey: "isbn") as? String) ?? "", cantidad: Int($0.cantidad), precioUnitario: $0.precioUnitario) }
                    }
                    emisor = (f.value(forKey: "emisor") as? String) ?? "Aula"
                    esMuestra = (numero == "Muestra")
                }
            }
            .onChange(of: esMuestra) { newValue in
                if newValue {
                    numero = "Muestra"
                } else if numero == "Muestra" {
                    numero = ""
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var datosGeneralesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Datos Generales")
                }
                .font(.headline)
                .foregroundStyle(.blue)
                
                Spacer()
                
                // Fecha de Cobro selector in the top-right corner
                HStack(spacing: 8) {
                    Text("Cobrada:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let dateValue = fechaCobro {
                        DatePicker("", selection: Binding(
                            get: { dateValue },
                            set: { fechaCobro = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        #if os(macOS)
                        .datePickerStyle(.field)
                        #else
                        .datePickerStyle(.compact)
                        #endif
                        .frame(width: 100)
                        
                        Button {
                            fechaCobro = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            fechaCobro = Date()
                        } label: {
                            Text("Establecer...")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 12) {
                GridRow {
                    Text("Nº Factura:")
                        .gridColumnAlignment(.trailing)
                    TextField("Ej: 2024/001", text: $numero)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(esMuestra)
                }
                
                GridRow {
                    Spacer()
                    Toggle("Es una Salida de Muestras", isOn: $esMuestra)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                        #if os(iOS)
                        .padding(.vertical, 4)
                        #endif
                }
                
                GridRow {
                    Text("Emisor:")
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $emisor) {
                        Text("Editorial Aula SL").tag("Aula")
                        Text("Itbook Editorial SL").tag("Itbook")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
                
                GridRow {
                    Text("Fecha:")
                        .gridColumnAlignment(.trailing)
                    DatePicker("", selection: $fecha, displayedComponents: .date)
                        .labelsHidden()
                        #if os(macOS)
                        .datePickerStyle(.field)
                        #else
                        .datePickerStyle(.compact)
                        #endif
                }
                
                GridRow {
                    Text("Cliente:")
                        .gridColumnAlignment(.trailing)
                    HStack {
                        TextField("Nombre del cliente...", text: $clienteNombre)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Seleccionar...") {
                            mostrarSelectorClientes = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                GridRow {
                    Text("CIF/NIF:")
                        .gridColumnAlignment(.trailing)
                    TextField("Opcional", text: $clienteCIF)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                
                GridRow {
                    Text("Dirección:")
                        .gridColumnAlignment(.trailing)
                    TextField("Calle, número...", text: $clienteDireccion)
                        .textFieldStyle(.roundedBorder)
                }
                
                GridRow {
                    Text("Población:")
                        .gridColumnAlignment(.trailing)
                    HStack {
                        TextField("CP", text: $clienteCP)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        TextField("Ciudad", text: $clienteCiudad)
                            .textFieldStyle(.roundedBorder)
                        TextField("Provincia", text: $clienteProvincia)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                GridRow {
                    Text("Otros Datos:")
                        .gridColumnAlignment(.trailing)
                    TextField("Información adicional del cliente", text: $clienteOtro)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    private var productosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack {
                    Image(systemName: "cart.fill")
                    Text("Productos / Líneas")
                }
                .font(.headline)
                .foregroundStyle(.blue)
                
                Spacer()
                
                Button {
                    lineas.append(LineaTemp(productoNombre: "", isbn: "", cantidad: 1, precioUnitario: 0))
                } label: {
                    Label("Línea Libre", systemImage: "pencil.and.outline")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    mostrarSelectorProductos = true
                } label: {
                    Label("Catálogo", systemImage: "list.bullet.rectangle.portrait")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if lineas.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "basket")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No hay productos añadidos aún")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])))
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Descripción").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Cant.").frame(width: 60)
                        if !esMuestra {
                            Text("Precio").frame(width: 80, alignment: .trailing)
                            Text("Total").frame(width: 100, alignment: .trailing)
                        }
                        Spacer().frame(width: 30)
                    }
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    ForEach(lineas) { linea in
                        if let index = lineas.firstIndex(where: { $0.id == linea.id }) {
                            HStack {
                                TextField("Descripción del producto...", text: $lineas[index].productoNombre)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("Cant.", value: $lineas[index].cantidad, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                
                                if !esMuestra {
                                    TextField("Precio", value: $lineas[index].precioUnitario, format: .currency(code: "EUR").precision(.fractionLength(3)))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 90)
                                        .multilineTextAlignment(.trailing)
                                    
                                    Text(String(format: "%.2f €", linea.total))
                                        .font(.body).bold()
                                        .frame(width: 100, alignment: .trailing)
                                }
                                
                                Button(role: .destructive) {
                                    lineas.removeAll { $0.id == linea.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.red)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 30)
                            }
                            .padding(.vertical, 8)
                            
                            if linea.id != lineas.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    private var notasYResumenSection: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notas / Observaciones")
                    .font(.headline)
                    .foregroundStyle(Color.blue)
                
                TextEditor(text: $notas)
                    .font(.body)
                    .padding(4)
                    .frame(minHeight: 120)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            
            if !esMuestra {
                VStack(spacing: 12) {
                    Text("Resumen Factura")
                        .font(.headline)
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    HStack {
                        Text("Descuento (%):")
                        Spacer()
                        TextField("0", value: $descuento, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 65)
                    }
                    .font(.subheadline)
                    
                    Divider()
                    
                    if descuento > 0.0 {
                        HStack {
                            Text("Importe Bruto:")
                            Spacer()
                            Text(String(format: "%.2f €", importeBruto))
                        }
                        .font(.subheadline)
                        
                        HStack {
                            Text(String(format: "Descuento (%.0f%%):", descuento))
                            Spacer()
                            Text(String(format: "-%.2f €", importeBruto * (descuento / 100.0)))
                        }
                        .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Base Imponible:")
                        Spacer()
                        Text(String(format: "%.2f €", baseImponible))
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Menu {
                            Button("4%") { porcIva = 0.04 }
                            Button("10%") { porcIva = 0.10 }
                            Button("21%") { porcIva = 0.21 }
                            Button("0%") { porcIva = 0.0 }
                        } label: {
                            HStack(spacing: 4) {
                                Text("IVA (\(Int(porcIva * 100))%):")
                                    .foregroundStyle(Color.blue)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(Color.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        Text(String(format: "%.2f €", iva))
                    }
                    .font(.subheadline)
                    
                    Divider()
                    
                    HStack {
                        Text("TOTAL:")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f €", totalFactura))
                            .font(.title2).bold()
                            .foregroundStyle(Color.blue)
                    }
                }
                .padding()
                .frame(width: 280)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    private var nombreClienteSeleccionado: String {
        if let id = clienteID, let c = try? ctx.existingObject(with: id) as? Contacto {
            return c.nombre ?? "S/N"
        }
        return facturaAEditar?.clienteNombre ?? "No seleccionado"
    }
    
    private func guardarFactura() {
        let f = facturaAEditar ?? Factura(context: ctx)
        f.id = f.id ?? UUID()
        f.numero = numero
        f.fecha = fecha
        f.fechaCobro = fechaCobro
        f.notas = notas
        f.baseImponible = baseImponible
        f.setValue(descuento, forKey: "descuento")
        f.iva = porcIva
        f.total = totalFactura
        f.clienteNombre = clienteNombre
        f.clienteCIF = clienteCIF
        f.clienteDireccion = clienteDireccion
        f.clienteCiudad = clienteCiudad
        f.clienteCP = clienteCP
        f.clienteProvincia = clienteProvincia
        f.clienteOtro = clienteOtro
        f.setValue(emisor, forKey: "emisor")
        
        // Limpiar lineas antiguas si es edición
        if let oldLines = f.lineas as? Set<LineaFactura> {
            oldLines.forEach(ctx.delete)
        }
        
        // Añadir nuevas lineas
        for lt in lineas {
            let lf = LineaFactura(context: ctx)
            lf.id = UUID()
            lf.productoNombre = lt.productoNombre
            lf.setValue(lt.isbn, forKey: "isbn")
            lf.cantidad = Int32(lt.cantidad)
            lf.precioUnitario = lt.precioUnitario
            lf.total = lt.total
            lf.factura = f
            
            // DAR DE BAJA DEL STOCK (Solo si es una nueva factura o si se ha seleccionado un producto del catálogo)
            // Para evitar duplicar bajas en ediciones, solo lo hacemos si es factura nueva o si queremos que siempre ocurra.
            // Según la petición: "deben darse de baja del stock". 
            // Implementaremos la creación de un MovimientoAlmacen para que quede constancia.
            
            if facturaAEditar == nil, let prod = lt.producto {
                let mov = MovimientoAlmacen(context: ctx)
                mov.id = UUID()
                mov.fecha = fecha
                mov.tipoMovimiento = "Salida"
                mov.cantidad = Int32(lt.cantidad)
                mov.producto = prod
                mov.tipoAlmacen = "Trastero" // Por defecto
                mov.comprador = clienteNombre
                mov.notas = (esMuestra ? "Salida por Muestra" : "Salida por Factura \(numero)") + " [Ref:\(f.id!.uuidString)]"
                
                // Actualizar stock en el producto
                let stockActual = (prod.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(prod.stock)
                prod.setValue(Int16(max(0, stockActual - lt.cantidad)), forKey: "stock")
            }
        }
        
        try? ctx.save()
    }
}

struct SelectorProductoView: View {
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [SortDescriptor(\Producto.nombre)])
    private var productos: FetchedResults<Producto>
    var onSelect: (Producto) -> Void
    
    @State private var search = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(productos) { p in
                    if search.isEmpty || (p.nombre ?? "").localizedCaseInsensitiveContains(search) || (p.isbn ?? "").localizedCaseInsensitiveContains(search) {
                        Button {
                            onSelect(p)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.nombre ?? "S/N")
                                        .font(.headline)
                                    if let isbn = p.isbn, !isbn.isEmpty {
                                        Text("ISBN: \(isbn)")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.2f €", p.precio))
                                        .font(.body).bold()
                                        .foregroundStyle(Color.blue)
                                    Text("Stock: \(p.stock)")
                                        .font(.caption)
                                        .foregroundStyle(p.stock > 0 ? Color.secondary : Color.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Seleccionar Producto")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
            #endif
            .searchable(text: $search, prompt: "Buscar por nombre o ISBN...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}


