import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    var datesWithVisits: Set<DateComponents>
    
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Cabecera: Mes y Navegación
            HStack {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 15) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { currentMonth = Date() }) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 8)
            
            // Días de la semana
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Rejilla de días
            let days = generateDaysInMonth(for: currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            hasVisit: hasVisit(on: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .frame(width: 300)
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func generateDaysInMonth(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        
        let weekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7 // Ajuste para que empiece en Lunes
        var days: [Date?] = Array(repeating: nil, count: weekday)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func hasVisit(on date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return datesWithVisits.contains(components)
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasVisit: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
                )
            
            // Punto indicador de visita
            Circle()
                .fill(hasVisit ? Color.orange : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(height: 36)
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return .blue }
        return .primary
    }
}
