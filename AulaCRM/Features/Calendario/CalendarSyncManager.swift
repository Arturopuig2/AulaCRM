import Foundation
import EventKit
import Combine

class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()
    private let eventStore = EKEventStore()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized || status == .fullAccess)
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                return granted
            }
        } catch {
            print("Error solicitando acceso al calendario: \(error.localizedDescription)")
            return false
        }
    }
    
    func saveEvent(title: String, startDate: Date, endDate: Date, notes: String, existingEventID: String?) -> String? {
        if !isAuthorized {
            print("No hay permisos de calendario")
            return nil
        }
        
        let event: EKEvent
        if let eventID = existingEventID, let existing = eventStore.event(withIdentifier: eventID) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error guardando evento: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteEvent(eventID: String) {
        guard isAuthorized else { return }
        
        if let event = eventStore.event(withIdentifier: eventID) {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("Error borrando evento: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
}
