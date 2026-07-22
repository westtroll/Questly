//
//  CalendarService.swift
//  Questly
//
//  Добавление задач в Календарь Apple через EventKit.
//  Используем write-only доступ (iOS 17+): мы только СОЗДАЁМ события
//  и не читаем чужие — системный запрос разрешения мягче,
//  а пользователю спокойнее.
//

import Foundation
import EventKit

@MainActor
enum CalendarService {

    // EKEventStore дорогой в создании — держим один на всё приложение.
    private static let store = EKEventStore()

    /// Добавить событие в календарь по умолчанию.
    /// completion(true) — событие создано, completion(false) — нет доступа
    /// или ошибка сохранения.
    static func addEvent(title: String, startDate: Date, endDate: Date,
                         notes: String? = nil,
                         completion: @escaping (Bool) -> Void) {

        store.requestWriteOnlyAccessToEvents { granted, _ in
            // Колбэк EventKit приходит на произвольной очереди —
            // возвращаемся на главную перед работой с UI-логикой.
            DispatchQueue.main.async {
                guard granted else {
                    completion(false)
                    return
                }

                let event = EKEvent(eventStore: store)
                event.title = title
                event.startDate = startDate
                event.endDate = endDate
                event.notes = notes
                event.calendar = store.defaultCalendarForNewEvents

                do {
                    try store.save(event, span: .thisEvent)
                    completion(true)
                } catch {
                    completion(false)
                }
            }
        }
    }
}

