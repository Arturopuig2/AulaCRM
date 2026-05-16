import SwiftUI
import CoreData
import EventKit


struct ReservasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Reserva.fechaInicio, order: .forward)],
        animation: .default
    ) private var reservas: FetchedResults<Reserva>
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Contacto.nombre, comparator: .localizedStandard)],
        animation: .default
    ) private var contactos: FetchedResults<Contacto>
    
    @State private var selectedDate = Date()
    @State private var showingForm = false
    @State private var selectedHour: Int? = nil
    
    // Form fields
    @State private var formColegio: Contacto? = nil
    @State private var formNotas: String = ""
    @State private var editingReserva: Reserva? = nil
    @State private var formExternalEventID: String? = nil
    
    @State private var externalEvents: [EKEvent] = []
    
    @State private var showingColegioSelector = false
    @State private var dummySelection = ""
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    @State private var showingDeleteAlert = false
    @State private var reservaABorrar: Reserva? = nil
    
    @StateObject private var syncManager = CalendarSyncManager.shared
    
    // Notas diarias
    @AppStorage("calendario_notas_diarias") private var notasDiariasData: Data = Data()
    
    private func getDailyNote() -> String {
        let dict = (try? JSONDecoder().decode([String: String].self, from: notasDiariasData)) ?? [:]
        return dict[currentDayKey] ?? ""
    }
    
    private func saveDailyNote(_ text: String) {
        var dict = (try? JSONDecoder().decode([String: String].self, from: notasDiariasData)) ?? [:]
        dict[currentDayKey] = text
        if let data = try? JSONEncoder().encode(dict) {
            notasDiariasData = data
        }
    }
    
    private var currentDayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
    
    @State private var localDailyNote: String = ""

    private var datesWithVisits: Set<DateComponents> {
        let calendar = Calendar.current
        let components = reservas.compactMap { res -> DateComponents? in
            guard let date = res.fechaInicio else { return nil }
            return calendar.dateComponents([.year, .month, .day], from: date)
        }
        return Set(components)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header con CustomCalendar y Notas
            HStack(alignment: .top, spacing: 30) {
                CustomCalendarView(selectedDate: $selectedDate, datesWithVisits: datesWithVisits)
                    .frame(width: 300)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notas del día", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $localDailyNote)
                        .font(.body)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .textBackgroundColor))
                                .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .onChange(of: localDailyNote) { _, newValue in
                            saveDailyNote(newValue)
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            }
            .padding()
            .onAppear {
                localDailyNote = getDailyNote()
            }
            .onChange(of: selectedDate) { _, _ in
                localDailyNote = getDailyNote()
            }
            
            Divider()
            
            Text("Reservas para \(selectedDate.formatted(date: .long, time: .omitted))")
                .font(.title3)
                .bold()
                .padding()
            
            List {
                ForEach(8...18, id: \.self) { hour in
                    let reserva = reservaFor(hour: hour, on: selectedDate)
                    let external = externalEventFor(hour: hour, on: selectedDate)
                    
                    HStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Columna Hora
                            Text(String(format: "%02d:00", hour))
                                .font(.headline)
                                .frame(width: 50, alignment: .leading)
                                .foregroundStyle(.secondary)
                            
                            // Área de Contenido
                            VStack(alignment: .leading, spacing: 4) {
                                if let res = reserva {
                                    Text(res.contacto?.nombre ?? "Colegio sin asignar")
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                    if let n = res.notas, !n.isEmpty {
                                        Text(n)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } else if let ext = external {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar.badge.plus")
                                                .font(.caption)
                                            Text(ext.title ?? "Evento Externo")
                                        }
                                        .fontWeight(.bold)
                                        .foregroundStyle(.purple)
                                        
                                        Text("Pulsa para vincular como visita")
                                            .font(.caption2)
                                            .foregroundStyle(.purple.opacity(0.8))
                                    }
                                } else {
                                    Text("Disponible")
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .italic()
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let res = reserva {
                                openForm(for: res)
                            } else if let ext = external {
                                openForm(for: ext, hour: hour)
                            } else {
                                openForm(for: hour)
                            }
                        }
                        
                        // Botón de Borrar (Independiente)
                        if let res = reserva {
                            Button(role: .destructive) {
                                reservaABorrar = res
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(reserva != nil ? Color.blue.opacity(0.12) : (external != nil ? Color.purple.opacity(0.12) : Color.clear))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    )
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.plain)
            #endif
        }
        .sheet(isPresented: $showingForm) {
            formView
        }
        .alert("Error de Calendario", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Borrar Cita", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {
                reservaABorrar = nil
            }
            Button("Borrar", role: .destructive) {
                if let res = reservaABorrar {
                    borrarReserva(res)
                    reservaABorrar = nil
                }
            }
        } message: {
            Text("¿Estás seguro de que quieres borrar esta cita? También se eliminará de tu calendario externo si estaba vinculada.")
        }
        .task {
            let granted = await syncManager.requestAccess()
            if granted {
                loadExternalEvents()
            }
        }
        .onChange(of: selectedDate) { _ in
            loadExternalEvents()
        }
    }
    
    private func loadExternalEvents() {
        if syncManager.isAuthorized {
            externalEvents = syncManager.fetchEvents(for: selectedDate)
        }
    }
    
    private func reservaFor(hour: Int, on date: Date) -> Reserva? {
        let calendar = Calendar.current
        return reservas.first { res in
            guard let resDate = res.fechaInicio else { return false }
            return calendar.isDate(resDate, inSameDayAs: date) &&
                   calendar.component(.hour, from: resDate) == hour
        }
    }
    
    private func externalEventFor(hour: Int, on date: Date) -> EKEvent? {
        let calendar = Calendar.current
        return externalEvents.first { ev in
            return calendar.isDate(ev.startDate, inSameDayAs: date) &&
                   calendar.component(.hour, from: ev.startDate) == hour &&
                   !reservas.contains(where: { $0.eventoID == ev.eventIdentifier })
        }
    }
    
    private func openForm(for hour: Int) {
        editingReserva = nil
        selectedHour = hour
        formColegio = nil
        formNotas = ""
        formExternalEventID = nil
        showingForm = true
    }
    
    private func openForm(for reserva: Reserva) {
        editingReserva = reserva
        selectedHour = Calendar.current.component(.hour, from: reserva.fechaInicio ?? Date())
        formColegio = reserva.contacto
        formNotas = reserva.notas ?? ""
        formExternalEventID = nil
        showingForm = true
    }
    
    private func openForm(for ext: EKEvent, hour: Int) {
        editingReserva = nil
        selectedHour = hour
        
        if let title = ext.title {
            formColegio = contactos.first { c in
                guard let nombre = c.nombre else { return false }
                return title.localizedCaseInsensitiveContains(nombre) || nombre.localizedCaseInsensitiveContains(title)
            }
        } else {
            formColegio = nil
        }
        
        formNotas = ext.notes ?? ""
        formExternalEventID = ext.eventIdentifier
        showingForm = true
    }
    
    private var formView: some View {
        NavigationStack {
            Form {
                Section("Colegio a visitar") {
                    HStack {
                        Text(formColegio?.nombre ?? "Selecciona un colegio...")
                            .foregroundStyle(formColegio == nil ? .secondary : .primary)
                        Spacer()
                        Button("Buscar") {
                            showingColegioSelector = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Section("Notas de la reserva") {
                    TextField("Añadir notas adicionales...", text: $formNotas, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle(editingReserva == nil ? "Nueva Reserva - \(String(format: "%02d:00", selectedHour ?? 8))" : "Editar Reserva")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showingForm = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardarReserva() }
                        .disabled(formColegio == nil)
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 350)
            .sheet(isPresented: $showingColegioSelector) {
                SelectorContactoView(
                    seleccion: $dummySelection,
                    contactos: Array(contactos),
                    onSelect: { contacto in
                        formColegio = contacto
                    }
                )
            }
        }
    }
    
    private func guardarReserva() {
        let reserva = editingReserva ?? Reserva(context: ctx)
        reserva.id = reserva.id ?? UUID()
        reserva.contacto = formColegio
        reserva.notas = formNotas
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = selectedHour
        components.minute = 0
        let startDate = calendar.date(from: components) ?? Date()
        
        var endComponents = components
        endComponents.hour = (selectedHour ?? 8) + 1
        let endDate = calendar.date(from: endComponents) ?? startDate.addingTimeInterval(3600)
        
        reserva.fechaInicio = startDate
        reserva.fechaFin = endDate
        
        // Sincronizar con Google Calendar a través de EventKit
        let title = "Visita: \(formColegio?.nombre ?? "Colegio")"
        if let eventID = syncManager.saveEvent(title: title, startDate: startDate, endDate: endDate, notes: formNotas, existingEventID: reserva.eventoID ?? formExternalEventID) {
            reserva.eventoID = eventID
        } else {
            errorMessage = "No se pudo guardar la reserva en tu calendario de Apple/Google. Comprueba que le diste permisos a la app en Ajustes > Privacidad > Calendarios."
            showingErrorAlert = true
        }
        
        formExternalEventID = nil
        
        do {
            try ctx.save()
        } catch {
            print("Error guardando reserva: \(error.localizedDescription)")
        }
        
        showingForm = false
    }
    
    private func borrarReserva(_ reserva: Reserva) {
        if let eventID = reserva.eventoID {
            syncManager.deleteEvent(eventID: eventID)
        }
        ctx.delete(reserva)
        do {
            try ctx.save()
        } catch {
            print("Error borrando reserva: \(error.localizedDescription)")
        }
    }
}
