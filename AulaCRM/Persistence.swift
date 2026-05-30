//
//  Persistence.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let c = Contacto(context: viewContext)
        c.id = UUID()
        c.nombre = "Colegio Demo (Preview)"
        c.ciudad = "Valencia"
        c.notas = "Cliente de prueba para SwiftUI Preview."
        
        try? viewContext.save()
        
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "AulaCRM")
        
        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            
            // Forzar las opciones explícitas de CloudKit
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.itbook.AulaCRM.pro")
            description.cloudKitContainerOptions = cloudKitOptions
            
            // Habilitar notificaciones de cambios remotos (CloudKit -> UI)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Migración ligera automática: permite añadir entidades/atributos
            // sin perder datos cuando el modelo evoluciona.
            description.setOption(true as NSNumber,
                                  forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber,
                                  forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let url = storeDescription.url {
                 print("📂 Ruta de la Base de Datos SQLite: \(url.path)")
            }
            if let error = error as NSError? {
                print("⚠️ Error al cargar base de datos (posible conflicto de migración): \(error.localizedDescription)")
                if let url = storeDescription.url {
                    print("🧹 Eliminando base de datos corrupta/antigua en \(url.path)...")
                    let shmURL = url.appendingPathExtension("shm")
                    let walURL = url.appendingPathExtension("wal")
                    try? FileManager.default.removeItem(at: url)
                    try? FileManager.default.removeItem(at: shmURL)
                    try? FileManager.default.removeItem(at: walURL)
                    
                    // Reintentar cargar de cero
                    PersistenceController.shared.container.loadPersistentStores(completionHandler: { (_, retryError) in
                        if let retryError = retryError as NSError? {
                            fatalError("Unresolved error \(retryError), \(retryError.userInfo)")
                        }
                    })
                } else {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
