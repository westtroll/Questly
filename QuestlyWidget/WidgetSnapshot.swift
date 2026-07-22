//
//  WidgetSnapshot.swift
//  Questly
//
//  Снимок данных для виджета. Приложение записывает его в общий
//  UserDefaults (App Group) при каждом сохранении, виджет — читает.
//
//  Интерактив: тап по задаче на виджете выполняется в процессе
//  ВИДЖЕТА, где нет SwiftData-стора. Поэтому виджет (1) оптимистично
//  правит снапшот — галочка и баллы обновляются мгновенно — и
//  (2) кладёт команду в очередь. Приложение применяет очередь к
//  настоящим данным при следующем запуске/выходе на передний план,
//  и снапшот пересобирается уже из истинного состояния.
//
//  ВАЖНО: этот файл должен входить в ОБА таргета!
//  Выдели файл в Xcode → правая панель (File Inspector) →
//  Target Membership → поставь галочки Questly И QuestlyWidgetExtension.
//

import Foundation
import WidgetKit

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
        /// Идентификатор задачи в сторе приложения (закодированный
        /// persistentModelID). Опционал — для старых снапшотов.
        /// Виджет его не расшифровывает, а передаёт обратно как есть.
        var id: String? = nil
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

    // MARK: - Очередь команд «задача выполнена» (виджет → приложение)

    private static let pendingCompletionsKey = "dq_widget_pending_completions"

    /// Виджет: положить команду в очередь
    static func enqueueCompletion(taskID: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var queue = defaults.stringArray(forKey: pendingCompletionsKey) ?? []
        guard !queue.contains(taskID) else { return }
        queue.append(taskID)
        defaults.set(queue, forKey: pendingCompletionsKey)
    }

    /// Приложение: забрать команды и очистить очередь
    static func drainCompletions() -> [String] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }
        let queue = defaults.stringArray(forKey: pendingCompletionsKey) ?? []
        defaults.removeObject(forKey: pendingCompletionsKey)
        return queue
    }

    // MARK: - Оптимистичное выполнение задачи (вызывает интент виджета)

    /// Мгновенная реакция на тап: убрать задачу из списка, добавить
    /// баллы, пересчитать статус — и поставить команду приложению.
    static func completeTaskOptimistically(taskID: String) {
        guard !taskID.isEmpty else { return }
        var snapshot = load()
        guard let index = snapshot.pendingTasks.firstIndex(where: { $0.id == taskID })
        else { return }

        let task = snapshot.pendingTasks.remove(at: index)
        snapshot.rawPoints += task.points
        snapshot.score = min(100, snapshot.rawPoints)
        snapshot.statusLabel = Self.label(for: snapshot.score)
        snapshot.statusEmoji = Self.emoji(for: snapshot.score)
        snapshot.save()

        enqueueCompletion(taskID: taskID)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Статус по баллам. ДЕРЖАТЬ В СИНХРОНЕ с DayScore в Models.swift:
    // виджет не видит модели приложения, поэтому шкала продублирована.
    private static func label(for value: Int) -> String {
        switch value {
        case 0:       return "День впереди"
        case 1..<20:  return "Ужасный день"
        case 20..<40: return "Мог бы лучше"
        case 40..<60: return "Неплохо"
        case 60..<80: return "Хороший день"
        default:      return "Идеальный день"
        }
    }

    private static func emoji(for value: Int) -> String {
        switch value {
        case 0:        return "🌱"
        case 1..<20:   return "😞"
        case 20..<40:  return "😐"
        case 40..<60:  return "🙂"
        case 60..<80:  return "😊"
        case 80..<100: return "🔥"
        default:       return "⚡️"
        }
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
