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

    //IMPORTAR DATOS Y LIMPIAR AL ARRANCAR
    init() {
        // No hacemos nada aquí con Core Data:
        // el store de CloudKit carga de forma asíncrona y acceder al
        // viewContext antes de que termine causa EXC_BAD_ACCESS.
        // La importación/limpieza se dispara desde .onAppear en ContentView.
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
