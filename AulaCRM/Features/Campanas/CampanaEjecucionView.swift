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
    
    // Estados de filtros
    @State private var filtroCliente: FiltroCliente = .todos
    @State private var filtroProvincia = ""
    @State private var delaySeconds: Double = 45.0
    
    enum FiltroCliente: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case clientes = "Solo Clientes"
        case noClientes = "Solo No Clientes"
        
        var id: String { self.rawValue }
    }
    
    init(plantilla: PlantillaEmail, context: NSManagedObjectContext) {
        self.plantilla = plantilla
        _queueManager = StateObject(wrappedValue: CampanaQueueManager(viewContext: context))
    }
    
    // Destinatarios filtrados listos para recibir el correo
    private var destinatariosFiltrados: [Contacto] {
        todosLosContactos.filter { c in
            // Filtrar por estado de cliente
            switch filtroCliente {
            case .clientes:
                if !c.esCliente { return false }
            case .noClientes:
                if c.esCliente { return false }
            case .todos:
                break
            }
            
            // Filtrar por provincia
            if !filtroProvincia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let prov = (c.provincia ?? "").lowercased()
                if !prov.contains(filtroProvincia.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
                    return false
                }
            }
            
            // Obligatorio tener correo
            guard let email = c.email, !email.isEmpty else { return false }
            
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
                        // Selección de Destinatarios (Filtros)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filtrar Colegios")
                                .font(.subheadline)
                                .bold()
                            
                            Picker("Tipo de Contacto", selection: $filtroCliente) {
                                ForEach(FiltroCliente.allCases) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            TextField("Filtrar por Provincia", text: $filtroProvincia, prompt: Text("Ej: Valencia"))
                                .textFieldStyle(.roundedBorder)
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
                            Text("• Tipo: \(filtroCliente.rawValue)")
                                .font(.caption)
                            if !filtroProvincia.isEmpty {
                                Text("• Provincia: \(filtroProvincia)")
                                    .font(.caption)
                            }
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
