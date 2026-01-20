//
//  Contacto+Extensions.swift
//  AulaCRM
//
//  Created for safe Core Data access refactoring.
//

import Foundation
import CoreData

extension Contacto {

    // MARK: - Safe Accessors
    
    /// Acceso seguro a 'codigo'
    var codigoSafe: String {
        get {
            return (self.value(forKey: "codigo") as? String) ?? ""
        }
        set {
            self.setValue(newValue, forKey: "codigo")
        }
    }
    
    /// Acceso seguro a 'cif'
    var cifSafe: String {
        get {
            return (self.value(forKey: "cif") as? String) ?? ""
        }
        set {
            self.setValue(newValue, forKey: "cif")
        }
    }
    
    /// Acceso seguro a 'lat'
    var latSafe: Double {
        get {
            return (self.value(forKey: "lat") as? NSNumber)?.doubleValue ?? 0.0
        }
        set {
            self.setValue(newValue, forKey: "lat")
        }
    }
    
    /// Acceso seguro a 'lng'
    var lngSafe: Double {
        get {
            return (self.value(forKey: "lng") as? NSNumber)?.doubleValue ?? 0.0
        }
        set {
            self.setValue(newValue, forKey: "lng")
        }
    }
    
    // MARK: - Logic Helpers
    
    /// Lógica consolidada para determinar si es cliente (soporta Bool, NSNumber, String)
    var esCliente: Bool {
        get {
            if let b = self.value(forKey: "cliente") as? Bool { return b }
            if let n = self.value(forKey: "cliente") as? NSNumber { return n.boolValue }
            if let s = self.value(forKey: "cliente") as? String {
                let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return v == "true" || v == "1" || v == "si" || v == "sí" || v == "y" || v == "yes"
            }
            return false
        }
        set {
            self.setValue(newValue, forKey: "cliente")
        }
    }
}
