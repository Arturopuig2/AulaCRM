//
//  AjustesSMTPView.swift
//  AulaCRM
//
//  Created for SMTP settings form and connectivity tests.
//

import SwiftUI

struct AjustesSMTPView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var host = ""
    @State private var portText = "465"
    @State private var user = ""
    @State private var fromName = ""
    @State private var password = ""
    
    @State private var isTesting = false
    @State private var testResultMessage = ""
    @State private var testResultSuccess = false
    @State private var showTestResult = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Servidor de Correo Saliente (SMTP)"),
                    footer: Text("Nota: AulaCRM requiere conexión segura SSL/TLS implícita (puerto recomendado 465). El puerto 587 (STARTTLS) no está soportado actualmente.")
                ) {
                    TextField("Servidor SMTP (Host)", text: $host, prompt: Text("ej: smtp.editorialaula.es"))
                    
                    TextField("Puerto", text: $portText)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                    
                    TextField("Usuario / Correo Electrónico", text: $user, prompt: Text("ej: info@editorialaula.es"))
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    #endif
                    
                    TextField("Nombre del Remitente", text: $fromName, prompt: Text("ej: Aula Editorial"))
                    
                    SecureField("Contraseña del Correo", text: $password, prompt: Text("Contraseña de la cuenta"))
                }
                
                Section {
                    Button(action: probarConexion) {
                        HStack {
                            Text("Probar Conexión y Guardar")
                            if isTesting {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isTesting || host.isEmpty || user.isEmpty || password.isEmpty)
                    
                    if showTestResult {
                        Text(testResultMessage)
                            .foregroundColor(testResultSuccess ? .green : .red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Ajustes SMTP")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardarAjustes()
                        dismiss()
                    }
                    .disabled(host.isEmpty || user.isEmpty)
                }
            }
            .onAppear(perform: cargarAjustes)
            #if os(macOS)
            .padding()
            .frame(width: 450, height: 350)
            #endif
        }
    }
    
    private func cargarAjustes() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "smtp_host") ?? ""
        let port = defaults.integer(forKey: "smtp_port")
        portText = port == 0 ? "465" : String(port)
        user = defaults.string(forKey: "smtp_user") ?? ""
        fromName = defaults.string(forKey: "smtp_from_name") ?? ""
        password = KeychainHelper.load() ?? ""
    }
    
    private func guardarAjustes() {
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: "smtp_host")
        let port = Int(portText) ?? 465
        defaults.set(port, forKey: "smtp_port")
        defaults.set(user, forKey: "smtp_user")
        defaults.set(fromName, forKey: "smtp_from_name")
        
        KeychainHelper.save(password: password)
    }
    
    private func probarConexion() {
        isTesting = true
        showTestResult = false
        
        // Guardar ajustes temporales para la prueba
        guardarAjustes()
        
        Task {
            let port = Int(portText) ?? 465
            let client = SMTPClient(host: host, port: port, user: user, fromName: fromName)
            
            do {
                // Enviar correo de prueba a nosotros mismos
                try await client.sendEmail(
                    to: user,
                    subject: "AulaCRM - Prueba de Conexión SMTP",
                    htmlBody: """
                    <html>
                    <body style="font-family: Arial, sans-serif; color: #333;">
                        <h2 style="color: #4f46e5;">Prueba de Conexión Existosa</h2>
                        <p>Este correo confirma que la configuración SMTP en <strong>AulaCRM</strong> es correcta.</p>
                        <hr style="border: 0; border-top: 1px solid #eee;" />
                        <p style="font-size: 12px; color: #888;">Mensaje enviado automáticamente desde AulaCRM.</p>
                    </body>
                    </html>
                    """
                )
                
                testResultSuccess = true
                testResultMessage = "✅ ¡Conexión SMTP exitosa! Correo de prueba enviado a \(user)."
            } catch {
                testResultSuccess = false
                testResultMessage = "❌ Error de conexión: \(error.localizedDescription)"
            }
            
            isTesting = false
            showTestResult = true
        }
    }
}
