//
//  CampanaEjecucionView.swift
//  AulaCRM
//
//  Created for campaign execution screen.
//

import SwiftUI
import CoreData

struct CampanaEjecucionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let plantilla: PlantillaEmail
    
    // Obtener todos los contactos del CRM
    @FetchRequest(sortDescriptors: [SortDescriptor(\Contacto.nombre)])
    private var todosLosContactos: FetchedResults<Contacto>
    
    @StateObject private var queueManager: CampanaQueueManager
    
    // Estados de filtros idénticos a los de Colegios
    @State private var selectedProvincia = "València"
    @State private var selectedCiudad    = "VALÈNCIA"
    @State private var selectedCP        = "Todos"
    @State private var selectedRegimen   = "Todos"
    @State private var selectedCliente   = "Todos"
    @State private var showFilters       = true
    @State private var delaySeconds: Double = 45.0
    
    init(plantilla: PlantillaEmail, context: NSManagedObjectContext) {
        self.plantilla = plantilla
        _queueManager = StateObject(wrappedValue: CampanaQueueManager(viewContext: context))
    }
    
    // MARK: - Valores Únicos para los Pickers
    private var provinciasUnicas: [String] {
        let list = todosLosContactos.compactMap { $0.provincia?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(list)).sorted()
    }
    
    private var ciudadesUnicas: [String] {
        let filteredByProv = todosLosContactos.filter { c in
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
        let filtered = todosLosContactos.filter { c in
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
    
    private var regimenesUnicos: [String] {
        let list = todosLosContactos.compactMap { $0.regimen?.trimmingCharacters(in: .whitespacesAndNewlines)  }.filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(list)).sorted()
    }
    
    // Destinatarios filtrados listos para recibir el correo
    private var destinatariosFiltrados: [Contacto] {
        todosLosContactos.filter { c in
            // Obligatorio tener correo
            guard let email = c.email, !email.isEmpty else { return false }
            
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

            if selectedCliente != "Todos" {
                if selectedCliente == "Sí" && !c.esCliente { return false }
                if selectedCliente == "No" && c.esCliente  { return false }
            }
            
            return true
        }
    }
    
    private var tiempoEstimadoTexto: String {
        let totalCorreos = destinatariosFiltrados.count
        guard totalCorreos > 0 else { return "0 minutos" }
        let totalSegundos = Double(totalCorreos - 1) * delaySeconds
        let totalMinutos = Int(totalSegundos / 60)
        if totalMinutos == 0 {
            return "\(Int(totalSegundos)) segundos"
        }
        return "\(totalMinutos) minutos"
    }
    
    var body: some View {
        NavigationStack {
            HSplitView {
                // Columna Izquierda: Configuración de Destinatarios y Envío
                VStack(alignment: .leading, spacing: 16) {
                    Text("Destinatarios y Parámetros")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    if !queueManager.isSending {
                        // Selección de Destinatarios (Filtros idénticos a Colegios)
                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                        
                        // Configuración del Retardo
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Retardo entre Envíos:")
                                    .bold()
                                Spacer()
                                Text("\(Int(delaySeconds)) segundos")
                                    .foregroundColor(.blue)
                                    .bold()
                            }
                            
                            Slider(value: $delaySeconds, in: 5...120, step: 5)
                            
                            Text("Espaciar los correos previene que tu servidor sea bloqueado o clasificado como spam.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        // Mostrar filtros bloqueados mientras envía
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Campaña en curso...")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.blue)
                            
                            Text("Filtros aplicados:")
                                .font(.caption)
                                .bold()
                            if selectedProvincia != "Todos" { Text("• Provincia: \(selectedProvincia)").font(.caption) }
                            if selectedCiudad != "Todos" { Text("• Ciudad: \(selectedCiudad)").font(.caption) }
                            if selectedCP != "Todos" { Text("• CP: \(selectedCP)").font(.caption) }
                            if selectedRegimen != "Todos" { Text("• Régimen: \(selectedRegimen)").font(.caption) }
                            if selectedCliente != "Todos" { Text("• Cliente: \(selectedCliente)").font(.caption) }
                            Text("• Retardo: \(Int(delaySeconds))s")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Resumen Informativo
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Destinatarios que coinciden:")
                            Spacer()
                            Text("\(destinatariosFiltrados.count)")
                                .bold()
                        }
                        HStack {
                            Text("Tiempo estimado total:")
                            Spacer()
                            Text(tiempoEstimadoTexto)
                                .bold()
                        }
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .border(Color.secondary.opacity(0.1), width: 1)
                    
                    Spacer()
                    
                    // Botonera de Control
                    HStack(spacing: 12) {
                        if !queueManager.isSending {
                            Button(action: iniciarEnvio) {
                                Label("Iniciar Campaña", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(destinatariosFiltrados.isEmpty)
                        } else {
                            if queueManager.isPaused {
                                Button(action: reanudarEnvio) {
                                    Label("Reanudar", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Button(action: queueManager.pausarEnvio) {
                                    Label("Pausar", systemImage: "pause.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                            
                            Button(action: queueManager.detenerEnvio) {
                                Label("Detener / Reiniciar", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding()
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                
                // Columna Derecha: Monitorización en Tiempo Real y Logs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Progreso y Bitácora")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    // Vista del progreso actual
                    if queueManager.isSending {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Progreso:")
                                    .bold()
                                Spacer()
                                Text("\(queueManager.currentIndex) de \(destinatariosFiltrados.count) enviados")
                                    .bold()
                            }
                            .font(.subheadline)
                            
                            ProgressView(value: Double(queueManager.currentIndex), total: Double(destinatariosFiltrados.count))
                                .tint(.blue)
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Lista de logs de envíos
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logs de Envío:")
                            .font(.subheadline)
                            .bold()
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                if queueManager.logs.isEmpty {
                                    Text("Los logs del motor SMTP aparecerán aquí cuando inicies el envío.")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .padding()
                                } else {
                                    ForEach(queueManager.logs, id: \.self) { log in
                                        Text(log)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(colorForLog(log))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .border(Color.secondary.opacity(0.15))
                    }
                }
                .padding()
                .frame(minWidth: 400, idealWidth: 500)
            }
            .navigationTitle("Enviar Campaña: \(plantilla.titulo ?? "Sin título")")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        queueManager.detenerEnvio()
                        dismiss()
                    }
                    .disabled(queueManager.isSending && !queueManager.isPaused)
                }
            }
            // Sincronizar selectores anidados
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
    }
    
    private func iniciarEnvio() {
        queueManager.iniciarEnvio(
            destinatarios: destinatariosFiltrados,
            plantilla: plantilla,
            delaySeconds: delaySeconds
        )
    }
    
    private func reanudarEnvio() {
        // Enviar destinatarios restantes
        let restantes = Array(destinatariosFiltrados.suffix(from: queueManager.currentIndex))
        queueManager.iniciarEnvio(
            destinatarios: restantes,
            plantilla: plantilla,
            delaySeconds: delaySeconds
        )
    }
    
    private func colorForLog(_ log: String) -> Color {
        if log.contains("✅") {
            return .green
        } else if log.contains("❌") || log.contains("Error") {
            return .red
        } else if log.contains("⚠️") {
            return .orange
        } else if log.contains("⏱️") || log.contains("Iniciando") {
            return .blue
        }
        return .primary
    }
}
