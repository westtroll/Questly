//
//  Appearance.swift
//  Questly
//
//  Всё, что связано с внешним видом и не привязано к конкретному экрану:
//  палитра категорий, цвета оценки дня, лейбл с отступами, хаптика.
//

import UIKit
import AudioToolbox
import CoreHaptics

// MARK: - Палитра категорий
//
// Используем системные цвета — они автоматически адаптируются
// к светлой и тёмной теме, нам не нужно ничего делать вручную.

enum CategoryColor: String, CaseIterable {
    case green, teal, blue, purple, pink, red, orange, yellow

    var main: UIColor {
        switch self {
        case .green:  return .systemGreen
        case .teal:   return .systemTeal
        case .blue:   return .systemBlue
        case .purple: return .systemPurple
        case .pink:   return .systemPink
        case .red:    return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        }
    }

    /// Полупрозрачная версия для фонов иконок и бейджей
    var background: UIColor { main.withAlphaComponent(0.16) }

    /// Достаём цвет по строке из модели; если не нашли — зелёный по умолчанию
    static func named(_ name: String) -> CategoryColor {
        CategoryColor(rawValue: name) ?? .green
    }
}

// MARK: - Цвет оценки дня

extension DayScore {
    var color: UIColor {
        switch value {
        case 0:       return .systemGray    // нейтральный «день впереди»
        case 1..<20:  return .systemRed
        case 20..<60: return .systemOrange
        default:      return .systemGreen
        }
    }
}

// MARK: - PaddedLabel
//
// UILabel с внутренними отступами — для «пилюль» (стрик, статус, баллы).
// Раньше отступы делались пробелами в тексте — это хрупко,
// правильнее переопределить отрисовку и intrinsicContentSize.

final class PaddedLabel: UILabel {

    var insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

// MARK: - Haptics
//
// Тактильный отклик. Мелочь, а ощущение от приложения меняет сильно.

enum Haptics {

    // Генераторы кэшируются и держатся «прогретыми» через prepare():
    // созданный на месте генератор без подготовки глотает вибрацию
    // (Taptic-движок спит), особенно первую после простоя и на старте.
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let notifier = UINotificationFeedbackGenerator()

    /// Разбудить движок заранее (например, на сплэше перед анимацией)
    static func warmUp() {
        impact.prepare()
        notifier.prepare()
    }

    /// Лёгкий «тук» — отметка задачи, жмяки
    static func light() {
        impact.impactOccurred(intensity: 0.7)
        impact.prepare()   // готовим следующий
    }

    /// Праздничный отклик — награды, идеальный день, конец сессии
    static func success() {
        notifier.notificationOccurred(.success)
        notifier.prepare()
    }

    /// Двойной «предупреждающий» толчок — конец перерыва, пора к делу
    static func warning() {
        notifier.notificationOccurred(.warning)
        notifier.prepare()
    }

    // MARK: Мощная вибрация (CoreHaptics)
    //
    // Системная kSystemSoundID_Vibrate фиксированная и менять её силу
    // нельзя. CoreHaptics позволяет гнать Taptic-движок на полную:
    // непрерывный сигнал intensity 1.0 ощущается заметно мощнее.
    // Фолбэк на системную вибрацию — для старых устройств и ошибок.

    private static var engine: CHHapticEngine?

    private static func playPattern(_ events: [CHHapticEvent]) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            return
        }
        do {
            if engine == nil {
                engine = try CHHapticEngine()
                // Система может остановить движок (фон, звонок) —
                // сбрасываем, при следующем вызове создастся заново.
                engine?.resetHandler = { Self.engine = nil }
                engine?.stoppedHandler = { _ in Self.engine = nil }
            }
            try engine?.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private static func buzz(at time: TimeInterval, duration: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        .init(parameterID: .hapticIntensity, value: 1.0),
                        .init(parameterID: .hapticSharpness, value: 0.55)
                      ],
                      relativeTime: time,
                      duration: duration)
    }

    /// Мощная вибрация на всю катушку Taptic-движка.
    /// Работает только в форграунде; в фоне вибрирует само уведомление.
    static func vibrate() {
        playPattern([buzz(at: 0, duration: 1.0)])
    }

    /// Двойная мощная вибрация — «пора к делу», не спутать с одиночной
    static func vibrateDouble() {
        playPattern([
            buzz(at: 0,    duration: 0.6),
            buzz(at: 0.85, duration: 0.6)
        ])
    }
}

// MARK: - String helper

extension String {
    /// «суббота, 4 июля» → «Суббота, 4 июля»
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

// MARK: - Склонение «дней»

extension Int {
    /// 0 дней, 1 день, 2 дня, 5 дней, 11 дней, 21 день...
    var daysString: String {
        let mod100 = self % 100
        // 11–14 — всегда «дней» (11 дней, 12 дней...),
        // проверяем ДО остатка от 10, иначе 11 станет «11 день».
        if (11...14).contains(mod100) { return "\(self) дней" }
        switch self % 10 {
        case 1:       return "\(self) день"
        case 2, 3, 4: return "\(self) дня"
        default:      return "\(self) дней"
        }
    }

    /// 1 год, 2 года, 5 лет, 11 лет, 21 год...
    var yearsString: String {
        let mod100 = self % 100
        if (11...14).contains(mod100) { return "\(self) лет" }
        switch self % 10 {
        case 1:       return "\(self) год"
        case 2, 3, 4: return "\(self) года"
        default:      return "\(self) лет"
        }
    }
}

// MARK: - Тема приложения

enum AppTheme: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2
    case auto   = 3   // день/ночь по времени суток

    var title: String {
        switch self {
        case .system: return "Как в системе"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        case .auto:   return "Авто (день/ночь)"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        case .auto:   return "sun.horizon.fill"
        }
    }

    // UIKit-стиль интерфейса. .unspecified = следовать системе.
    var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        case .auto:
            // Ночь — с 21:00 до 7:00, остальное — день.
            let hour = Calendar.current.component(.hour, from: Date())
            return (hour >= 21 || hour < 7) ? .dark : .light
        }
    }
}

@MainActor
enum ThemeManager {

    private static let key = "dq_theme"

    static var current: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            apply()
        }
    }

    // Тема переключается через overrideUserInterfaceStyle у окна:
    // одна строчка — и ВСЕ системные цвета (.label, .systemBackground,
    // .systemGreen...) автоматически перекрашиваются. Именно поэтому
    // мы везде использовали системные цвета, а не хардкод.
    static func apply() {
        let style = current.style
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                // Лёгкая анимация перехода между темами
                UIView.transition(with: window, duration: 0.25,
                                  options: .transitionCrossDissolve) {
                    window.overrideUserInterfaceStyle = style
                }
            }
    }
}

