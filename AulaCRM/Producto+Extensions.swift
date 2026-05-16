import Foundation
import CoreData

extension Producto {
    @objc var sortNombre: String { 
        return nombre ?? "" 
    }
    
    @objc var sortISBN: String { 
        return isbn ?? "" 
    }
    
    @objc var sortDeposito: String { 
        return depositolegal ?? "" 
    }
    
    @objc var sortStock: Int { 
        return Int(stock) 
    }
}
