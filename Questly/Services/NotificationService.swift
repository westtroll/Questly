//
//  NotificationService.swift
//  Questly
//
//  Умные локальные уведомления. Текст уведомления фиксируется
//  в момент планирования, поэтому после КАЖДОГО изменения данных
//  DataStore пересобирает расписание с актуальными цифрами —
//  тот же паттерн, что со снимком для виджета.
//

import Foundation
import UserNotifications

@MainActor
enum NotificationService {

    private static let enabledKey = "dq_notifications_enabled"
    private static let promptShownKey = "dq_notif_prompt_shown"
    private static let center = UNUserNotificationCenter.current()

    /// Показывали ли уже наш пре-промпт. Один раз за жизнь профиля:
    /// любой ответ запоминается, больше не пристаём.
    static var hasShownPrePrompt: Bool {
        get { UserDefaults.standard.bool(forKey: promptShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptShownKey) }
    }

    // MARK: - Время «защиты стрика»

    private static let guardHourKey = "dq_streak_guard_hour"
    private static let guardMinuteKey = "dq_streak_guard_minute"

    /// Час и минута вечернего напоминания-страховки. По умолчанию 21:30.
    static var streakGuardTime: (hour: Int, minute: Int) {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: guardHourKey) != nil else { return (21, 30) }
            return (defaults.integer(forKey: guardHourKey),
                    defaults.integer(forKey: guardMinuteKey))
        }
        set {
            UserDefaults.standard.set(newValue.hour, forKey: guardHourKey)
            UserDefaults.standard.set(newValue.minute, forKey: guardMinuteKey)
        }
    }

    /// Включены ли умные уведомления (тумблер в настройках)
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue {
                center.removeAllPendingNotificationRequests()
            }
        }
    }

    /// Запрос системного разрешения. Колбэк всегда на главном потоке.
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - Расписание

    /// Пересобирает все уведомления под текущее состояние дня.
    static func reschedule(score: Int, streak: Int) {
        guard isEnabled else { return }

        // Сносим старое расписание целиком — проще и надёжнее,
        // чем выборочно обновлять: источник правды один, и это данные.
        center.removeAllPendingNotificationRequests()

        let now = Date()

        // 1. Вечерний прогресс — сегодня в 19:00, если день не идеален.
        if score < 100,
           let fireDate = date(hour: 19, minute: 0, of: now), fireDate > now {
            schedule(
                id: "evening_progress",
                title: "⚡️ Осталось \(100 - score) баллов до идеального дня",
                body: "Ещё есть время добить задачи",
                at: fireDate
            )
        }

        // 2. Вечерняя страховка — время настраивается в настройках.
        //    Срабатывает, только если порог стрика ещё не взят:
        //    добил день раньше — вечером тишина.
        //    Копия зависит от ситуации: защищаем стрик или помогаем начать.
        let guardTime = streakGuardTime
        if score < AppConfig.streakThreshold,
           let fireDate = date(hour: guardTime.hour, minute: guardTime.minute, of: now),
           fireDate > now {
            let missing = AppConfig.streakThreshold - score
            if streak >= 1 {
                schedule(
                    id: "streak_risk",
                    title: "🔥 Стрик \(streak.daysString) под угрозой!",
                    body: "До полуночи нужно ещё \(missing) баллов, чтобы его сохранить",
                    at: fireDate
                )
            } else {
                schedule(
                    id: "streak_risk",
                    title: "🌱 День ещё не закрыт",
                    body: "Набери ещё \(missing) баллов — и начнётся новый стрик",
                    at: fireDate
                )
            }
        }

        // 3. Утренний старт — завтра в 9:00.
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           let fireDate = date(hour: 9, minute: 0, of: tomorrow) {
            schedule(
                id: "morning_start",
                title: "🎯 Новый день — новые 100 баллов",
                body: "С какой задачи начнёшь сегодня?",
                at: fireDate
            )
        }

        // 4. Новый квест дня — в полночь, когда ротация подкинула
        //    свежий. Заголовок содержит сам квест: интрига + польза.
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           let fireDate = date(hour: 0, minute: 0, of: tomorrow) {
            let quest = DailyQuestCatalog.quest(for: tomorrow)
            schedule(
                id: "daily_quest",
                title: "\(quest.emoji) Новый квест дня!",
                body: "«\(quest.title)» — выполни и получи +\(DailyQuest.rewardXP) XP",
                at: fireDate
            )
        }
    }

    // MARK: - Приватные помощники

    private static func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Конкретное время в заданный день
    private static func date(hour: Int, minute: Int, of day: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }
}

