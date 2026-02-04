//
//  AulaCRMApp.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

@main
struct AulaCRMApp: App {
    let persistenceController = PersistenceController.shared

    //IMPORTAR DATOS DE UN CSV
    init() {
        
        let ctx = persistenceController.container.viewContext
                
        // SOLUCIÓN DEDUPICACIÓN:
        // Solo importamos si la base de datos está VACÍA.
        // Esto evita que al instalar en un iPhone nuevo (que recibe datos por iCloud)
        // se lance la importación doble.
        let requestCon: NSFetchRequest<Contacto> = Contacto.fetchRequest()
        let count = (try? ctx.count(for: requestCon)) ?? 0
        
        if count == 0 {
            CSVImporter.importarContactos(desde: "contacto", contexto: ctx)
            // Marcamos flag por si acaso, aunque el count es más seguro
            UserDefaults.standard.set(true, forKey: "didImportCSV")
        }
        
        // Importar Productos si no hay
        let requestProd: NSFetchRequest<Producto> = NSFetchRequest<Producto>(entityName: "Producto")
        let countProd = (try? ctx.count(for: requestProd)) ?? 0

        if countProd == 0 {
             CSVImporter.importarProductos(desde: "producto", contexto: ctx)
        }
        
        // Limpieza extra al arrancar
        CSVImporter.eliminarDuplicadosReales(ctx: ctx)
        
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        #endif
    }
}
