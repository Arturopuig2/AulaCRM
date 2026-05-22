import Foundation
import CoreData

extension Factura {
    @objc var sortNumero: String {
        return numero ?? ""
    }
    
    @objc var sortCliente: String {
        return clienteNombre ?? ""
    }
    
    @objc var sortFecha: Date {
        return fecha ?? Date.distantPast
    }
    
    @objc var sortFechaCobro: Date {
        return fechaCobro ?? Date.distantPast
    }
    
    @objc var sortTotal: Double {
        return total
    }
    
    @objc var sortProyecto: String {
        return (value(forKey: "emisor") as? String) ?? "Aula"
    }
}
