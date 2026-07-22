//
//  WidgetSnapshot.swift
//  DayQuest
//
//  Снимок данных для виджета. Приложение записывает его в общий
//  UserDefaults (App Group) при каждом сохранении, виджет — читает.
//
//  ВАЖНО: этот файл должен входить в ОБА таргета!
//  Выдели файл в Xcode → правая панель (File Inspector) →
//  Target Membership → поставь галочки DayQuest И DayQuestWidgetExtension.
//

import Foundation

struct WidgetSnapshot: Codable {

    // Идентификатор App Group — должен совпадать с тем,
    // что добавлен в Signing & Capabilities обоих таргетов.
    static let appGroupID = "group.beta.study1.DayQuest"
    private static let key = "dq_widget_snapshot"

    // MARK: - Данные

    var score: Int              // 0–100
    var rawPoints: Int          // честная сумма, может быть > 100
    var statusLabel: String     // «Хороший день»
    var statusEmoji: String     // 😊
    var streak: Int
    var level: Int
    var pendingTasks: [PendingTask]

    /// Невыполненные цели года (до 4) — для виджета «Цели».
    /// Опционал: старые снапшоты без поля декодируются без ошибки.
    var yearGoals: [String]? = nil

    struct PendingTask: Codable {
        var name: String
        var points: Int
    }

    // MARK: - Чтение и запись через App Group

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    // MARK: - Заглушки

    /// Пустое состояние — до первой записи из приложения
    static let empty = WidgetSnapshot(
        score: 0, rawPoints: 0,
        statusLabel: "Начни день", statusEmoji: "🎯",
        streak: 0, level: 1, pendingTasks: [], yearGoals: []
    )

    /// Пример для галереи виджетов и превью
    static let placeholder = WidgetSnapshot(
        score: 65, rawPoints: 65,
        statusLabel: "Хороший день", statusEmoji: "😊",
        streak: 7, level: 3,
        pendingTasks: [
            PendingTask(name: "Вечерняя пробежка", points: 15),
            PendingTask(name: "Прочитать 20 страниц", points: 20)
        ],
        yearGoals: ["Пробежать полумарафон", "Прочитать 24 книги", "Выучить SwiftUI"]
    )
}

