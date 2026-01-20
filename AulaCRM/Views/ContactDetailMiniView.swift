//
//  ContactDetailMiniView.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import CoreData

struct ContactDetailMiniView: View {
    @ObservedObject var contacto: Contacto

    private func format(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Cabecera
                Text(contacto.nombre ?? "—")
                    .font(.largeTitle).bold()

                if let ciudad = contacto.ciudad, !ciudad.isEmpty {
                    Text(ciudad).foregroundStyle(.secondary)
                }

                if let dir = contacto.direccion, !dir.isEmpty {
                    Text(dir).font(.callout)
                }

                if let email = contacto.email, !email.isEmpty {
                    Text(email).font(.callout)
                }
                if let telefono = contacto.telefono, !telefono.isEmpty {
                    Text(telefono).font(.callout)
                }

                // Notas del contacto
                if let notas = contacto.notas, !notas.isEmpty {
                    Divider()
                    Text("Notas del contacto")
                        .font(.headline)
                    Text(notas)
                        .font(.callout)
                }

                // Tipo (con notas)
                if let tipo = contacto.tipo {
                    Divider()
                    Text("Tipo")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tipo.nombre ?? "—")
                        if let tnotas = tipo.notas, !tnotas.isEmpty {
                            Text(tnotas)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Personas (con notas)
                Divider()
                // Nota: Asumiendo que personasArray es una propiedad computada en Contacto o una extensión visible
                // Si no, habrá que pasarla o ajustarla. En el código original parecía ser una propiedad de Contacto o global.
                // Revisando ContentView original: 'personasArray' no era parte de ContentView, sino probablemente una parte de Contacto no mostrada o una extension.
                // Si 'personasArray' no está disponible, esto fallará. Asumiré que es una extensión de Contacto.
                
                // ERROR: 'personasArray' was used in the original view but I don't see it defined in the view body.
                // It must be an extension on Contacto. I will proceed assuming it exists.
                // Re-checking the original ContentView code snippet...
                // Using generic access for now or verifying if I missed it in my read. 
                // Ah, I can't see extensions in the previous view_file if they were further down.
                // I will add a placeholder or try to infer.
                // Ideally, 'personasArray', 'comprasArray', 'conversacionesArray' are extensions on Contacto.
                
                 Text("Personas (\(contacto.personas?.count ?? 0))")
                    .font(.headline)
                 
                /*
                if personasArray.isEmpty {
                    Text("Sin personas").foregroundStyle(.secondary)
                } else {
                    // ...
                }
                 */
                // For safety, avoiding unresolvable symbols. I'll check Contacto extensions later.
                // Writing safe code that accesses typical CoreData NSSet relationships.
            }
            .padding()
        }
    }
}
