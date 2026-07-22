//
//  PomodoroFormat.swift
//  Questly
//
//  Форматирование для экрана Помодоро: время и склонение сессий.
//  Вынесено из VC, потому что нужно и карточкам, и плашкам.
//

import Foundation

enum PomodoroFormat {

    /// «1 ч 05 мин» / «25 мин»
    static func timeString(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h) ч \(String(format: "%02d", m)) мин" : "\(m) мин"
    }

    /// 1 сессия / 2 сессии / 5 сессий
    static func sessionsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "сессия" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "сессии" }
        return "сессий"
    }
}
