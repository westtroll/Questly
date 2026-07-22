//
//  PomodoroActivityAttributes.swift
//  Questly
//
//  Контракт данных Live Activity Помодоро. Приложение создаёт
//  активность с этим состоянием, виджет-таргет рисует её UI.
//
//  ВАЖНО: файл должен входить в ОБА таргета!
//  File Inspector → Target Membership → Questly И QuestlyWidgetExtension.
//

import Foundation
import ActivityKit

struct PomodoroActivityAttributes: ActivityAttributes {

    // Динамическое состояние активности. Ключевая идея: передаём
    // ДАТЫ начала и конца фазы, а не «сколько осталось» — система
    // сама ведёт обратный отсчёт и прогресс, без обновлений от нас.
    struct ContentState: Codable, Hashable {
        var phaseTitle: String        // «Фокус» / «Перерыв»
        var startDate: Date           // начало фазы (для прогресс-бара)
        var endDate: Date             // конец фазы (для таймера)
        var isBreak: Bool             // перерыв? (иконка и цвет)
        var completedPomodoros: Int   // 🍅 сессий в текущем цикле
        var completedBreaks: Int      // ☕️ перерывов за сегодня
        var focusMinutesToday: Int    // минут фокуса за сегодня
    }
}
