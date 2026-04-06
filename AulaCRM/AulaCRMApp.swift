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
        
        // Importar Productos si no hay
        let requestProd: NSFetchRequest<Producto> = NSFetchRequest<Producto>(entityName: "Producto")
        let countProd = (try? ctx.count(for: requestProd)) ?? 0

        if countProd == 0 {
             CSVImporter.importarProductos(desde: "producto", contexto: ctx)
        }
        
        // Limpieza extra al arrancar para asegurar integridad
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

// MARK: - Helper para habilitar el swipe para atrás (iOS)
#if os(iOS)
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
#endif
