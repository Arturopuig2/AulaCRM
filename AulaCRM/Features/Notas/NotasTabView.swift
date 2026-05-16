import SwiftUI
import CoreData

struct NotasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    // Fetch Requests
    @FetchRequest(sortDescriptors: [SortDescriptor(\NotaLibre.fecha, order: .reverse)])
    private var notas: FetchedResults<NotaLibre>
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\TareaTODO.fecha, order: .forward)])
    private var tareas: FetchedResults<TareaTODO>
    
    // UI State
    @State private var seleccionNota: NotaLibre? = nil
    @State private var textoNuevaTarea: String = ""
    @State private var mostrarEditorNota = false
    
    var body: some View {
        HStack(spacing: 0) {
            // ── COLUMNA IZQUIERDA: TODOs ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Tareas TODO", systemImage: "checklist")
                        .font(.title3.bold())
                    Spacer()
                }
                
                // Entrada nueva tarea
                HStack {
                    TextField("Nueva tarea...", text: $textoNuevaTarea)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { añadirTarea() }
                    
                    Button(action: añadirTarea) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(textoNuevaTarea.isEmpty)
                }
                
                // Lista de tareas
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(tareas) { tarea in
                            HStack {
                                Button {
                                    toggleTarea(tarea)
                                } label: {
                                    Image(systemName: tarea.completada ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(tarea.completada ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Text(tarea.titulo ?? "—")
                                    .strikethrough(tarea.completada)
                                    .foregroundStyle(tarea.completada ? .secondary : .primary)
                                
                                Spacer()
                                
                                Button {
                                    ctx.delete(tarea)
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
                        }
                    }
                }
            }
            .padding(24)
            .frame(width: 350)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // ── COLUMNA DERECHA: NOTAS LIBRES ────────────────────────────────
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Notas Independientes", systemImage: "note.text")
                        .font(.title3.bold())
                    Spacer()
                    Button {
                        crearNuevaNota()
                    } label: {
                        Label("Nueva Nota", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                            ForEach(notas) { nota in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(nota.titulo ?? "Sin título")
                                        .font(.headline)
                                        .lineLimit(1)
                                    
                                    Text(nota.contenido ?? "Sin contenido")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                    
                                    Spacer()
                                    
                                    HStack {
                                        Text(nota.fecha?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Button {
                                            ctx.delete(nota)
                                            try? ctx.save()
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(.red.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                                .frame(height: 160)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
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
        }
        .sheet(isPresented: $mostrarEditorNota) {
            if let nota = seleccionNota {
                EditorNotaView(nota: nota)
            }
        }
    }
    
    // MARK: - Lógica
    private func añadirTarea() {
        let limpia = textoNuevaTarea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        
        let t = TareaTODO(context: ctx)
        t.id = UUID()
        t.titulo = limpia
        t.completada = false
        t.fecha = Date()
        
        try? ctx.save()
        textoNuevaTarea = ""
    }
    
    private func toggleTarea(_ tarea: TareaTODO) {
        tarea.completada.toggle()
        try? ctx.save()
    }
    
    private func crearNuevaNota() {
        let n = NotaLibre(context: ctx)
        n.id = UUID()
        n.titulo = "Nueva Nota"
        n.contenido = ""
        n.fecha = Date()
        
        seleccionNota = n
        mostrarEditorNota = true
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
