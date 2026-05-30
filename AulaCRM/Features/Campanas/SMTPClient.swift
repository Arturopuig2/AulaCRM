//
//  SMTPClient.swift
//  AulaCRM
//
//  Created for native SMTP email dispatching.
//

import Foundation
import Network

class SMTPClient {
    let host: String
    let port: Int
    let user: String
    let fromName: String
    
    init(host: String, port: Int, user: String, fromName: String) {
        self.host = host
        self.port = port
        self.user = user
        self.fromName = fromName
    }
    
    /// Helper de tiempo de espera (Timeout) para operaciones asíncronas
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "SMTPClient",
                    code: -999,
                    userInfo: [NSLocalizedDescriptionKey: "Tiempo de espera agotado (timeout) al intentar conectar con el servidor SMTP. Verifica la configuración o tu conexión a Internet."]
                )
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    func sendEmail(to recipient: String, subject: String, htmlBody: String) async throws {
        // Envolver toda la secuencia SMTP en un tiempo límite de 15 segundos
        try await withTimeout(seconds: 15) {
            try await self.executeSendEmail(to: recipient, subject: subject, htmlBody: htmlBody)
        }
    }
    
    private func executeSendEmail(to recipient: String, subject: String, htmlBody: String) async throws {
        // Load password securely from Keychain
        guard let password = KeychainHelper.load() else {
            throw NSError(
                domain: "SMTPClient",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No se encontró la contraseña del correo en el Keychain. Configúrala en los Ajustes de AulaCRM."]
            )
        }
        
        let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) ?? 465
        let hostName = NWEndpoint.Host(host)
        
        // Configuración de TLS implícito para puerto 465
        let parameters = NWParameters.tls
        
        let connection = NWConnection(host: hostName, port: portNumber, using: parameters)
        
        defer {
            connection.cancel()
        }
        
        try await withTaskCancellationHandler {
            // Esperar a que la conexión esté lista
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var resolved = false
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if !resolved {
                            resolved = true
                            continuation.resume()
                        }
                    case .failed(let error):
                        if !resolved {
                            resolved = true
                            continuation.resume(throwing: error)
                        }
                    case .cancelled:
                        if !resolved {
                            resolved = true
                            continuation.resume(throwing: NSError(domain: "SMTPClient", code: -5, userInfo: [NSLocalizedDescriptionKey: "Conexión cancelada"]))
                        }
                    default:
                        break
                    }
                }
                
                if Task.isCancelled {
                    resolved = true
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                connection.start(queue: .global())
            }
            
            // Flujo SMTP
            // 1. Saludo del servidor (Esperamos código 220)
            var resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 220 else { throw smtpError(resp.message) }
            
            // 2. EHLO
            try await sendCommand(connection: connection, cmd: "EHLO \(host)")
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 250 else { throw smtpError(resp.message) }
            
            // 3. AUTH LOGIN
            try await sendCommand(connection: connection, cmd: "AUTH LOGIN")
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 334 else { throw smtpError(resp.message) }
            
            // 4. Enviar Usuario en Base64
            let userBase64 = user.data(using: .utf8)!.base64EncodedString()
            try await sendCommand(connection: connection, cmd: userBase64)
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 334 else { throw smtpError(resp.message) }
            
            // 5. Enviar Contraseña en Base64
            let passBase64 = password.data(using: .utf8)!.base64EncodedString()
            try await sendCommand(connection: connection, cmd: passBase64)
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 235 else { throw smtpError(resp.message) }
            
            // 6. MAIL FROM
            try await sendCommand(connection: connection, cmd: "MAIL FROM:<\(user)>")
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 250 else { throw smtpError(resp.message) }
            
            // 7. RCPT TO
            try await sendCommand(connection: connection, cmd: "RCPT TO:<\(recipient)>")
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 250 else { throw smtpError(resp.message) }
            
            // 8. DATA
            try await sendCommand(connection: connection, cmd: "DATA")
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 354 else { throw smtpError(resp.message) }
            
            // 9. Enviar Mensaje Completo (Cabeceras y Cuerpo HTML)
            let cleanSubject = subject.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
            
            var message = ""
            message += "From: \(fromName) <\(user)>\r\n"
            message += "To: <\(recipient)>\r\n"
            message += "Subject: \(cleanSubject)\r\n"
            message += "MIME-Version: 1.0\r\n"
            message += "Content-Type: text/html; charset=\"utf-8\"\r\n"
            message += "Content-Transfer-Encoding: 8bit\r\n"
            message += "\r\n"
            message += htmlBody
            message += "\r\n."
            
            try await sendCommand(connection: connection, cmd: message)
            resp = try await readSMTPResponse(connection: connection)
            guard resp.code == 250 else { throw smtpError(resp.message) }
            
            // 10. QUIT
            try await sendCommand(connection: connection, cmd: "QUIT")
            _ = try? await readSMTPResponse(connection: connection)
        } onCancel: {
            connection.cancel()
        }
    }
    
    private func sendCommand(connection: NWConnection, cmd: String) async throws {
        if Task.isCancelled {
            throw CancellationError()
        }
        let data = (cmd + "\r\n").data(using: .utf8)!
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }))
        }
    }
    
    private func readSMTPResponse(connection: NWConnection) async throws -> (code: Int, message: String) {
        if Task.isCancelled {
            throw CancellationError()
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(code: Int, message: String), Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, !data.isEmpty else {
                    continuation.resume(throwing: NSError(domain: "SMTPClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "No se recibieron datos del servidor SMTP"]))
                    return
                }
                guard let responseString = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: NSError(domain: "SMTPClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "No se pudo decodificar la respuesta SMTP en UTF8"]))
                    return
                }
                
                let lines = responseString.components(separatedBy: "\r\n").filter { !$0.isEmpty }
                guard let lastLine = lines.last else {
                    continuation.resume(throwing: NSError(domain: "SMTPClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Respuesta SMTP vacía"]))
                    return
                }
                
                // En SMTP el código de respuesta son los primeros 3 caracteres
                let codeStr = String(lastLine.prefix(3))
                guard let code = Int(codeStr) else {
                    continuation.resume(throwing: NSError(domain: "SMTPClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Código de estado SMTP inválido: \(codeStr)"]))
                    return
                }
                
                continuation.resume(returning: (code, lastLine))
            }
        }
    }
    
    private func smtpError(_ msg: String) -> Error {
        return NSError(domain: "SMTPClient", code: -100, userInfo: [NSLocalizedDescriptionKey: "Error SMTP: \(msg)"])
    }
}
