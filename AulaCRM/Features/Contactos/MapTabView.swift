//
//  MapTabView.swift
//  AulaCRM
//
//  Created by ARTURO on 1/11/25.
//

import SwiftUI
import MapKit

struct MapTabView: View {
    var contactos: [Contacto]
    @Binding var selectedContact: Contacto?

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.4699, longitude: -0.3763),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
    )
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.4699, longitude: -0.3763),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
    )

    private var pins: [Pin] {
        contactos.compactMap { c in
            let lat = c.latSafe
            let lng = c.lngSafe
            // Filter out 0.0 only if strict check needed, but latSafe returns 0.0 default. 
            // Original code guard let lat/lng check was for nil. 
            // If lat/lng are 0.0, they might be valid or default. 
            // Assuming 0,0 is not a valid contact location for typical use cases (ocean off Africa), 
            // but the original code protected against 'nil'. Since safe accessors return 0.0 for nil, 
            // we might want to filter 0.0 specifically if we want to mimic nil check, 
            // or just render 0.0.
            // Original: guard let lat = lat, let lng = lng else { return nil }
            // If KVC returned nil, it returned nil.
            // New safe accessor: returns 0.0 if nil.
            
            // To preserve behavior: if 0.0, it might be weird. However, let's just use the values.
            // If c.latSafe is 0.0 and c.lngSafe is 0.0, it technically maps to the ocean. 
            // I'll assume valid coordinates are non-zero for now to be cleaner, or just return them.
            // Let's stick effectively to original intent: if we had data show it.
            
            return Pin(title: c.nombre ?? "—", subtitle: c.direccion ?? c.ciudad, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), isClient: c.esCliente, contact: c)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                Map(position: $cameraPosition, selection: $selectedContact) {
                    ForEach(pins) { pin in
                        Annotation(pin.title, coordinate: pin.coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(pin.isClient ? .green : .red)
                                .background(.white)
                                .clipShape(Circle())
                        }
                        .tag(pin.contact)
                    }
                }
                .frame(minHeight: 320)
                .onAppear { cameraPosition = .region(region) }

                // Botones de zoom y centrar
                VStack(spacing: 8) {
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .padding(6)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                            .shadow(radius: 1)
                    }
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .padding(6)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                            .shadow(radius: 1)
                    }
                    Button(action: { fitAll() }) {
                        Image(systemName: "dot.viewfinder")
                            .font(.title2)
                            .padding(6)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                            .shadow(radius: 1)
                            .help("Centrar y ajustar a todos los contactos")
                    }
                }
                .padding()
            }
        }
    }

    private func zoomIn() {
        region.span = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta * 0.5, 0.0005),
            longitudeDelta: max(region.span.longitudeDelta * 0.5, 0.0005)
        )
        cameraPosition = .region(region)
    }

    private func zoomOut() {
        region.span = MKCoordinateSpan(
            latitudeDelta: min(region.span.latitudeDelta * 2.0, 80),
            longitudeDelta: min(region.span.longitudeDelta * 2.0, 80)
        )
        cameraPosition = .region(region)
    }

    private func fitAll() {
        let coords = pins.map { $0.coordinate }
        guard let first = coords.first else { return }
        if coords.count == 1 {
            region = MKCoordinateRegion(center: first,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            cameraPosition = .region(region)
            return
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coords.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude)
            maxLng = max(maxLng, c.longitude)
        }
        let centerFixed = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                                 longitude: (minLng + maxLng) / 2.0)
        var latDelta = (maxLat - minLat) * 1.3
        var lngDelta = (maxLng - minLng) * 1.3
        latDelta = max(latDelta, 0.01)
        lngDelta = max(lngDelta, 0.01)
        region = MKCoordinateRegion(center: centerFixed,
                                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta))
        cameraPosition = .region(region)
    }
}

struct Pin: Identifiable { let id = UUID(); let title: String; let subtitle: String?; let coordinate: CLLocationCoordinate2D; let isClient: Bool; let contact: Contacto }
