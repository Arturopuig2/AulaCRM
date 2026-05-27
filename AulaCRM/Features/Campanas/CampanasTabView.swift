import SwiftUI
import CoreData

struct CampanasTabView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    // Obtener todas las plantillas ordenadas por fecha de creación
    @FetchRequest(sortDescriptors: [SortDescriptor(\PlantillaEmail.fechaCreacion, order: .reverse)])
    private var plantillas: FetchedResults<PlantillaEmail>
    
    @State private var seleccionID: NSManagedObjectID? = nil
    @State private var mostrarAjustesSMTP = false
    @State private var mostrarEjecucionCampana = false
    
    // Variables para el editor cuando no hay selección o para control temporal
    @State private var titulo = ""
    @State private var asunto = ""
    @State private var cuerpoHTML = ""
    
    // Template seleccionado actualmente
    private var plantillaSeleccionada: PlantillaEmail? {
        if let id = seleccionID {
            return plantillas.first(where: { $0.objectID == id })
        }
        return nil
    }
    
    var body: some View {
        HSplitView {
            // Columna 1: Listado de Plantillas (Izquierda)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Plantillas", systemImage: "envelope.and.paper")
                        .font(.headline)
                    Spacer()
                    Button(action: { mostrarAjustesSMTP = true }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .help("Configuración SMTP")
                    
                    Button(action: { mostrarEjecucionCampana = true }) {
                        Image(systemName: "paperplane")
                    }
                    .buttonStyle(.plain)
                    .disabled(plantillaSeleccionada == nil)
                    .help("Enviar Campaña Automática")
                    
                    Button(action: crearNuevaPlantilla) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("Crear nueva plantilla")
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                List(selection: $seleccionID) {
                    ForEach(plantillas) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.titulo ?? "Sin título")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(p.asunto ?? "Sin asunto")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            
                            if let fecha = p.fechaCreacion {
                                Text(fecha.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(p.objectID)
                        .contextMenu {
                            Button("Eliminar Plantilla", role: .destructive) {
                                eliminarPlantilla(p)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Botonera inferior de lista
                HStack {
                    Button(action: {
                        if let selected = plantillaSeleccionada {
                            eliminarPlantilla(selected)
                        }
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .disabled(plantillaSeleccionada == nil)
                    .help("Eliminar plantilla seleccionada")
                    
                    Spacer()
                }
                .padding(8)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 350)
            
            // Columna 2: Editor y Vista Previa (Centro y Derecha)
            if let plantilla = plantillaSeleccionada {
                HSplitView {
                    // Editor (Centro)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Diseñar Correo")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Título de la Plantilla (interno)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Ej: Campaña Primavera Matemáticas", text: Binding(
                                get: { plantilla.titulo ?? "" },
                                set: { newValue in
                                    plantilla.titulo = newValue
                                    try? ctx.save()
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Asunto del Correo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Ej: Licencias gratuitas para {{nombre}}", text: Binding(
                                get: { plantilla.asunto ?? "" },
                                set: { newValue in
                                    plantilla.asunto = newValue
                                    try? ctx.save()
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Código HTML del Correo (Estilo Mailchimp)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Soporta: {{nombre}}, {{provincia}}, {{ciudad}}, {{direccion}}, {{telefono}}, {{cif}}")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                            }
                            
                            TextEditor(text: Binding(
                                get: { plantilla.cuerpoHTML ?? "" },
                                set: { newValue in
                                    plantilla.cuerpoHTML = newValue
                                    try? ctx.save()
                                }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                            .border(Color.secondary.opacity(0.2), width: 1)
                        }
                    }
                    .padding()
                    .frame(minWidth: 350, idealWidth: 450)
                    
                    // Vista Previa (Derecha)
                    VStack(spacing: 0) {
                        // Cabecera simulada de cliente de correo
                        let previewResult = procesarPlantillaParaPreview(
                            html: plantilla.cuerpoHTML ?? "",
                            asunto: plantilla.asunto ?? ""
                        )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("De:")
                                    .bold()
                                    .foregroundStyle(.secondary)
                                Text("AulaCRM <info@editorialaula.es>")
                                Spacer()
                                Image(systemName: "macwindow")
                                    .foregroundStyle(.tertiary)
                            }
                            Divider()
                            HStack {
                                Text("Para:")
                                    .bold()
                                    .foregroundStyle(.secondary)
                                Text("Colegio San José <contacto@sanjose.edu>")
                            }
                            Divider()
                            HStack {
                                Text("Asunto:")
                                    .bold()
                                    .foregroundStyle(.secondary)
                                Text(previewResult.1)
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.system(size: 12))
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        
                        Divider()
                        
                        HTMLPreviewView(htmlContent: previewResult.0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                    }
                    .frame(minWidth: 350, idealWidth: 450)
                }
            } else {
                // Estado vacío
                VStack(spacing: 12) {
                    Image(systemName: "envelope.and.paper.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("Selecciona una plantilla o crea una nueva")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Button("Crear Nueva Plantilla") {
                        crearNuevaPlantilla()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Seleccionar automáticamente la primera plantilla si existe
            if seleccionID == nil, let primer = plantillas.first {
                seleccionID = primer.objectID
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CrearNuevaPlantillaEmail"))) { _ in
            crearNuevaPlantilla()
        }
        .sheet(isPresented: $mostrarAjustesSMTP) {
            AjustesSMTPView()
        }
        .sheet(isPresented: $mostrarEjecucionCampana) {
            if let plantilla = plantillaSeleccionada {
                CampanaEjecucionView(plantilla: plantilla, context: ctx)
            }
        }
    }
    
    // MARK: - Helper de Previsualización
    private func procesarPlantillaParaPreview(html: String, asunto: String) -> (String, String) {
        let mockValues = [
            "{{nombre}}": "Colegio San José",
            "{{ciudad}}": "Valencia",
            "{{provincia}}": "Valencia",
            "{{direccion}}": "Calle Mayor, 15",
            "{{cif}}": "B99887766",
            "{{telefono}}": "961234567",
            "{{notas}}": "Centro educativo interesado en licencias digitales de matemáticas."
        ]
        
        var processedHtml = html
        var processedAsunto = asunto
        
        for (placeholder, val) in mockValues {
            processedHtml = processedHtml.replacingOccurrences(of: placeholder, with: val)
            processedAsunto = processedAsunto.replacingOccurrences(of: placeholder, with: val)
        }
        
        if html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            processedHtml = """
            <!DOCTYPE html>
            <html>
            <body style="font-family: Arial, sans-serif; color: #4a5568; padding: 30px; text-align: center; background-color: #f7fafc;">
                <div style="max-width: 400px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; border: 1px solid #edf2f7; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
                    <h3 style="color: #2b6cb0; margin-top: 0;">Diseña tu campaña</h3>
                    <p style="font-size: 14px;">Escribe el código HTML en la columna del editor y verás el resultado en tiempo real aquí.</p>
                </div>
            </body>
            </html>
            """
        }
        
        return (processedHtml, processedAsunto)
    }
    
    // MARK: - Acciones Core Data
    private func crearNuevaPlantilla() {
        let p = PlantillaEmail(context: ctx)
        p.id = UUID()
        p.titulo = "Plantilla Nueva"
        p.asunto = "Asunto del correo para {{nombre}}"
        p.fechaCreacion = Date()
        
        // Cargar plantilla HTML promocional inicial por defecto
        p.cuerpoHTML = """
        <!DOCTYPE html>
        <html lang="es">
        <body style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f7fafc;">
            <table align="center" width="100%" cellpadding="0" cellspacing="0" style="max-width: 600px; background-color: #ffffff; border: 1px solid #edf2f7; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
                <tr>
                    <td style="background: linear-gradient(135deg, #2b6cb0 0%, #2c5282 100%); padding: 30px; text-align: center; color: #ffffff;">
                        <h1 style="margin: 0; font-size: 26px;">Propuesta Especial Aula</h1>
                        <p style="margin: 5px 0 0 0; opacity: 0.9;">Solución educativa para {{ciudad}}</p>
                    </td>
                </tr>
                <tr>
                    <td style="padding: 30px; color: #4a5568; line-height: 1.6; font-size: 15px;">
                        <h2>Estimados docentes del {{nombre}},</h2>
                        <p>Nos agrada presentarles nuestra herramienta gamificada de aprendizaje. Hemos verificado que los colegios en la zona de <strong>{{provincia}}</strong> están aumentando el interés de los alumnos por el aprendizaje autónomo.</p>
                        <p>Nuestro programa ofrece:</p>
                        <ul>
                            <li>Adaptación dinámica al nivel del alumno.</li>
                            <li>Ejercicios y juegos pedagógicos interactivos.</li>
                            <li>Monitoreo y analíticas avanzadas para el profesorado.</li>
                        </ul>
                        <div style="text-align: center; margin: 35px 0;">
                            <a href="https://tuweb.com/demo" style="background-color: #e53e3e; color: #ffffff; padding: 12px 28px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block; box-shadow: 0 4px 6px rgba(229,62,62,0.2);">Solicitar Prueba Curricular</a>
                        </div>
                        <p>Atentamente,<br>El equipo de Aula</p>
                    </td>
                </tr>
            </table>
        </body>
        </html>
        """
        
        try? ctx.save()
        seleccionID = p.objectID
    }
    
    private func eliminarPlantilla(_ p: PlantillaEmail) {
        ctx.delete(p)
        try? ctx.save()
        
        if seleccionID == p.objectID {
            seleccionID = plantillas.first?.objectID
        }
    }
}
