
//
//  AlmacenView.swift
//  AulaCRM
//
//  Gestión de stock: entradas y salidas de productos.
//

import SwiftUI
import CoreData

// MARK: - Vista principal Almacén
struct AlmacenView: View {
    @StateObject private var viewModel = AlmacenViewModel()
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\MovimientoAlmacen.fecha, order: .reverse)],
        animation: .default
    ) private var movimientos: FetchedResults<MovimientoAlmacen>

    @State private var mostrarFormulario          = false
    @State private var movimientoAEditar:          MovimientoAlmacen? = nil
    @State private var movimientoABorrar:          MovimientoAlmacen? = nil
    @State private var mostrarConfirmacionBorrado  = false

    /// Binding desde ContentView para triggear el sheet de nuevo movimiento
    @Binding var mostrarNuevo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if movimientos.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "shippingbox")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Sin movimientos registrados")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Pulsa «Nuevo Movimiento» para registrar una entrada o salida de stock.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                MovimientosTable(
                    movimientos: Array(movimientos),
                    onEdit:   { m in movimientoAEditar = m },
                    onDelete: { m in movimientoABorrar = m; mostrarConfirmacionBorrado = true }
                )
            }
        }
        .onChange(of: mostrarNuevo) { _, nuevo in
            if nuevo {
                mostrarFormulario = true
                mostrarNuevo      = false
            }
        }
        // ── Sheet: nuevo movimiento ───────────────────────────────────
        .sheet(isPresented: $mostrarFormulario) {
            FormularioMovimientoView(movimientoAEditar: nil)
                .environment(\.managedObjectContext, ctx)
        }
        // ── Sheet: editar movimiento (item: garantiza no-nil al construir la vista)
        .sheet(item: $movimientoAEditar) { mov in
            FormularioMovimientoView(movimientoAEditar: mov)
                .environment(\.managedObjectContext, ctx)
        }
        // ── Alert: confirmar borrado ──────────────────────────────────
        .alert("Borrar Movimiento", isPresented: $mostrarConfirmacionBorrado) {
            Button("Cancelar", role: .cancel) { movimientoABorrar = nil }
            Button("Borrar", role: .destructive) {
                if let mov = movimientoABorrar {
                    viewModel.borrarMovimiento(mov, context: ctx)
                    movimientoABorrar = nil
                }
            }
        } message: {
            if let mov = movimientoABorrar {
                let tipo    = mov.tipoMovimiento ?? "movimiento"
                let prod    = mov.producto?.nombre ?? "producto desconocido"
                let cant    = mov.cantidad
                Text("¿Borrar \(tipo) de \(cant) ud. de «\(prod)»?\nSe revertirá el efecto sobre el stock.")
            }
        }
    }
}

// MARK: - Tabla de historial (macOS / iPad)
private struct MovimientosTable: View {
    let movimientos: [MovimientoAlmacen]
    let onEdit:   (MovimientoAlmacen) -> Void
    let onDelete: (MovimientoAlmacen) -> Void

    private let fechaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    var body: some View {
        Table(movimientos) {
            TableColumn("Fecha") { m in
                Text(m.fecha.map { fechaFormatter.string(from: $0) } ?? "—")
                    .font(.body)
            }
            .width(91)

            TableColumn("Tipo") { m in
                HStack(spacing: 6) {
                    Image(systemName: m.tipoMovimiento == "Entrada" ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(m.tipoMovimiento == "Entrada" ? Color.green : Color.orange)
                    Text(m.tipoMovimiento ?? "—")
                        .foregroundStyle(m.tipoMovimiento == "Entrada" ? Color.green : Color.orange)
                        .fontWeight(.semibold)
                }
            }
            .width(100)

            TableColumn("Producto") { m in
                Text(m.producto?.nombre ?? "—")
            }
            .width(min: 140, ideal: 200)

            TableColumn("Cant.") { m in
                let signo = m.tipoMovimiento == "Entrada" ? "+" : "−"
                Text("\(signo)\(m.cantidad)")
                    .foregroundStyle(m.tipoMovimiento == "Entrada" ? Color.green : Color.orange)
                    .fontWeight(.medium)
            }
            .width(60)

            TableColumn("Almacén") { m in
                Text(m.tipoAlmacen ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(90)

            TableColumn("Persona") { m in
                if m.tipoMovimiento == "Salida" {
                    Text(m.comprador.flatMap { $0.isEmpty ? nil : $0 } ?? "—")
                        .foregroundStyle(.secondary)
                } else {
                    Text(m.vendedor.flatMap { $0.isEmpty ? nil : $0 } ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 100, ideal: 150)

            TableColumn("Notas") { m in
                Text(m.notas ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            TableColumn("Acciones") { m in
                HStack(spacing: 10) {
                    Button {
                        onEdit(m)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Editar movimiento")

                    Button {
                        onDelete(m)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Borrar movimiento")
                }
            }
            .width(70)
        }
    }
}

// MARK: - Formulario de movimiento (nuevo y edición)
struct FormularioMovimientoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx

    /// Si se pasa un movimiento existente, el formulario actúa en modo edición.
    var movimientoAEditar: MovimientoAlmacen?

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Producto.nombre, comparator: .localizedStandard)]
    ) private var productos: FetchedResults<Producto>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Contacto.nombre, comparator: .localizedStandard)]
    ) private var contactos: FetchedResults<Contacto>

    // ── Campos del formulario ─────────────────────────────────────
    @State private var tipoMovimiento: TipoMovimiento = .entrada
    @State private var productoSeleccionado: Producto? = nil
    @State private var cantidad: Int = 1
    @State private var fecha: Date = Date()
    @State private var comprador: String = ""
    @State private var vendedor: String = ""
    @State private var notas: String = ""
    @State private var tipoAlmacen: TipoAlmacen = .trastero
    @State private var mostrarSelectorColegio = false

    @State private var errorMsg: String? = nil

    private var esEdicion: Bool { movimientoAEditar != nil }

    enum TipoMovimiento: String, CaseIterable {
        case entrada = "Entrada"
        case salida  = "Salida"
    }

    enum TipoAlmacen: String, CaseIterable {
        case trastero = "Trastero"
        case casa     = "Casa"
    }

    // Stock actual del producto, descontando el efecto del movimiento anterior si estamos editando
    private var stockBase: Int {
        guard let p = productoSeleccionado else { return 0 }
        let real: Int = (p.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(p.stock)
        guard let mov = movimientoAEditar, mov.producto == p else { return real }
        // Revertir el impacto previo para mostrar el "stock limpio" antes de este movimiento
        let cantPrev = Int(mov.cantidad)
        return mov.tipoMovimiento == "Entrada" ? real - cantPrev : real + cantPrev
    }

    private var stockResultante: Int {
        switch tipoMovimiento {
        case .entrada: return stockBase + cantidad
        case .salida:  return stockBase - cantidad
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Cabecera ─────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(esEdicion ? "Editar Movimiento" : "Nuevo Movimiento de Almacén")
                        .font(.title2).bold()
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Tipo de movimiento ────────────────────────────
                    FormSection(title: "Tipo de Movimiento", icon: "arrow.up.arrow.down.circle") {
                        Picker("Tipo de movimiento", selection: $tipoMovimiento) {
                            Label("Entrada", systemImage: "plus.circle.fill")
                                .tag(TipoMovimiento.entrada)
                            Label("Salida", systemImage: "minus.circle.fill")
                                .tag(TipoMovimiento.salida)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // ── Producto ──────────────────────────────────────
                    FormSection(title: "Producto", icon: "book.closed") {
                        Picker("Producto", selection: $productoSeleccionado) {
                            Text("Selecciona un producto…").tag(Optional<Producto>.none)
                            ForEach(productos) { p in
                                Text(p.nombre ?? "—").tag(Optional(p))
                            }
                        }
                        .labelsHidden()
                        #if os(macOS)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #endif

                        if productoSeleccionado != nil {
                            HStack(spacing: 20) {
                                Label("Stock antes: \(stockBase)", systemImage: "cube.box")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if errorMsg == nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: tipoMovimiento == .entrada ? "plus.circle.fill" : "minus.circle.fill")
                                        Text("Stock resultante: \(stockResultante)")
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(stockResultante < 0 ? .red : (tipoMovimiento == .entrada ? .green : .orange))
                                }
                            }
                            .padding(.top, 2)
                        }
                    }

                    // ── Cantidad ──────────────────────────────────────
                    FormSection(title: "Cantidad", icon: "number") {
                        HStack(spacing: 12) {
                            Stepper("", value: $cantidad, in: 1...999_999)
                                .labelsHidden()
                            Text("\(cantidad) unidades")
                                .font(.body.monospacedDigit())
                                .frame(minWidth: 100, alignment: .leading)
                        }
                    }

                    // ── Fecha ─────────────────────────────────────────
                    FormSection(title: "Fecha", icon: "calendar") {
                        HStack {
                            DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                                .labelsHidden()
                                #if os(macOS)
                                .datePickerStyle(.field)
                                #else
                                .datePickerStyle(.compact)
                                #endif
                            Spacer()
                        }
                    }

                    // ── Persona ───────────────────────────────────────
                    FormSection(
                        title: tipoMovimiento == .salida ? "Comprador" : "Vendedor",
                        icon:  tipoMovimiento == .salida ? "person.badge.plus" : "person.badge.minus"
                    ) {
                        if tipoMovimiento == .salida {
                            // Comprador: texto libre + sugerencias de colegios + botón de filtro
                            HStack(spacing: 8) {
                                TextField("Nombre del comprador (opcional)", text: $comprador)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    mostrarSelectorColegio = true
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.bordered)
                                .help("Filtrar y seleccionar colegio")
                            }
                        } else {
                            TextField("Nombre del vendedor (opcional)", text: $vendedor)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // ── Almacén ───────────────────────────────────────
                    FormSection(title: "Almacén", icon: "house.and.flag") {
                        Picker("Tipo de almacén", selection: $tipoAlmacen) {
                            Label("Trastero", systemImage: "shippingbox.fill")
                                .tag(TipoAlmacen.trastero)
                            Label("Casa", systemImage: "house.fill")
                                .tag(TipoAlmacen.casa)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // ── Notas ─────────────────────────────────────────
                    FormSection(title: "Notas", icon: "note.text") {
                        TextField("Observaciones adicionales…", text: $notas, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)
                    }

                    // ── Error ─────────────────────────────────────────
                    if let msg = errorMsg {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(msg)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }

            Divider()

            // ── Botones ───────────────────────────────────────────────
            HStack(spacing: 12) {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.escape)

                Button {
                    guardarMovimiento()
                } label: {
                    Label(esEdicion ? "Guardar Cambios" : "Guardar Movimiento",
                          systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(productoSeleccionado == nil)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .frame(minWidth: 560, minHeight: 720)
        .onAppear { cargarDatosEdicion() }
        .sheet(isPresented: $mostrarSelectorColegio) {
            SelectorContactoView(seleccion: $comprador, contactos: Array(contactos))
        }
    }

    // MARK: - Cargar datos si es edición
    private func cargarDatosEdicion() {
        guard let mov = movimientoAEditar else { return }
        tipoMovimiento     = mov.tipoMovimiento == "Salida" ? .salida : .entrada
        productoSeleccionado = mov.producto
        cantidad           = Int(mov.cantidad)
        fecha              = mov.fecha ?? Date()
        comprador          = mov.comprador ?? ""
        vendedor           = mov.vendedor ?? ""
        notas              = mov.notas ?? ""
        tipoAlmacen        = mov.tipoAlmacen == "Casa" ? .casa : .trastero
    }

    // MARK: - Guardar (nuevo o edición)
    private func guardarMovimiento() {
        errorMsg = nil

        guard let producto = productoSeleccionado else {
            errorMsg = "Debes seleccionar un producto."
            return
        }
        guard cantidad > 0 else {
            errorMsg = "La cantidad debe ser mayor que cero."
            return
        }

        let stockReal: Int = (producto.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(producto.stock)

        if esEdicion {
            // ── Modo edición ──────────────────────────────────────────
            guard let mov = movimientoAEditar else { return }

            // 1. Revertir impacto anterior sobre el stock (del mismo producto o de uno diferente)
            if let productoAnterior = mov.producto {
                let cantAnterior  = Int(mov.cantidad)
                let stockAnterior: Int = (productoAnterior.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(productoAnterior.stock)
                let stockRevertido: Int = mov.tipoMovimiento == "Entrada"
                    ? stockAnterior - cantAnterior
                    : stockAnterior + cantAnterior
                productoAnterior.setValue(Int16(max(0, stockRevertido)), forKey: "stock")
            }

            // 2. Validar stock suficiente para la nueva operación
            let stockTrasRevertir: Int = (producto.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(producto.stock)
            if tipoMovimiento == .salida && cantidad > stockTrasRevertir {
                errorMsg = "Stock insuficiente tras revertir el movimiento anterior: \(stockTrasRevertir) ud."
                ctx.rollback()
                return
            }

            // 3. Aplicar nuevo impacto
            let nuevoStock = tipoMovimiento == .entrada
                ? stockTrasRevertir + cantidad
                : stockTrasRevertir - cantidad
            producto.setValue(Int16(nuevoStock), forKey: "stock")

            // 4. Actualizar campos del movimiento
            mov.tipoMovimiento = tipoMovimiento.rawValue
            mov.cantidad       = Int32(cantidad)
            mov.fecha          = fecha
            mov.notas          = notas.trimmingCharacters(in: .whitespacesAndNewlines)
            mov.tipoAlmacen    = tipoAlmacen.rawValue
            mov.comprador      = tipoMovimiento == .salida  ? comprador.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            mov.vendedor       = tipoMovimiento == .entrada ? vendedor.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            mov.producto       = producto

        } else {
            // ── Modo nuevo ────────────────────────────────────────────
            if tipoMovimiento == .salida && cantidad > stockReal {
                errorMsg = "No hay suficiente stock. Stock actual: \(stockReal) ud."
                return
            }

            let mov = MovimientoAlmacen(context: ctx)
            mov.id             = UUID()
            mov.tipoMovimiento = tipoMovimiento.rawValue
            mov.cantidad       = Int32(cantidad)
            mov.fecha          = fecha
            mov.notas          = notas.trimmingCharacters(in: .whitespacesAndNewlines)
            mov.tipoAlmacen    = tipoAlmacen.rawValue
            mov.comprador      = tipoMovimiento == .salida  ? comprador.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            mov.vendedor       = tipoMovimiento == .entrada ? vendedor.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            mov.producto       = producto

            let nuevoStock = tipoMovimiento == .entrada ? stockReal + cantidad : stockReal - cantidad
            producto.setValue(Int16(nuevoStock), forKey: "stock")
        }

        do {
            try ctx.save()
            dismiss()
        } catch {
            errorMsg = "Error al guardar: \(error.localizedDescription)"
            ctx.rollback()
        }
    }
}

// MARK: - Componente auxiliar: sección de formulario
private struct FormSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}

// MARK: - ComboBox: texto libre + sugerencias de colegios
struct ComboBoxContacto: View {
    @Binding var texto: String
    let placeholder: String
    let contactos: [Contacto]

    @State private var mostrarSugerencias = false
    @FocusState private var campoActivo: Bool

    /// Todos los nombres de contactos disponibles, ordenados
    private var todosLosNombres: [String] {
        contactos
            .compactMap { $0.nombre?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// Lista filtrada: si hay texto filtra, si no muestra todos
    private var sugerencias: [String] {
        let query = texto.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return Array(todosLosNombres.prefix(12))
        }
        return todosLosNombres
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ── Campo de texto + botón desplegable ────────────────────
            HStack(spacing: 0) {
                TextField(placeholder, text: $texto)
                    .textFieldStyle(.roundedBorder)
                    .focused($campoActivo)
                    .onChange(of: texto) { _, _ in
                        mostrarSugerencias = true
                    }
                    .onChange(of: campoActivo) { _, activo in
                        if activo {
                            mostrarSugerencias = true
                        } else {
                            // Pequeño delay para permitir el tap en la sugerencia
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                mostrarSugerencias = false
                            }
                        }
                    }

                // Botón para desplegar/plegar la lista sin escribir
                Button {
                    if mostrarSugerencias {
                        mostrarSugerencias = false
                        campoActivo = false
                    } else {
                        mostrarSugerencias = true
                        campoActivo = true
                    }
                } label: {
                    Image(systemName: mostrarSugerencias ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }

            // ── Lista desplegable ──────────────────────────────────────
            if mostrarSugerencias && !sugerencias.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Cabecera informativa
                    if texto.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                            Text("Selecciona un colegio o escribe libremente")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        Divider().padding(.horizontal, 8)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sugerencias, id: \.self) { nombre in
                                Button {
                                    texto = nombre
                                    mostrarSugerencias = false
                                    campoActivo = false
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "building.2")
                                            .font(.caption)
                                            .foregroundStyle(.blue.opacity(0.7))
                                        Text(nombre)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                #if os(macOS)
                                .background(Color(NSColor.controlBackgroundColor))
                                #endif
                                #if !os(macOS)
                                .hoverEffect(.highlight)
                                #endif

                                if nombre != sugerencias.last {
                                    Divider().padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                #if os(macOS)
                .background(Color(NSColor.controlBackgroundColor))
                #else
                .background(Color(.secondarySystemBackground))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Selector de Contacto con Filtros (Replicando ContentView)
struct SelectorContactoView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var seleccion: String
    let contactos: [Contacto]
    var onSelect: ((Contacto) -> Void)? = nil

    @State private var search = ""
    @State private var selectedProvincia = "Todos"
    @State private var selectedCiudad    = "Todos"
    @State private var selectedCP        = "Todos"
    @State private var selectedRegimen   = "Todos"
    @State private var selectedCliente   = "Todos"
    @State private var showFilters: Bool = true

    // Lógica de filtrado idéntica a ContentView
    private var provinciasUnicas: [String] { ["Todos"] + Array(Set(contactos.compactMap { $0.provincia?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted() }
    private var ciudadesUnicas:   [String] {
        let filteredByProv = contactos.filter { c in
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
        let filtered = contactos.filter { c in
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

    private var filteredContacts: [Contacto] {
        let buscado = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return contactos.filter { c in
            if selectedProvincia != "Todos", (c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(selectedProvincia) != .orderedSame { return false }
            if selectedCiudad != "Todos", (c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(selectedCiudad) != .orderedSame { return false }
            if selectedCP != "Todos", (c.cp ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(selectedCP) != .orderedSame { return false }
            if selectedRegimen != "Todos", (c.regimen ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(selectedRegimen) != .orderedSame { return false }
            if selectedCliente != "Todos" {
                let isCliente = (c.value(forKey: "cliente") as? Bool) ?? false
                if selectedCliente == "Sí" && !isCliente { return false }
                if selectedCliente == "No" && isCliente  { return false }
            }
            if buscado.isEmpty { return true }
            return (c.nombre ?? "").localizedCaseInsensitiveContains(buscado) || (c.ciudad ?? "").localizedCaseInsensitiveContains(buscado)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
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
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Section("Resultados (\(filteredContacts.count))") {
                        ForEach(filteredContacts) { c in
                            Button {
                                seleccion = c.nombre ?? ""
                                onSelect?(c)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.nombre ?? "—")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("\(c.ciudad ?? "") \(c.provincia ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
            .navigationTitle("Seleccionar Colegio")
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 600)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .searchable(text: $search, prompt: "Buscar por nombre...")
        }
        .onChange(of: selectedProvincia) { _, _ in
            if !ciudadesUnicas.contains(selectedCiudad) { selectedCiudad = "Todos" }
            if !cpsUnicos.contains(selectedCP) { selectedCP = "Todos" }
        }
        .onChange(of: selectedCiudad) { _, _ in
            if !cpsUnicos.contains(selectedCP) { selectedCP = "Todos" }
        }
    }
}
