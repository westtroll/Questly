//
//  PomodoroViewModel.swift
//  Questly
//
//  Логика таймера Помодоро: 25 минут фокуса → 5 минут перерыва,
//  после 4 «помидоров» — длинный перерыв 15 минут.
//
//  ВАЖНО про фон: iOS замораживает таймеры, когда приложение свёрнуто.
//  Поэтому мы храним НЕ «сколько осталось», а ДАТУ ОКОНЧАНИЯ фазы —
//  и на каждом тике вычисляем остаток от неё. Вернулся из фона через
//  10 минут — таймер честно покажет актуальное время.
//

import Foundation
import Combine
import ActivityKit
import UserNotifications

// MARK: - Настройки длительностей
//
// Хранятся в UserDefaults. UserDefaults потокобезопасен,
// поэтому изоляция актора здесь не нужна.

enum PomodoroSettings {

    private static let workKey  = "dq_pomo_work_minutes"
    private static let shortKey = "dq_pomo_short_minutes"
    private static let longKey  = "dq_pomo_long_minutes"

    // integer(forKey:) возвращает 0, если значения нет —
    // используем это как признак «настройка не менялась, берём дефолт».
    static var workMinutes: Int {
        get { defaultIfZero(UserDefaults.standard.integer(forKey: workKey), 25) }
        set { UserDefaults.standard.set(newValue, forKey: workKey) }
    }

    static var shortBreakMinutes: Int {
        get { defaultIfZero(UserDefaults.standard.integer(forKey: shortKey), 5) }
        set { UserDefaults.standard.set(newValue, forKey: shortKey) }
    }

    static var longBreakMinutes: Int {
        get { defaultIfZero(UserDefaults.standard.integer(forKey: longKey), 15) }
        set { UserDefaults.standard.set(newValue, forKey: longKey) }
    }

    private static func defaultIfZero(_ value: Int, _ fallback: Int) -> Int {
        value == 0 ? fallback : value
    }
}

// MARK: - Фазы

enum PomodoroPhase {
    case work
    case shortBreak
    case longBreak

    // Длительность читается из настроек при каждом обращении —
    // новая фаза автоматически берёт актуальные значения.
    var duration: TimeInterval {
        switch self {
        case .work:       return TimeInterval(PomodoroSettings.workMinutes * 60)
        case .shortBreak: return TimeInterval(PomodoroSettings.shortBreakMinutes * 60)
        case .longBreak:  return TimeInterval(PomodoroSettings.longBreakMinutes * 60)
        }
    }

    var title: String {
        switch self {
        case .work:       return "Фокус"
        case .shortBreak: return "Перерыв"
        case .longBreak:  return "Длинный перерыв"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class PomodoroViewModel {

    /// Единый экземпляр: экран Помодоро и кнопки Live Activity
    /// (App Intents) должны управлять ОДНИМ и тем же таймером.
    static let shared = PomodoroViewModel()

    /// Сколько «помидоров» в цикле до длинного перерыва
    static let pomodorosPerCycle = 4

    // MARK: Published

    @Published private(set) var phase: PomodoroPhase = .work
    @Published private(set) var remaining: TimeInterval = PomodoroPhase.work.duration
    @Published private(set) var isRunning = false
    @Published private(set) var completedPomodoros = 0   // 0...4 в текущем цикле
    private(set) var completedBreaksToday = 0             // ☕️ перерывов завершено (для плашки)

    /// Название текущего фокуса — «над чем работаю».
    /// Переживает перезапуски и подставляется в следующий старт.
    @Published var focusLabel: String? =
        UserDefaults.standard.string(forKey: "dq_pomodoro_focus_label") {
        didSet {
            UserDefaults.standard.set(focusLabel, forKey: "dq_pomodoro_focus_label")
            if let label = focusLabel, !label.isEmpty { FocusList.add(label) }
        }
    }

    /// Статистика по текущему фокусу за сегодня: завершённые сессии
    /// и минуты (минуты — включая идущую фазу).
    var focusTodayLive: (sessions: Int, minutes: Int) {
        guard let label = focusLabel, !label.isEmpty else { return (0, 0) }
        var detail = PomodoroStats.todayDetail(label: label)
        if phase == .work, isRunning {
            detail.minutes += Int((phase.duration - remaining) / 60)
        }
        return detail
    }

    // MARK: Приватное состояние

    private var endDate: Date?
    private var timer: AnyCancellable?
    private var liveActivity: Activity<PomodoroActivityAttributes>?

    // MARK: Init

    init() {
        // Подчищаем «осиротевшие» активности с прошлого запуска —
        // например, если приложение убили свайпом при работающем таймере.
        for orphan in Activity<PomodoroActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
        // Аналогично снимаем «застрявший» щит блокировки: настройки
        // ManagedSettings переживают завершение приложения.
        FocusBlockService.shared.stopBlocking()
    }

    // MARK: Вычисляемые свойства

    /// Прогресс фазы 0...1 — для кольца
    var progress: Double {
        1 - remaining / phase.duration
    }

    /// «24:59» — минуты и секунды
    var timeString: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: Управление

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        // Дата окончания = сейчас + остаток. Это единственный
        // источник правды, пока таймер запущен.
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true

        // Тикаем дважды в секунду: секундная точность на экране
        // без заметного лага при возврате из фона.
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }

        startLiveActivity()
        schedulePhaseEndNotification()

        // Щит поднимаем только на фазе фокуса — перерывы свободные.
        if phase == .work {
            FocusBlockService.shared.startBlocking()
        }
    }

    func pause() {
        if let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        endDate = nil
        isRunning = false
        timer = nil   // отмена подписки останавливает Timer.publish

        endLiveActivity()
        FocusBlockService.shared.stopBlocking()
        cancelPhaseEndNotification()
    }

    /// Сбросить текущую фазу к началу
    func reset() {
        pause()
        remaining = phase.duration
    }

    /// Пропустить фазу (перейти к следующей без празднования)
    func skip() {
        advancePhase(completedNaturally: false)
    }

    // MARK: Команды с плашки Live Activity (App Intents)

    /// Кнопка «Завершить»: остановить досрочно и сбросить фазу.
    /// Плашку убирает pause() → endLiveActivity().
    func endFromLiveActivity() {
        pause()
        remaining = phase.duration
    }

    /// Кнопка «Старт» на устаревшей плашке: фаза дотикала в фоне
    /// (тик не работал — приложение спало), поэтому засчитываем
    /// завершение вручную и сразу запускаем следующую фазу.
    /// LiveActivityIntent разрешает стартовать активность из фона.
    func startNextFromLiveActivity() {
        if let endDate, endDate.timeIntervalSinceNow <= 0 {
            advancePhase(completedNaturally: true)
        }
        start()
    }

    // MARK: Приватные методы

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)

        if remaining <= 0 {
            advancePhase(completedNaturally: true)
        }
    }

    private func advancePhase(completedNaturally: Bool) {
        timer = nil
        // При пропуске фазы уведомление о её конце больше не нужно.
        // (При естественном завершении оно как раз должно сработать —
        // но advancePhase зовётся из tick в форграунде, где баннер
        // системой не показывается, так что отменять безопасно.)
        if !completedNaturally { cancelPhaseEndNotification() }
        endDate = nil
        isRunning = false
        endLiveActivity()
        FocusBlockService.shared.stopBlocking()

        switch phase {
        case .work:
            completedPomodoros += 1
            // Засчитываем сессию только доведённую до конца — скип
            // рабочей фазы фокусом не считается.
            if completedNaturally {
                PomodoroStats.recordSession(minutes: PomodoroSettings.workMinutes, label: focusLabel)
                // Фокус вписан в экономику: сессия = честный XP.
                DataStore.shared.awardBonusXP(AppConfig.pomodoroSessionXP)
                Haptics.vibrate()   // конец рабочей сессии — полноценная вибрация
            }
            phase = completedPomodoros >= Self.pomodorosPerCycle ? .longBreak : .shortBreak
        case .shortBreak:
            // Конец перерыва — двойная вибрация: пора к делу.
            if completedNaturally {
                completedBreaksToday += 1
                Haptics.vibrateDouble()
            }
            phase = .work
        case .longBreak:
            if completedNaturally {
                completedBreaksToday += 1
                Haptics.vibrateDouble()
            }
            completedPomodoros = 0   // цикл завершён — начинаем заново
            phase = .work
        }

        remaining = phase.duration

        // Хаптик-«праздник» убран: вибрация выше его перекрывает,
        // дублировать отклик нет смысла.
    }

    // MARK: - Live Activity

    // MARK: Уведомление о конце фазы

    // Таймер в фоне не тикает — о завершении фазы сообщает локальное
    // уведомление, запланированное на endDate. Свернул приложение
    // посреди сессии — телефон сам скажет, что пора отдыхать.
    private func schedulePhaseEndNotification() {
        guard let endDate, endDate.timeIntervalSinceNow > 1 else { return }

        let content = UNMutableNotificationContent()
        switch phase {
        case .work:
            content.title = "Сессия завершена! 🎉"
            content.body = "25 минут фокуса позади (+\(AppConfig.pomodoroSessionXP) XP). Время отдохнуть."
        case .shortBreak, .longBreak:
            content.title = "Перерыв окончен"
            content.body = "Отдохнул? Пора сфокусироваться на следующей сессии."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: endDate.timeIntervalSinceNow, repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "pomodoro_phase_end", content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelPhaseEndNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["pomodoro_phase_end"])
    }

    private func startLiveActivity() {
        // Пользователь может запретить Live Activities в настройках —
        // тогда молча работаем без них.
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let endDate else { return }

        // startDate считаем от полной длительности фазы: если таймер
        // возобновили с середины, прогресс-бар покажет честную позицию.
        // На плашке рабочая фаза подписана названием фокуса, если есть
        let activityTitle = (phase == .work && !(focusLabel ?? "").isEmpty)
            ? focusLabel! : phase.title
        let state = PomodoroActivityAttributes.ContentState(
            phaseTitle: activityTitle,
            startDate: endDate.addingTimeInterval(-phase.duration),
            endDate: endDate,
            isBreak: phase != .work,
            completedPomodoros: completedPomodoros,
            completedBreaks: completedBreaksToday,
            focusMinutesToday: PomodoroStats.today()
        )
        // staleDate = конец фазы: если мы «пропали», система сама
        // пометит активность устаревшей.
        let content = ActivityContent(state: state, staleDate: endDate)

        liveActivity = try? Activity.request(
            attributes: PomodoroActivityAttributes(),
            content: content
        )
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}


// MARK: - Список фокусов пользователя
//
// Названия, между которыми можно переключаться на экране Помодоро.
// Живёт отдельно от истории сессий: фокус существует и до первой
// сессии, и после удаления его история остаётся в статистике.

enum FocusList {

    private static let key = "dq_pomodoro_focus_list"

    static func all() -> [String] {
        if let list = UserDefaults.standard.stringArray(forKey: key) {
            return list
        }
        // Первый запуск после обновления: собираем список из истории
        let seeded = PomodoroStats.recentLabels(limit: 10)
        UserDefaults.standard.set(seeded, forKey: key)
        return seeded
    }

    static func add(_ label: String) {
        var list = all()
        guard !list.contains(label) else { return }
        list.insert(label, at: 0)
        UserDefaults.standard.set(list, forKey: key)
    }

    static func remove(_ label: String) {
        var list = all()
        list.removeAll { $0 == label }
        UserDefaults.standard.set(list, forKey: key)
    }

    /// Полный сброс списка и текущего выбранного фокуса
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "dq_pomodoro_focus_label")
    }
}


// MARK: - Статистика фокус-сессий
//
// Записываем завершённые рабочие фазы: дата + минуты. Хранится
// в UserDefaults, старше 60 дней — чистится само.

enum PomodoroStats {

    private static let key = "dq_pomodoro_sessions"

    private struct Session: Codable {
        let date: Date
        let minutes: Int
        var label: String? = nil   // опционал: старые записи без него читаются
    }

    private static let totalSessionsKey = "dq_pomodoro_total_sessions"
    private static let totalMinutesKey = "dq_pomodoro_total_minutes"

    /// Сессий за всё время (для ачивок — не обрезается 60 днями)
    static var totalSessions: Int {
        UserDefaults.standard.integer(forKey: totalSessionsKey)
    }
    /// Минут фокуса за всё время
    static var totalMinutes: Int {
        UserDefaults.standard.integer(forKey: totalMinutesKey)
    }

    static func recordSession(minutes: Int, label: String? = nil) {
        let defaults = UserDefaults.standard
        defaults.set(totalSessions + 1, forKey: totalSessionsKey)
        defaults.set(totalMinutes + minutes, forKey: totalMinutesKey)

        var sessions = load()
        sessions.append(Session(date: Date(), minutes: minutes, label: label))
        // Не копим бесконечно.
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        sessions.removeAll { $0.date < cutoff }
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
        cache = sessions   // кэш всегда отражает то, что записали
    }

    /// Минут фокуса за сегодня (для плашки Live Activity)
    static func today() -> Int {
        let dayStart = Calendar.current.startOfDay(for: Date())
        return load().filter { $0.date >= dayStart }.reduce(0) { $0 + $1.minutes }
    }

    /// Минут за сегодня по конкретному фокусу
    static func today(label: String) -> Int {
        let dayStart = Calendar.current.startOfDay(for: Date())
        return load()
            .filter { $0.date >= dayStart && $0.label == label }
            .reduce(0) { $0 + $1.minutes }
    }

    /// (сессий, минут) за сегодня по конкретному фокусу
    static func todayDetail(label: String) -> (sessions: Int, minutes: Int) {
        let dayStart = Calendar.current.startOfDay(for: Date())
        let todays = load().filter { $0.date >= dayStart && $0.label == label }
        return (todays.count, todays.reduce(0) { $0 + $1.minutes })
    }

    /// Последние использованные названия фокусов (уникальные, по свежести)
    static func recentLabels(limit: Int = 5) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in load().sorted(by: { $0.date > $1.date }) {
            guard let label = session.label, !label.isEmpty,
                  seen.insert(label).inserted else { continue }
            result.append(label)
            if result.count == limit { break }
        }
        return result
    }

    /// (сессий, минут) с начала текущей недели
    static func thisWeek() -> (sessions: Int, minutes: Int) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        else { return (0, 0) }
        let recent = load().filter { $0.date >= weekStart }
        return (recent.count, recent.reduce(0) { $0 + $1.minutes })
    }

    /// Разбор по фокусам за интервал: [(название, сессий, минут)],
    /// по убыванию минут. Сессии без метки собираются в «Без фокуса».
    static func byLabel(from start: Date, to end: Date? = nil)
        -> [(label: String, sessions: Int, minutes: Int)] {
        var acc: [String: (sessions: Int, minutes: Int)] = [:]
        for session in load()
        where session.date >= start && (end == nil || session.date < end!) {
            let key = (session.label?.isEmpty == false) ? session.label! : "Без фокуса"
            acc[key, default: (0, 0)].sessions += 1
            acc[key, default: (0, 0)].minutes += session.minutes
        }
        return acc
            .map { (label: $0.key, sessions: $0.value.sessions, minutes: $0.value.minutes) }
            .sorted { $0.minutes > $1.minutes }
    }

    /// Разбор по фокусам за текущую неделю
    static func weekByLabel() -> [(label: String, sessions: Int, minutes: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        else { return [] }
        return byLabel(from: weekStart)
    }

    /// Разбор по фокусам за конкретный день недели (0 = понедельник)
    static func dayByLabel(index: Int) -> [(label: String, sessions: Int, minutes: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let dayStart = calendar.date(byAdding: .day, value: index, to: weekStart),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else { return [] }
        return byLabel(from: dayStart, to: dayEnd)
    }

    /// Детально по дням текущей недели: [(сессий, минут)] пн...вс
    static func weekDetailByDay() -> [(sessions: Int, minutes: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        else { return Array(repeating: (0, 0), count: 7) }

        var result = Array(repeating: (sessions: 0, minutes: 0), count: 7)
        for session in load() where session.date >= weekStart {
            let index = calendar.dateComponents([.day], from: weekStart, to: session.date).day ?? 0
            if (0..<7).contains(index) {
                result[index].sessions += 1
                result[index].minutes += session.minutes
            }
        }
        return result
    }

    /// Минуты фокуса по дням текущей недели: [пн, вт, ..., вс]
    static func weekMinutesByDay() -> [Int] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        else { return Array(repeating: 0, count: 7) }

        var result = Array(repeating: 0, count: 7)
        for session in load() where session.date >= weekStart {
            let index = calendar.dateComponents([.day], from: weekStart, to: session.date).day ?? 0
            if (0..<7).contains(index) {
                result[index] += session.minutes
            }
        }
        return result
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: totalSessionsKey)
        UserDefaults.standard.removeObject(forKey: totalMinutesKey)
        cache = nil
    }

    // Кэш декодированных сессий. Без него каждый тик таймера
    // (focusTodayLive → todayDetail → load) декодировал весь JSON
    // истории из UserDefaults — раз в секунду ради числа, которое
    // меняется раз в минуту. Единственный писатель — recordSession,
    // он же обновляет кэш, поэтому инвалидация тривиальна.
    private static var cache: [Session]?

    private static func load() -> [Session] {
        if let cache { return cache }
        let sessions: [Session]
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
        } else {
            sessions = []
        }
        cache = sessions
        return sessions
    }
}
