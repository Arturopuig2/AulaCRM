import Foundation
import CoreData
import SwiftUI

struct ContactoBackup: Codable {
    let id: String?
    let nombre: String?
    let direccion: String?
    let telefono: String?
    let email: String?
    let ciudad: String?
    let provincia: String?
    let cp: String?
    let codigo: String?
    let cif: String?
    let cliente: Bool?
    let notas: String?
    let regimen: String?
    let lat: Double?
    let lng: Double?
}

struct BackupManager {
    static func generarBackupJSON(context: NSManagedObjectContext) -> URL? {
        let fetchRequest: NSFetchRequest<Contacto> = Contacto.fetchRequest()
        
        do {
            let contactos = try context.fetch(fetchRequest)
            let backupData = contactos.map { c in
                ContactoBackup(
                    id: c.id?.uuidString,
                    nombre: c.nombre,
                    direccion: c.direccion,
                    telefono: c.telefono,
                    email: c.email,
                    ciudad: c.ciudad,
                    provincia: c.provincia,
                    cp: c.cp,
                    codigo: c.codigo,
                    cif: c.cif,
                    cliente: c.cliente,
                    notas: c.notas,
                    regimen: c.regimen,
                    lat: c.lat,
                    lng: c.lng
                )
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(backupData)
            
            // Guardar en archivo temporal
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Backup_AulaCRM_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            print("📦 Backup generado en: \(fileURL)")
            return fileURL
            
        } catch {
            print("❌ Error generando backup: \(error)")
            return nil
        }
    }
}
