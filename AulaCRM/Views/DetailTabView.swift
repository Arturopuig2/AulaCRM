//
//  DetailTabView.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import MapKit
import CoreData
#if os(iOS)
import UIKit
#endif

struct DetailTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.openURL) private var openURL
    @ObservedObject var contacto: Contacto
    var contactosFiltrados: [Contacto] = []
    @Binding var showAllPins: Bool
    @Binding var selectedContact: Contacto?
    @State private var latText = ""
    @State private var lngText = ""
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.4699, longitude: -0.3763),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
    )
    
    enum Field: Hashable {
        case nombre
    }
    @FocusState private var focusedField: Field?
    @State private var showDeleteAlert = false



    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            //Spacer().frame(height: 10)
            #if os(macOS)
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 10) {
                // Fila 1: Nombre | [Código, CIF]
                GridRow {
                    Text("Nombre")
                    TextField("Nombre", text: Binding(get: { contacto.nombre ?? "" }, set: { contacto.nombre = $0 }))
                        .focused($focusedField, equals: .nombre)
                        .textFieldStyle(.roundedBorder)
                        // Removed fixed minWidth to allow shrinking/expanding
                        .frame(width: 280) // Shortened field
                        .gridColumnAlignment(.leading)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Código")
                            TextField("Código", text: Binding(get: { contacto.codigoSafe }, set: { contacto.codigoSafe = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack(spacing: 4) {
                            Text("CIF")
                            TextField("cif", text: Binding(get: { contacto.cifSafe }, set: { contacto.cifSafe = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                }

                // Fila 2: Dirección | [Provincia, Ciudad, CP]
                GridRow {
                    Text("Dirección")
                    TextField("Dirección", text: Binding(get: { contacto.direccion ?? "" }, set: { contacto.direccion = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280) // Shortened field
                        .gridColumnAlignment(.leading)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Provincia")
                            TextField("Provincia", text: Binding(get: { contacto.provincia ?? "" }, set: { contacto.provincia = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack(spacing: 4) {
                            Text("Ciudad")
                            TextField("Ciudad", text: Binding(get: { contacto.ciudad ?? "" }, set: { contacto.ciudad = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        HStack(spacing: 4) {
                            Text("CP")
                            TextField("CP", text: Binding(get: { contacto.cp ?? "" }, set: { contacto.cp = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                }

                // Fila 3: Teléfono | [Email + Button]
                GridRow {
                    Text("Teléfono")
                    TextField("Teléfono", text: Binding(get: { contacto.telefono ?? "" }, set: { contacto.telefono = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200) // Phone doesn't need full width but can behave like one
                        .gridColumnAlignment(.leading)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Correo")
                            TextField("Email", text: Binding(get: { contacto.email ?? "" }, set: { contacto.email = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                        }
                        
                        if let email = contacto.email, !email.isEmpty {
                            Button {
                                if let url = URL(string: "mailto:\(email)?subject=Consulta%20AulaCRM") {
                                    openURL(url)
                                }
                            } label: {
                                Image(systemName: "envelope")
                                    .help("Enviar correo")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                // Fila 4: Lat/Lng (Solo) o en Fila 3? Mejor fila propia para no saturar Fila 3.
                // Usaremos Fila 4 para "Ubicación" y Fila 5 para Notas.
                GridRow {
                    Text("Coords")
                    HStack(spacing: 8) {
                        Text("Lat")
                        TextField("Lat", text: $latText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: latText) { _, newValue in
                                if let d = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    contacto.latSafe = d
                                    if !contacto.isDeleted { try? ctx.save() }
                                }
                            }
                        Text("Lng")
                        TextField("Lng", text: $lngText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: lngText) { _, newValue in
                                if let d = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    contacto.lngSafe = d
                                    if !contacto.isDeleted { try? ctx.save() }
                                }
                            }
                    }
                    .gridColumnAlignment(.leading)
                    
                    // Extra Column Space used for Client Toggle or Filter?
                    HStack(spacing: 20) {
                        Toggle("Cliente", isOn: Binding(get: { contacto.esCliente }, set: { contacto.esCliente = $0 }))
                        
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Eliminar")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            do {
                                try ctx.save()
                                #if os(macOS)
                                NSHapticFeedbackManager.defaultPerformer.perform(
                                    .generic,
                                    performanceTime: NSHapticFeedbackManager.PerformanceTime.default
                                )
                                #endif
                                print("✅ Contacto guardado")
                            } catch {
                                print("❌ Error al guardar: \(error.localizedDescription)")
                            }
                        } label: {
                            Text("Guardar")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        // Alert attached to the HStack or Button
                        .alert("¿Eliminar este contacto?", isPresented: $showDeleteAlert) {
                            Button("Eliminar", role: .destructive) {
                                ctx.delete(contacto)
                                try? ctx.save()
                                selectedContact = nil
                            }
                            Button("Cancelar", role: .cancel) { }
                        } message: {
                            Text("Esta acción no se puede deshacer.")
                        }
                    }
                }

                // Fila 5: Notas (Spans main cols)
                GridRow {
                    Text("Notas")
                        .alignmentGuide(.firstTextBaseline) { d in d[.top] + 5 } // Align with top of textfield
                    TextField("Notas", text: Binding(get: { contacto.notas ?? "" }, set: { contacto.notas = $0 }), axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)
                        .gridCellColumns(2) // Span Main Input + Secondary
                }
                
                // Fila 6: Filtrados Toggle
                GridRow {
                    Text("")
                    Toggle("Mostrar filtrados en mapa", isOn: $showAllPins)
                        .font(.caption)
                        .gridCellColumns(2)
                }
                
            }
            // Mapa
            MapTabView(contactos: showAllPins ? contactosFiltrados : [contacto], selectedContact: $selectedContact)
                //.frame(minHeight: 400)
                .frame(height: 600)
                .padding(.top, 0)
            #else
            Form {
                Section("Datos Principales") {
                    TextField("Nombre", text: Binding(get: { contacto.nombre ?? "" }, set: { contacto.nombre = $0 }))
                        .focused($focusedField, equals: .nombre)
                    
                    Toggle("Es Cliente", isOn: Binding(get: { contacto.esCliente }, set: { contacto.esCliente = $0 }))
                    
                    HStack {
                        TextField("Código", text: Binding(get: { contacto.codigoSafe }, set: { contacto.codigoSafe = $0 }))
                        Divider()
                        TextField("CIF", text: Binding(get: { contacto.cifSafe }, set: { contacto.cifSafe = $0 }))
                    }
                }
                
                Section("Ubicación") {
                    TextField("Dirección", text: Binding(get: { contacto.direccion ?? "" }, set: { contacto.direccion = $0 }))
                    
                    HStack {
                        TextField("Ciudad", text: Binding(get: { contacto.ciudad ?? "" }, set: { contacto.ciudad = $0 }))
                        Divider()
                        TextField("Provincia", text: Binding(get: { contacto.provincia ?? "" }, set: { contacto.provincia = $0 }))
                    }
                    
                    HStack {
                        TextField("Código Postal", text: Binding(get: { contacto.cp ?? "" }, set: { contacto.cp = $0 }))
                            .keyboardType(.numberPad)
                        
                        Spacer()
                        
                        Button {
                            // Construir query de dirección
                            let addressParts = [contacto.direccion, contacto.cp, contacto.ciudad, contacto.provincia]
                            let query = addressParts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                            
                            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
                            
                            // Intentar app nativa primero, luego web genérica
                            let mapsURL = URL(string: "comgooglemaps://?q=\(encodedQuery)")!
                            let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)")!
                            
                            if UIApplication.shared.canOpenURL(mapsURL) {
                                UIApplication.shared.open(mapsURL)
                            } else {
                                UIApplication.shared.open(webURL)
                            }
                        } label: {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                Section("Contacto") {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundStyle(.secondary)
                        TextField("Teléfono", text: Binding(get: { contacto.telefono ?? "" }, set: { contacto.telefono = $0 }))
                            .keyboardType(.phonePad)
                    }
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                        TextField("Email", text: Binding(get: { contacto.email ?? "" }, set: { contacto.email = $0 }))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        
                        if let email = contacto.email, !email.isEmpty {
                            Spacer()
                            Button {
                                if let url = URL(string: "mailto:\(email)?subject=Consulta%20AulaCRM") {
                                    openURL(url)
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                Section("Notas") {
                    TextField("Añadir notas...", text: Binding(get: { contacto.notas ?? "" }, set: { contacto.notas = $0 }), axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section {
                    Button {
                        try? ctx.save()
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    } label: {
                        Text("Guardar Cambios")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear) 
                }
            }
            .formStyle(.grouped)
            #endif

        }
        
        .onAppear {
            latText = String(contacto.latSafe)
            lngText = String(contacto.lngSafe)
            
            // 🛑 Forzar que NO se ponga el foco en Nombre automáticamente
            DispatchQueue.main.async {
                self.focusedField = nil
            }
        }
        .onChange(of: contacto.objectID) { _, _ in
            latText = String(contacto.latSafe)
            lngText = String(contacto.lngSafe)
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(UIDevice.current.userInterfaceIdiom == .phone)
        #endif
    }
}
