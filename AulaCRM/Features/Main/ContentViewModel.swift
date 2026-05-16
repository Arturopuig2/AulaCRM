//
//  ContentViewModel.swift
//  AulaCRM
//

import SwiftUI
import CoreData
import Combine

class ContentViewModel: ObservableObject {
    @Published var search = ""
    @Published var selectedProvincia = "València"
    @Published var selectedCiudad    = "VALÈNCIA"
    @Published var selectedCP        = "Todos"
    @Published var selectedRegimen   = "Todos"
    @Published var selectedCliente   = "Todos" // opciones: Todos / Sí / No
    
    @Published var showAllPins = false
    @Published var showFilters: Bool = false
    
    // Arrays for pickers
    func provinciasUnicas(from contactos: [Contacto]) -> [String] {
        ["Todos"] + Array(Set(contactos.compactMap { $0.provincia?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
    
    func ciudadesUnicas(from contactos: [Contacto]) -> [String] {
        let filteredByProv = contactos.filter { c in
            if selectedProvincia == "Todos" { return true }
            return ((c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                .caseInsensitiveCompare(selectedProvincia) == .orderedSame
        }
        let ciudades = filteredByProv
            .compactMap { $0.ciudad?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(ciudades)).sorted()
    }
    
    func cpsUnicos(from contactos: [Contacto]) -> [String] {
        let filtered = contactos.filter { c in
            let provOK: Bool = {
                if selectedProvincia == "Todos" { return true }
                return ((c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .caseInsensitiveCompare(selectedProvincia) == .orderedSame
            }()
            let cityOK: Bool = {
                if selectedCiudad == "Todos" { return true }
                return ((c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .caseInsensitiveCompare(selectedCiudad) == .orderedSame
            }()
            return provOK && cityOK
        }
        let cps = filtered
            .compactMap { $0.cp?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ["Todos"] + Array(Set(cps)).sorted()
    }
    
    func regimenesUnicos(from contactos: [Contacto]) -> [String] {
        ["Todos"] + Array(Set(contactos.compactMap { $0.regimen?.trimmingCharacters(in: .whitespacesAndNewlines)  }.filter { !$0.isEmpty })).sorted()
    }
    
    func filteredContacts(from contactos: [Contacto]) -> [Contacto] {
        let buscado = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return contactos.filter { c in
            if selectedProvincia != "Todos",
               (c.provincia ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedProvincia) != .orderedSame { return false }

            if selectedCiudad != "Todos",
               (c.ciudad ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedCiudad) != .orderedSame { return false }

            if selectedCP != "Todos",
               (c.cp ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedCP) != .orderedSame { return false }

            if selectedRegimen != "Todos",
               (c.regimen ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(selectedRegimen) != .orderedSame { return false }

            if selectedCliente != "Todos" {
                let isCliente: Bool = {
                    if let b = c.value(forKey: "cliente") as? Bool { return b }
                    if let n = c.value(forKey: "cliente") as? NSNumber { return n.boolValue }
                    if let s = c.value(forKey: "cliente") as? String {
                        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return v == "true" || v == "1" || v == "si" || v == "sí" || v == "yes" || v == "y"
                    }
                    return false
                }()
                if selectedCliente == "Sí" && !isCliente { return false }
                if selectedCliente == "No" && isCliente  { return false }
            }

            if buscado.isEmpty { return true }
            return (c.nombre ?? "").localizedCaseInsensitiveContains(buscado)
                || (c.ciudad ?? "").localizedCaseInsensitiveContains(buscado)
                || (c.direccion ?? "").localizedCaseInsensitiveContains(buscado)
        }
    }

    func borrar(offsets: IndexSet, in filteredContacts: [Contacto], context: NSManagedObjectContext) {
        offsets.map { filteredContacts[$0] }.forEach(context.delete)
        try? context.save()
    }

    func crearContactoVacio(context: NSManagedObjectContext) -> NSManagedObjectID {
        let c = Contacto(context: context)
        c.id = UUID()
        c.nombre = "Nuevo contacto"
        try? context.save()
        return c.objectID
    }
}
