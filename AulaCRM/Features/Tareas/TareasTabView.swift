import SwiftUI
import CoreData

struct TareasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    // Fetch Requests
    @FetchRequest(sortDescriptors: [SortDescriptor(\TareaTODO.fecha, order: .forward)])
    private var tareas: FetchedResults<TareaTODO>
    
    // UI State
    @Binding var mostrarNuevoToDo: Bool
    @FocusState private var isTextFieldFocused: Bool
    @State private var textoNuevaTarea: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Tareas", systemImage: "checklist")
                    .font(.title3.bold())
                Spacer()
            }
            
            // Entrada nueva tarea
            HStack {
                TextField("Nueva tarea...", text: $textoNuevaTarea)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
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
        .frame(maxWidth: .infinity)
        .onChange(of: mostrarNuevoToDo) { _, newValue in
            if newValue {
                isTextFieldFocused = true
                mostrarNuevoToDo = false
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
}
