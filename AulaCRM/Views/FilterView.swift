import SwiftUI

struct FilterView: View {
    @Binding var showFilters: Bool
    @Binding var selectedProvincia: String
    @Binding var selectedCiudad: String
    @Binding var selectedCP: String
    @Binding var selectedRegimen: String
    @Binding var selectedCliente: String
    
    let provinciasUnicas: [String]
    let ciudadesUnicas: [String]
    let cpsUnicos: [String]
    let regimenesUnicos: [String]
    
    var body: some View {
        DisclosureGroup("Filtros", isExpanded: $showFilters) {
            VStack(alignment: .leading, spacing: 12) {
                // Provincia
                filterRow(title: "Provincia", selection: $selectedProvincia, options: provinciasUnicas)
                
                // Ciudad
                filterRow(title: "Ciudad", selection: $selectedCiudad, options: ciudadesUnicas)
                
                // CP
                filterRow(title: "CP", selection: $selectedCP, options: cpsUnicos)
                
                // Régimen
                filterRow(title: "Régimen", selection: $selectedRegimen, options: regimenesUnicos)
                
                // Cliente (Manual options)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Cliente")
                    Picker("Cliente", selection: $selectedCliente) {
                        Text("Todos").tag("Todos")
                        Text("Sí").tag("Sí")
                        Text("No").tag("No")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    @ViewBuilder
    private func filterRow(title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
