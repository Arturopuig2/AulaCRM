//
//  AulaCRMApp.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import CoreData

@main
struct AulaCRMApp: App {
    let persistenceController = PersistenceController.shared

    //IMPORTAR DATOS DE UN CSV
    init() {
        
        let ctx = persistenceController.container.viewContext
                
        if !UserDefaults.standard.bool(forKey: "didImportCSV") {
            CSVImporter.importarContactos(desde: "contacto", contexto: ctx)
            UserDefaults.standard.set(true, forKey: "didImportCSV")
        }
        
        eliminarDuplicadosPorCIF(ctx: ctx)
        
        
        if !UserDefaults.standard.bool(forKey: "didImportProducto") {
            CSVImporter.importarProductos(desde: "producto", contexto: ctx)
            UserDefaults.standard.set(true, forKey: "didImportProducto")
        }
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowToolbarStyle(.unified)
    }
}
