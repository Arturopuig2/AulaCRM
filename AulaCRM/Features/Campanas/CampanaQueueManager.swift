//
//  CampanaQueueManager.swift
//  AulaCRM
//
//  Created for managing background SMTP queue execution.
//

import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class CampanaQueueManager: ObservableObject {
    @Published var isSending = false
    @Published var isPaused = false
    @Published var currentIndex = 0
    @Published var logs: [String] = []
    
    private var task: Task<Void, Never>? = nil
    private var viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    /// Agrega una línea formateada a los logs visibles
    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: Date())
        logs.insert("[\(time)] \(message)", at: 0)
    }
    
    /// Inicia o reanuda la campaña
    func iniciarEnvio(
        destinatarios: [Contacto],
        plantilla: PlantillaEmail,
        delaySeconds: Double
    ) {
        guard !destinatarios.isEmpty else {
            log("Error: Lista de destinatarios vacía.")
            return
        }
        
        // Cargar ajustes SMTP desde UserDefaults
        let defaults = UserDefaults.standard
        guard let host = defaults.string(forKey: "smtp_host"), !host.isEmpty,
              let user = defaults.string(forKey: "smtp_user"), !user.isEmpty else {
            log("Error: Ajustes SMTP incompletos. Configúralos primero.")
            return
        }
        
        let port = defaults.integer(forKey: "smtp_port") == 0 ? 465 : defaults.integer(forKey: "smtp_port")
        let fromName = defaults.string(forKey: "smtp_from_name") ?? "Aula"
        
        isSending = true
        isPaused = false
        
        log("Iniciando campaña con \(destinatarios.count) destinatarios...")
        
        task = Task {
            let client = SMTPClient(host: host, port: port, user: user, fromName: fromName)
            
            while currentIndex < destinatarios.count && isSending && !isPaused {
                let contacto = destinatarios[currentIndex]
                
                guard let email = contacto.email, !email.isEmpty else {
                    log("⚠️ \(contacto.nombre ?? "Sin nombre"): Correo vacío. Omitiendo.")
                    currentIndex += 1
                    continue
                }
                
                log("✉️ Enviando a \(contacto.nombre ?? "Colegio")...")
                
                // Renderizar plantilla para este contacto
                let asunto = plantilla.asunto ?? "Propuesta Aula"
                let cuerpoHTML = plantilla.cuerpoHTML ?? ""
                
                let mockValues = [
                    "{{nombre}}": contacto.nombre ?? "",
                    "{{ciudad}}": contacto.ciudad ?? "",
                    "{{provincia}}": contacto.provincia ?? "",
                    "{{direccion}}": contacto.direccion ?? "",
                    "{{cif}}": contacto.cifSafe,
                    "{{telefono}}": contacto.telefono ?? "",
                    "{{notas}}": contacto.notas ?? ""
                ]
                
                var processedHtml = cuerpoHTML
                var processedAsunto = asunto
                
                for (placeholder, val) in mockValues {
                    processedHtml = processedHtml.replacingOccurrences(of: placeholder, with: val)
                    processedAsunto = processedAsunto.replacingOccurrences(of: placeholder, with: val)
                }
                
                do {
                    // Envío real SMTP
                    try await client.sendEmail(to: email, subject: processedAsunto, htmlBody: processedHtml)
                    
                    log("✅ ¡Enviado con éxito a \(contacto.nombre ?? "Colegio")!")
                    
                    // Crear registro de conversación en el historial de Core Data
                    let conv = Conversacion(context: viewContext)
                    conv.id = UUID()
                    conv.fecha = Date()
                    conv.notas = "Email automático enviado: \"\(plantilla.titulo ?? "Sin título")\" con asunto \"\(processedAsunto)\"."
                    conv.contactos = contacto
                    
                    try? viewContext.save()
                    
                } catch {
                    log("❌ Error enviando a \(contacto.nombre ?? "Colegio"): \(error.localizedDescription)")
                }
                
                currentIndex += 1
                
                // Esperar retardo si no es el último correo
                if currentIndex < destinatarios.count && isSending && !isPaused {
                    log("⏱️ Esperando \(Int(delaySeconds)) segundos para el próximo envío...")
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    } catch {
                        // Task cancelled
                        break
                    }
                }
            }
            
            if currentIndex >= destinatarios.count {
                log("🎉 ¡Campaña finalizada! Todos los envíos procesados.")
                isSending = false
                currentIndex = 0
            } else if isPaused {
                log("⏸️ Campaña pausada por el usuario.")
            } else {
                log("⏹️ Campaña detenida.")
            }
        }
    }
    
    /// Pausa la campaña actual
    func pausarEnvio() {
        isPaused = true
        task?.cancel()
        task = nil
    }
    
    /// Detiene y limpia la campaña
    func detenerEnvio() {
        isSending = false
        isPaused = false
        task?.cancel()
        task = nil
        currentIndex = 0
        log("Campaña cancelada y cola reiniciada.")
    }
}
