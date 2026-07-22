//
//  Models.swift
//  Questly
//
//  Модели данных на SwiftData.
//  Макрос @Model превращает класс в персистентную модель: SwiftData сам
//  генерирует схему базы данных и отслеживает изменения свойств.
//  Заметь: это классы (reference type), а не структуры — SwiftData
//  требует классы, чтобы следить за объектами по ссылке.
//

import Foundation
import SwiftData

// MARK: - Константы приложения

enum AppConfig {
    /// Минимальный балл дня, чтобы день засчитался в стрик
    static let streakThreshold = 60
    /// Штраф за невыполненную задачу: её очки × этот множитель
    static let missedTaskPenaltyMultiplier = 2
    /// Штраф за обрыв стрика
    static let streakBreakPenalty = 500
    /// Минимальная длина стрика, обрыв которого штрафуется
    static let streakPenaltyMinLength = 7

    // MARK: Джокеры (спасение стрика)
    /// Максимум джокеров в запасе
    static let maxJokers = 3
    /// Сколько идеальных дней (100 баллов) даёт один джокер
    static let perfectDaysPerJoker = 3

    /// XP за доведённую до конца фокус-сессию помодоро
    static let pomodoroSessionXP = 10

    /// XP за прочитанную статью (начисляется один раз за статью)
    static let articleReadXP = 5

    /// Ссылка на страницу в App Store — для «поделиться».
    /// ЗАМЕНИТЬ на реальную после публикации приложения!
    static let appStoreURL = "https://apps.apple.com/app/id0000000000"

    /// Доступна ли блокировка приложений (Screen Time).
    /// Требует capability Family Controls — она есть только
    /// у платного Apple Developer аккаунта. Купишь — поставь true.
    static let isScreenTimeAvailable = false
}

// MARK: - Профиль пользователя (персонализация)
//
// Имя, пол, возраст и эмодзи-аватар. Хранится локально в UserDefaults —
// регистрация и сервер для персонализации не нужны.

enum Gender: Int, CaseIterable {
    case unspecified = 0
    case male
    case female

    var title: String {
        switch self {
        case .unspecified: return "Не указан"
        case .male:        return "Мужской"
        case .female:      return "Женский"
        }
    }
}

enum UserProfile {

    private static let nameKey = "dq_user_name"
    private static let avatarKey = "dq_user_avatar"
    private static let avatarColorKey = "dq_user_avatar_color"
    private static let genderKey = "dq_user_gender"
    private static let ageKey = "dq_user_age"
    private static let onboardingKey = "dq_onboarding_done"
    private static let memberSinceKey = "dq_member_since"

    static var name: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static var avatarEmoji: String {
        get { UserDefaults.standard.string(forKey: avatarKey) ?? "🙂" }
        set { UserDefaults.standard.set(newValue, forKey: avatarKey) }
    }

    /// Цвет фона аватарки — ключ из палитры CategoryColor
    static var avatarColorName: String {
        get { UserDefaults.standard.string(forKey: avatarColorKey) ?? "blue" }
        set { UserDefaults.standard.set(newValue, forKey: avatarColorKey) }
    }

    static var gender: Gender {
        get { Gender(rawValue: UserDefaults.standard.integer(forKey: genderKey)) ?? .unspecified }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: genderKey) }
    }

    /// Возраст; 0 — не указан
    static var age: Int {
        get { UserDefaults.standard.integer(forKey: ageKey) }
        set { UserDefaults.standard.set(min(max(newValue, 0), 120), forKey: ageKey) }
    }

    /// Пройден ли приветственный онбординг
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    /// Дата первого запуска. Фиксируется при первом же обращении —
    /// у существующих пользователей это будет момент обновления,
    /// у новых — настоящий первый запуск (сработает в онбординге).
    static var memberSince: Date {
        if let date = UserDefaults.standard.object(forKey: memberSinceKey) as? Date {
            return date
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: memberSinceKey)
        return now
    }

    /// «В Questly с 2026 года»
    static var memberSinceLine: String {
        let year = Calendar.current.component(.year, from: memberSince)
        return "В Questly с \(year) года"
    }

    /// Полный сброс профиля — для «выхода». Тема и настройки Помодоро
    /// не трогаются: это настройки устройства, а не профиля.
    static func reset() {
        let defaults = UserDefaults.standard
        [nameKey, avatarKey, avatarColorKey, genderKey, ageKey,
         onboardingKey, memberSinceKey].forEach { defaults.removeObject(forKey: $0) }
    }

    /// Приветствие по времени суток: «Доброе утро, Даня!»
    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12:  base = "Доброе утро"
        case 12..<18: base = "Добрый день"
        case 18..<23: base = "Добрый вечер"
        default:      base = "Доброй ночи"
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "\(base)!" : "\(base), \(trimmed)!"
    }

    /// «Мужской · 19 лет» — строка деталей для шапки профиля
    static var detailsLine: String {
        var parts: [String] = []
        if gender != .unspecified { parts.append(gender.title) }
        if age > 0 { parts.append(age.yearsString) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Category

@Model
final class Category {
    var name: String
    var icon: String        // имя SF Symbol
    var colorName: String   // ключ цвета из CategoryColor (Appearance.swift)
    var createdAt: Date

    // Ежедневная категория живёт вечно, разовая (isDaily == false)
    // удаляется при перекате дня — после попадания в историю.
    // Значение по умолчанию обязательно: SwiftData использует его
    // при миграции для уже существующих записей в базе.
    var isDaily: Bool = true

    // Закреплённые категории поднимаются в начало сетки.
    // Дефолт обязателен для миграции существующих записей.
    var isPinned: Bool = false

    // Связь «один ко многим». deleteRule: .cascade — при удалении категории
    // SwiftData автоматически удалит и все её задачи.
    // inverse указывает на обратную сторону связи (TaskItem.category).
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.category)
    var tasks: [TaskItem]

    init(name: String, icon: String, colorName: String, isDaily: Bool = true) {
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.isDaily = isDaily
        self.createdAt = .now
        self.tasks = []
    }

    // SwiftData не гарантирует порядок элементов в relationship-массиве,
    // поэтому для отображения сортируем по дате создания.
    var sortedTasks: [TaskItem] {
        tasks.sorted { $0.createdAt < $1.createdAt }
    }

    var totalPoints: Int  { tasks.reduce(0) { $0 + $1.points } }
    var earnedPoints: Int { tasks.filter(\.isCompleted).reduce(0) { $0 + $1.points } }
    var completedCount: Int { tasks.filter(\.isCompleted).count }
}

// MARK: - TaskItem
//
// Название TaskItem, а не Task — намеренно: Task уже занят
// Swift Concurrency (async/await), и одноимённый тип рано или поздно
// приведёт к конфликтам при использовании конкурентности.

@Model
final class TaskItem {
    var name: String
    var points: Int
    var isCompleted: Bool

    /// Заметка к задаче: детали, которые не влезают в название
    /// («безлактозное, синяя упаковка»). Дефолт — для миграции.
    var note: String = ""
    var createdAt: Date

    // Опциональные дата и время задачи. Дефолт nil обязателен
    // для миграции уже существующих записей.
    var dueDate: Date?
    var endDate: Date?

    var category: Category?

    init(name: String, points: Int, dueDate: Date? = nil, endDate: Date? = nil) {
        self.name = name
        self.points = points
        self.isCompleted = false
        self.createdAt = .now
        self.dueDate = dueDate
        self.endDate = endDate
    }
}

// MARK: - DayRecord
//
// Снимок завершённого дня. Создаётся автоматически при «перекате» дня
// (см. DataStore.performDayRolloverIfNeeded) и используется на экране
// «История» и при подсчёте стрика.

@Model
final class DayRecord {
    @Attribute(.unique) var date: Date   // всегда startOfDay
    var score: Int                       // итоговый балл 0–100
    var earnedPoints: Int
    var totalPoints: Int
    var completedTasks: Int
    var totalTasks: Int

    // Штраф дня: невыполненные задачи ×2 + возможный штраф за стрик.
    // Дефолт нужен для миграции уже существующих записей.
    var penaltyPoints: Int = 0

    init(date: Date, score: Int, earnedPoints: Int, totalPoints: Int,
         completedTasks: Int, totalTasks: Int, penaltyPoints: Int = 0) {
        self.date = date
        self.score = score
        self.earnedPoints = earnedPoints
        self.totalPoints = totalPoints
        self.completedTasks = completedTasks
        self.totalTasks = totalTasks
        self.penaltyPoints = penaltyPoints
    }
}

// MARK: - DayScore
//
// Не хранится в базе — это просто расчётная оценка текущего дня.

struct DayScore {
    let value: Int      // 0–100, для статуса, цвета и прогресс-бара
    let rawPoints: Int  // реальная сумма очков, может быть больше 100

    /// Единая точка расчёта балла дня. Баллы буквальные: задача
    /// на 20 очков даёт ровно +20. value обрезается до 100,
    /// а rawPoints сохраняет честную сумму — чтобы пользователь
    /// видел «102 / 100» и математика при удалении задач сходилась.
    init(earnedPoints: Int) {
        self.rawPoints = max(0, earnedPoints)
        self.value = min(100, rawPoints)
    }

    /// Для случаев, когда балл уже посчитан (например, из DayRecord).
    init(value: Int) {
        self.value = value
        self.rawPoints = value
    }

    var label: String {
        switch value {
        // Ноль — не «ужасный», а просто ещё не начатый день.
        // Приговор на старте демотивирует; нейтральный статус — нет.
        case 0:       return "День впереди"
        case 1..<20:  return "Ужасный день"
        case 20..<40: return "Мог бы лучше"
        case 40..<60: return "Неплохо"
        case 60..<80: return "Хороший день"
        default:      return "Идеальный день"
        }
    }

    var emoji: String {
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

    var hint: String {
        value >= 100
            ? "Идеальный день! Так держать"
            : "Ещё \(100 - value) баллов до идеального дня"
    }
}

// MARK: - Система уровней
//
// Уровень растёт от суммы очков за ВСЁ время (история + сегодня).
// Статус дня («хороший день») — про сегодня, уровень — про весь путь.

struct UserLevel {
    let level: Int
    let totalPoints: Int
    let currentThreshold: Int   // очки, с которых начался текущий уровень
    let nextThreshold: Int      // очки, нужные для следующего

    var pointsIntoLevel: Int { totalPoints - currentThreshold }
    var pointsForLevel: Int  { nextThreshold - currentThreshold }
    var pointsToNext: Int    { nextThreshold - totalPoints }

    /// Прогресс внутри текущего уровня, 0...1
    var progress: Double {
        Double(pointsIntoLevel) / Double(pointsForLevel)
    }

    var title: String {
        switch level {
        case 1:  return "Новичок"
        case 2:  return "Ученик"
        case 3:  return "Практик"
        case 4:  return "Мастер"
        case 5:  return "Гуру"
        default: return "Легенда"
        }
    }
}

enum LevelSystem {

    // Кумулятивные пороги ДОСТИЖЕНИЯ уровней 2, 3, 4, 5.
    // Хочешь поменять кривую прокачки — правь только этот массив.
    private static let baseThresholds = [100, 1_000, 3_000, 5_000]

    /// Сколько всего очков нужно, чтобы достичь заданного уровня
    static func threshold(toReach level: Int) -> Int {
        let index = level - 2          // уровень 2 → индекс 0
        guard index >= 0 else { return 0 }

        if index < baseThresholds.count {
            return baseThresholds[index]
        }
        // После базовых порогов — каждый следующий уровень +3000
        return baseThresholds.last! + (index - baseThresholds.count + 1) * 3_000
    }

    /// Определить уровень по сумме очков за всё время
    static func userLevel(totalPoints: Int) -> UserLevel {
        var level = 1
        while totalPoints >= threshold(toReach: level + 1) {
            level += 1
        }
        return UserLevel(
            level: level,
            totalPoints: totalPoints,
            currentThreshold: threshold(toReach: level),
            nextThreshold: threshold(toReach: level + 1)
        )
    }
}

// MARK: - Счётчики отказа от привычек

/// Формат отображения прошедшего времени
enum CounterFormat: Int, CaseIterable {
    case daysHoursMinutes = 0
    case daysOnly
    case monthsOnly
    case monthsDaysHours
    case yearsMonthsDays
    case timer
    case sinceDate

    var title: String {
        switch self {
        case .daysHoursMinutes: return "Дни, часы, минуты"
        case .daysOnly:         return "Только дни"
        case .monthsOnly:       return "Только месяцы"
        case .monthsDaysHours:  return "Месяцы, дни, часы"
        case .yearsMonthsDays:  return "Годы, месяцы, дни"
        case .timer:            return "Таймер"
        case .sinceDate:        return "Просто с даты"
        }
    }

    /// Строка прошедшего времени от startDate до «сейчас»
    func string(from start: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        switch self {
        case .daysHoursMinutes:
            let c = calendar.dateComponents([.day, .hour, .minute], from: start, to: now)
            return "\(c.day ?? 0) дн \(c.hour ?? 0) ч \(c.minute ?? 0) мин"
        case .daysOnly:
            let days = calendar.dateComponents([.day], from: start, to: now).day ?? 0
            return days.daysString
        case .monthsOnly:
            let months = calendar.dateComponents([.month], from: start, to: now).month ?? 0
            return "\(months) мес"
        case .monthsDaysHours:
            let c = calendar.dateComponents([.month, .day, .hour], from: start, to: now)
            return "\(c.month ?? 0) мес \(c.day ?? 0) дн \(c.hour ?? 0) ч"
        case .yearsMonthsDays:
            let c = calendar.dateComponents([.year, .month, .day], from: start, to: now)
            return "\(c.year ?? 0) г \(c.month ?? 0) мес \(c.day ?? 0) дн"
        case .timer:
            let seconds = max(0, Int(now.timeIntervalSince(start)))
            return String(format: "%02d:%02d:%02d",
                          seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        case .sinceDate:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMMM yyyy"
            return "с \(formatter.string(from: start))"
        }
    }
}

/// Период трат на привычку
enum SpendPeriod: Int, CaseIterable {
    case day = 0
    case week
    case month

    var title: String {
        switch self {
        case .day:   return "День"
        case .week:  return "Неделя"
        case .month: return "Месяц"
        }
    }

    /// Длина периода в днях — для пересчёта в дневную ставку
    var lengthInDays: Double {
        switch self {
        case .day:   return 1
        case .week:  return 7
        case .month: return 30
        }
    }
}

@Model
final class HabitCounter {
    var name: String
    var colorName: String       // стиль = цвет из палитры CategoryColor
    var startDate: Date         // начало отсчёта («когда бросил»)
    var formatRaw: Int = 0
    var spendAmount: Double = 0 // траты на привычку за период
    var spendPeriodRaw: Int = 0
    var currencyCode: String = "RUB"
    var createdAt: Date

    // Обещание: мотивация («почему я это делаю») и срок,
    // на который пользователь обещает себе не срываться.
    // Дефолты обязательны — для миграции существующих счётчиков.
    var promiseText: String = ""
    var promiseUntil: Date?

    /// Лучший заход (в секундах): самая долгая продержка между
    /// срывами. Фиксируется перед каждым сбросом отсчёта.
    var bestDuration: TimeInterval = 0

    /// Рекорд в днях с учётом текущего захода (он может быть лучшим).
    var bestDays: Int {
        let current = max(0, Date().timeIntervalSince(startDate))
        return Int(max(bestDuration, current) / 86_400)
    }

    /// Зафиксировать текущий заход в рекорд. Вызывать ПЕРЕД любым
    /// изменением startDate (сброс, правка даты) — иначе рекорд пропадёт.
    func recordCurrentRun() {
        let current = max(0, Date().timeIntervalSince(startDate))
        bestDuration = max(bestDuration, current)
    }

    var isPromiseActive: Bool {
        guard let promiseUntil else { return false }
        return promiseUntil > Date()
    }

    init(name: String, colorName: String, startDate: Date,
         format: CounterFormat, spendAmount: Double,
         spendPeriod: SpendPeriod, currencyCode: String) {
        self.name = name
        self.colorName = colorName
        self.startDate = startDate
        self.formatRaw = format.rawValue
        self.spendAmount = spendAmount
        self.spendPeriodRaw = spendPeriod.rawValue
        self.currencyCode = currencyCode
        self.createdAt = .now
    }

    var format: CounterFormat {
        get { CounterFormat(rawValue: formatRaw) ?? .daysHoursMinutes }
        set { formatRaw = newValue.rawValue }
    }

    var spendPeriod: SpendPeriod {
        get { SpendPeriod(rawValue: spendPeriodRaw) ?? .day }
        set { spendPeriodRaw = newValue.rawValue }
    }

    /// Сколько привычка съедала в день
    var dailySpend: Double {
        spendAmount / spendPeriod.lengthInDays
    }

    /// Накопленная экономия: дневная ставка × прошедшее время (непрерывно)
    func savedMoney(now: Date = Date()) -> Double {
        max(0, now.timeIntervalSince(startDate) / 86_400) * dailySpend
    }
}

// MARK: - Полезные привычки (внедряю)
//
// В отличие от разовых задач дня, полезная привычка — долгосрочный
// трекер: одна отметка в день, свой стрик, история отметок.

@Model
final class GoodHabit {
    var name: String
    var colorName: String
    var checkInDays: [Date] = []   // startOfDay каждой отметки
    var createdAt: Date

    init(name: String, colorName: String) {
        self.name = name
        self.colorName = colorName
        self.createdAt = .now
    }

    // MARK: Отметки

    func isChecked(on day: Date) -> Bool {
        let calendar = Calendar.current
        return checkInDays.contains { calendar.isDate($0, inSameDayAs: day) }
    }

    var isCheckedToday: Bool {
        isChecked(on: Date())
    }

    /// Поставить/снять сегодняшнюю отметку
    func toggleToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let index = checkInDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: today) }) {
            checkInDays.remove(at: index)
        } else {
            checkInDays.append(today)
        }
    }

    // MARK: Стрик привычки

    /// Серия подряд отмеченных дней. Если сегодня ещё не отмечено,
    /// серия «жива» и считается со вчерашнего дня — до полуночи
    /// есть шанс её продлить.
    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(checkInDays.map { calendar.startOfDay(for: $0) })

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    /// Лучшая серия за всю историю отметок: самая длинная цепочка
    /// подряд идущих дней. Вычислима из checkInDays — ничего
    /// дополнительно хранить не нужно.
    var bestStreak: Int {
        let calendar = Calendar.current
        let days = Set(checkInDays.map { calendar.startOfDay(for: $0) })
        var best = 0

        for day in days {
            // Начало цепочки — день, перед которым отметки нет.
            let previous = calendar.date(byAdding: .day, value: -1, to: day)!
            guard !days.contains(previous) else { continue }

            var length = 0
            var cursor = day
            while days.contains(cursor) {
                length += 1
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            best = max(best, length)
        }
        return best
    }

    // MARK: Полоска недели

    /// Последние 7 дней (по возрастанию): буква дня, отмечен ли, сегодня ли
    func weekStrip() -> [(letter: String, checked: Bool, isToday: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEEE"   // однобуквенный день недели

        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            return (
                letter: formatter.string(from: day).uppercased(),
                checked: isChecked(on: day),
                isToday: offset == 0
            )
        }
    }
}

// MARK: - Запланированные пункты на будущие дни
//
// Отдельная сущность: НЕ участвует в дневном счёте и штрафах.
// Живёт привязанной к дате и служит напоминанием. В свой день
// показывается как «запланировано на сегодня» и может быть
// превращена в обычную задачу дня или просто отмечена.

@Model
final class PlannedItem {
    var title: String
    var date: Date          // startOfDay дня, на который запланировано
    var timeText: String    // «15:00» или пусто — необязательное время
    var isDone: Bool = false
    var createdAt: Date

    init(title: String, date: Date, timeText: String = "") {
        self.title = title
        self.date = Calendar.current.startOfDay(for: date)
        self.timeText = timeText
        self.isDone = false
        self.createdAt = .now
    }
}

// MARK: - Эмоциональный дневник (check-in)
//
// Одна запись настроения на день. Значение 1..5 (от плохого к отличному).
// Живёт отдельно, не влияет на баллы — это дневник самочувствия.

@Model
final class MoodEntry {
    var date: Date          // startOfDay
    var value: Int          // 1...5
    var note: String
    var createdAt: Date

    init(date: Date, value: Int, note: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.value = min(max(value, 1), 5)
        self.note = note
        self.createdAt = .now
    }
}

/// Шкала настроения: эмодзи и подпись для значения 1..5
enum MoodScale {
    static let emojis = ["😞", "😕", "😐", "🙂", "😄"]
    static let labels = ["Плохо", "Так себе", "Нормально", "Хорошо", "Отлично"]

    static func emoji(for value: Int) -> String {
        emojis[min(max(value, 1), 5) - 1]
    }
    static func label(for value: Int) -> String {
        labels[min(max(value, 1), 5) - 1]
    }
}

// MARK: - Планировщик месяца
//
// Задачи «на этот месяц» без точной даты: «сходить к врачу»,
// «поменять резину». Когда дата созревает — переносятся в план
// конкретного дня (PlannedItem). Не влияют на баллы и штрафы.

@Model
final class MonthPlanItem {
    var title: String
    var month: Date         // начало месяца, к которому относится
    var isDone: Bool = false
    var createdAt: Date

    init(title: String, month: Date) {
        self.title = title
        self.month = MonthPlanItem.startOfMonth(month)
        self.isDone = false
        self.createdAt = .now
    }

    static func startOfMonth(_ date: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: comps)!
    }
}

// MARK: - Цели года
//
// Глобальные цели «на год»: крупные ориентиры, о которых важно
// помнить. Не влияют на баллы — это компас, а не задачи.

@Model
final class YearGoal {
    var title: String
    var year: Int
    var isDone: Bool = false
    var createdAt: Date

    init(title: String, year: Int) {
        self.title = title
        self.year = year
        self.isDone = false
        self.createdAt = .now
    }
}

// MARK: - Планировщик недели
//
// Как план месяца, но горизонт короче: дела «на этой неделе»,
// у которых пока нет конкретного дня.

@Model
final class WeekPlanItem {
    var title: String
    var weekStart: Date     // понедельник недели, к которой относится
    var isDone: Bool = false
    var createdAt: Date

    init(title: String, week: Date) {
        self.title = title
        self.weekStart = WeekPlanItem.startOfWeek(week)
        self.isDone = false
        self.createdAt = .now
    }

    static func startOfWeek(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
