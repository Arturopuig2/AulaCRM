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
    @State private var reservaTipoLibre: Bool = false
    @State private var formTitulo: String = ""
    @State private var formHoraInicio: Int = 8
    @State private var formHoraFin: Int = 9
    
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
                                    HStack(spacing: 6) {
                                        Text(res.contacto?.nombre ?? res.titulo ?? "Cita sin asignar")
                                            .fontWeight(.bold)
                                            .foregroundStyle(.primary)
                                        
                                        if let start = res.fechaInicio, let end = res.fechaFin {
                                            let startHour = Calendar.current.component(.hour, from: start)
                                            let endHour = Calendar.current.component(.hour, from: end)
                                            if endHour - startHour > 1 {
                                                Text("(\(String(format: "%02d:00", startHour))-\(String(format: "%02d:00", endHour)))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                    if let n = res.notas, !n.isEmpty {
                                        Text(n)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } else if let ext = external {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.badge.plus")
                                                    .font(.caption)
                                                Text(ext.title ?? "Evento Externo")
                                            }
                                            .fontWeight(.bold)
                                            .foregroundStyle(.purple)
                                            
                                            let startHour = Calendar.current.component(.hour, from: ext.startDate)
                                            let endHour = Calendar.current.component(.hour, from: ext.endDate)
                                            if endHour - startHour > 1 {
                                                Text("(\(String(format: "%02d:00", startHour))-\(String(format: "%02d:00", endHour)))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.purple)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        
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
            guard let startDate = res.fechaInicio, let endDate = res.fechaFin else { return false }
            guard calendar.isDate(startDate, inSameDayAs: date) else { return false }
            let startHour = calendar.component(.hour, from: startDate)
            let endHour = calendar.component(.hour, from: endDate)
            return hour >= startHour && hour < endHour
        }
    }
    
    private func externalEventFor(hour: Int, on date: Date) -> EKEvent? {
        let calendar = Calendar.current
        return externalEvents.first { ev in
            guard calendar.isDate(ev.startDate, inSameDayAs: date) else { return false }
            let startHour = calendar.component(.hour, from: ev.startDate)
            let endHour = calendar.component(.hour, from: ev.endDate)
            let hourRange = startHour..<max(startHour + 1, endHour)
            return hourRange.contains(hour) && !reservas.contains(where: { $0.eventoID == ev.eventIdentifier })
        }
    }
    
    private func openForm(for hour: Int) {
        editingReserva = nil
        selectedHour = hour
        formHoraInicio = hour
        formHoraFin = hour + 1
        formColegio = nil
        formNotas = ""
        formExternalEventID = nil
        reservaTipoLibre = false
        formTitulo = ""
        showingForm = true
    }
    
    private func openForm(for reserva: Reserva) {
        editingReserva = reserva
        let start = Calendar.current.component(.hour, from: reserva.fechaInicio ?? Date())
        let end = Calendar.current.component(.hour, from: reserva.fechaFin ?? Date())
        selectedHour = start
        formHoraInicio = start
        formHoraFin = max(start + 1, end)
        formColegio = reserva.contacto
        formNotas = reserva.notas ?? ""
        formExternalEventID = nil
        reservaTipoLibre = (reserva.contacto == nil)
        formTitulo = reserva.titulo ?? ""
        showingForm = true
    }
    
    private func openForm(for ext: EKEvent, hour: Int) {
        editingReserva = nil
        selectedHour = hour
        let start = Calendar.current.component(.hour, from: ext.startDate)
        let end = Calendar.current.component(.hour, from: ext.endDate)
        formHoraInicio = start
        formHoraFin = max(start + 1, end)
        
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
        reservaTipoLibre = (formColegio == nil)
        formTitulo = ext.title ?? ""
        showingForm = true
    }
    
    private var formView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Tipo de cita
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipo de cita")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Picker("Tipo de Reserva", selection: $reservaTipoLibre) {
                        Text("Colegio de la lista").tag(false)
                        Text("Cita libre / Otro").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                // Condicional: Colegio o Cita Libre
                if reservaTipoLibre {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre de la cita")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField("Escribe el nombre o título de la reserva...", text: $formTitulo)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Colegio a visitar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(formColegio?.nombre ?? "Selecciona un colegio...")
                                .foregroundStyle(formColegio == nil ? .secondary : .primary)
                            Spacer()
                            Button("Buscar") {
                                showingColegioSelector = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
                
                // Notas de la reserva
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notas de la reserva")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $formNotas)
                        .font(.body)
                        .padding(4)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .frame(height: 100)
                }
                
                // Horario de la reserva
                VStack(alignment: .leading, spacing: 6) {
                    Text("Horario de la reserva")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                        
                        Picker("Desde", selection: $formHoraInicio) {
                            ForEach(8...18, id: \.self) { h in
                                Text(String(format: "%02d:00", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)
                        
                        Text("a")
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                        
                        Picker("Hasta", selection: $formHoraFin) {
                            ForEach((formHoraInicio + 1)...19, id: \.self) { h in
                                Text(String(format: "%02d:00", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .onChange(of: formHoraInicio) { _, newInicio in
                if formHoraFin <= newInicio {
                    formHoraFin = newInicio + 1
                }
            }
            .padding()
            .navigationTitle(editingReserva == nil ? "Nueva Reserva - \(String(format: "%02d:00", selectedHour ?? 8))" : "Editar Reserva")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showingForm = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardarReserva() }
                        .disabled(reservaTipoLibre ? formTitulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : formColegio == nil)
                }
            }
            .frame(minWidth: 420, minHeight: 440)
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
        
        if reservaTipoLibre {
            reserva.contacto = nil
            reserva.titulo = formTitulo.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            reserva.contacto = formColegio
            reserva.titulo = nil
        }
        reserva.notas = formNotas
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = formHoraInicio
        components.minute = 0
        let startDate = calendar.date(from: components) ?? Date()
        
        var endComponents = components
        endComponents.hour = formHoraFin
        let endDate = calendar.date(from: endComponents) ?? startDate.addingTimeInterval(TimeInterval((formHoraFin - formHoraInicio) * 3600))
        
        reserva.fechaInicio = startDate
        reserva.fechaFin = endDate
        
        // Sincronizar con Google Calendar a través de EventKit
        let title = reservaTipoLibre ? formTitulo.trimmingCharacters(in: .whitespacesAndNewlines) : "Visita: \(formColegio?.nombre ?? "Colegio")"
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
