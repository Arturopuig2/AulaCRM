//
//  AlmacenViewModel.swift
//  AulaCRM
//

import SwiftUI
import CoreData
import Combine

class AlmacenViewModel: ObservableObject {
    
    func borrarMovimiento(_ mov: MovimientoAlmacen, context: NSManagedObjectContext) {
        if let producto = mov.producto {
            let stockActual: Int = (producto.value(forKey: "stock") as? NSNumber)?.intValue ?? Int(producto.stock)
            let cantidad = Int(mov.cantidad)
            let nuevoStock: Int
            // Revertir: si era Entrada (sumamos), ahora restamos; si era Salida (restamos), ahora sumamos
            if mov.tipoMovimiento == "Entrada" {
                nuevoStock = stockActual - cantidad
            } else {
                nuevoStock = stockActual + cantidad
            }
            producto.setValue(Int16(max(0, nuevoStock)), forKey: "stock")
        }
        context.delete(mov)
        try? context.save()
    }
}
