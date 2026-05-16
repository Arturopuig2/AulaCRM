import SwiftUI
import CoreData

struct NotasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    // Fetch Requests
    @FetchRequest(sortDescriptors: [SortDescriptor(\NotaLibre.fecha, order: .reverse)])
    private var notas: FetchedResults<NotaLibre>
    
    // UI State
    @State private var seleccionNota: NotaLibre? = nil
    @State private var textoNuevaNota: String = ""
    @State private var mostrarEditorNota = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Notas", systemImage: "note.text")
                    .font(.title3.bold())
                Spacer()
            }
            
            // Entrada nueva nota
            HStack {
                TextField("Nueva nota...", text: $textoNuevaNota)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { añadirNotaList() }
                
                Button(action: añadirNotaList) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(textoNuevaNota.isEmpty)
            }
            
            if notas.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("No tienes notas guardadas")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Lista de notas
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(notas) { nota in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                
                                Text(nota.titulo ?? "Sin título")
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Button {
                                    ctx.delete(nota)
                                    try? ctx.save()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                seleccionNota = nota
                                mostrarEditorNota = true
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $mostrarEditorNota) {
            if let nota = seleccionNota {
                EditorNotaView(nota: nota)
            }
        }
    }
    
    // MARK: - Lógica
    private func crearNuevaNota() {
        let n = NotaLibre(context: ctx)
        n.id = UUID()
        n.titulo = "Nueva Nota"
        n.contenido = ""
        n.fecha = Date()
        
        seleccionNota = n
        mostrarEditorNota = true
    }
    
    private func añadirNotaList() {
        let limpia = textoNuevaNota.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        
        let n = NotaLibre(context: ctx)
        n.id = UUID()
        n.titulo = limpia
        n.contenido = ""
        n.fecha = Date()
        
        try? ctx.save()
        textoNuevaNota = ""
    }
}

// MARK: - Editor de Nota
struct EditorNotaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var nota: NotaLibre
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Título de la nota", text: Binding(
                    get: { nota.titulo ?? "" },
                    set: { nota.titulo = $0 }
                ))
                .font(.title2.bold())
                .textFieldStyle(.plain)
                
                Spacer()
                
                Button("Cerrar") {
                    try? ctx.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            TextEditor(text: Binding(
                get: { nota.contenido ?? "" },
                set: { nota.contenido = $0 }
            ))
            .font(.body)
            .padding(24)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}
