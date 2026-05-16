//
//  ContactEditorInline.swift
//  AulaCRM
//

import SwiftUI

// MARK: - Editor mínimo embebido para crear contactos (incluye 'notas')
struct ContactEditorInline: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (_ nombre: String, _ ciudad: String, _ direccion: String, _ email: String, _ telefono: String, _ notas: String) -> Void

    @State private var nombre = ""
    @State private var ciudad = ""
    @State private var direccion = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var notas = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nuevo contacto").font(.title2).bold()
            Form {
                TextField("Nombre*", text: $nombre)
                TextField("Ciudad", text: $ciudad)
                TextField("Dirección", text: $direccion)
                TextField("Email", text: $email)
                TextField("Teléfono", text: $telefono)

                TextField("Notas", text: $notas, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    onSave(nombre, ciudad, direccion, email, telefono, notas)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }
}
