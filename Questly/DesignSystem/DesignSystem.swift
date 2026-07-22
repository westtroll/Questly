//
//  DesignSystem.swift
//  Questly
//
//  Единый источник правды для визуального языка приложения:
//  бирюзовый акцент, скруглённый шрифт для заголовков, радиусы,
//  отступы. Всё оформление кормится отсюда — никаких «магических»
//  цветов и чисел по экранам.
//

import UIKit

// MARK: - Палитра

enum DQColor {

    /// Основной бирюзовый акцент (кнопки, прогресс, активные состояния)
    static let accent = UIColor(hex: 0x1D9E75)
    /// Тёмный оттенок акцента — для текста на светло-бирюзовом фоне
    static let accentDark = UIColor(hex: 0x0F6E56)
    /// Светлая заливка акцента (фон пилюль, кружков иконок, полос прогресса)
    static let accentSoft = UIColor(hex: 0xE1F5EE)

    // Вторичный акцент — челленджи и «испытания». Осознанно отличается
    // от бирюзы: бирюза = повседневный прогресс, этот = особые вызовы.
    static let challenge = UIColor(hex: 0x7F77DD)       // мягкий индиго-фиолет
    static let challengeDark = UIColor(hex: 0x3C3489)
    static var challengeSoftAdaptive: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: 0x3C3489).withAlphaComponent(0.30)
                : UIColor(hex: 0xEEEDFE)
        }
    }
    static var challengeAdaptive: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: 0xAFA9EC)
                : challenge
        }
    }

    /// Акцент, адаптивный к тёмной теме: в тёмной — светлее, чтобы читался
    static var accentAdaptive: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: 0x5DCAA5)
                : accent
        }
    }

    /// Мягкая заливка акцента, адаптивная к теме
    static var accentSoftAdaptive: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: 0x0F6E56).withAlphaComponent(0.25)
                : accentSoft
        }
    }

    // Фоны — остаются системными ради бесплатной тёмной темы
    static let background = UIColor.systemGroupedBackground
    static let card = UIColor.secondarySystemGroupedBackground
}

// MARK: - Шрифты

enum DQFont {

    /// Скруглённый системный шрифт (SF Rounded) заданного размера/веса.
    /// Даёт дружелюбный тон. Fallback на обычный системный, если
    /// скруглённый дизайн недоступен.
    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Скруглённый шрифт с моноширинными цифрами — для таймеров и
    /// счётчиков, чтобы цифры не «прыгали» при обновлении.
    static func roundedMono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let rounded = rounded(size, weight: weight)
        let settings: [UIFontDescriptor.FeatureKey: Int] = [
            .featureIdentifier: kNumberSpacingType,
            .typeIdentifier: kMonospacedNumbersSelector
        ]
        let desc = rounded.fontDescriptor.addingAttributes([.featureSettings: [settings]])
        return UIFont(descriptor: desc, size: size)
    }

    // Ходовые роли — заголовки и крупные числа скруглённые,
    // тело оставляем обычным системным (читается лучше в мелком).
    static var largeNumber: UIFont { rounded(34, weight: .bold) }
    static var title: UIFont { rounded(22, weight: .bold) }
    static var headline: UIFont { rounded(17, weight: .semibold) }
    static var pill: UIFont { rounded(13, weight: .semibold) }
}

// MARK: - Метрики

enum DQMetric {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 14
    static let pillRadius: CGFloat = 20

    static let padS: CGFloat = 8
    static let padM: CGFloat = 14
    static let padL: CGFloat = 20
}

// MARK: - Хелперы стиля

extension UIColor {
    /// Инициализация из hex-числа вида 0x1D9E75
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

extension UIView {
    /// Оформить как стандартную карточку Questly
    func applyCardStyle() {
        backgroundColor = DQColor.card
        layer.cornerRadius = DQMetric.cardRadius
    }
}

// MARK: - Инлайн-иконка в тексте

extension NSAttributedString {
    /// Строка вида «[icon] текст» с SF Symbol в потоке текста —
    /// замена структурным эмодзи в статус-лейблах и бейджах.
    static func withIcon(_ symbolName: String,
                         text: String,
                         font: UIFont,
                         color: UIColor,
                         iconColor: UIColor? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: font.pointSize * 0.92, weight: .semibold)
        attachment.image = UIImage(systemName: symbolName)?
            .withConfiguration(config)
            .withTintColor(iconColor ?? color, renderingMode: .alwaysOriginal)
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: "  " + text))

        result.addAttributes(
            [.font: font, .foregroundColor: color],
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}

extension UIButton {
    /// Главная бирюзовая кнопка-призыв (капсула, белый текст)
    static func dqPrimary(title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = DQColor.accent
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = DQFont.rounded(17, weight: .semibold)
            return attrs
        }
        return UIButton(configuration: config)
    }
}

// MARK: - Иконка в цветном кружке

enum DQIcon {
    /// Круглая подложка с SF Symbol внутри — замена эмодзи-иконкам
    /// в заголовках карточек. Кружок в мягком цвете роли, символ — в ярком.
    static func circle(symbol: String,
                       tint: UIColor,
                       soft: UIColor,
                       diameter: CGFloat = 44,
                       symbolSize: CGFloat = 20) -> UIView {
        let circle = UIView()
        circle.backgroundColor = soft
        circle.layer.cornerRadius = diameter / 2
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.setContentHuggingPriority(.required, for: .horizontal)

        let icon = UIImageView(
            image: UIImage(systemName: symbol)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold))
        )
        icon.tintColor = tint
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(icon)

        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: diameter),
            circle.heightAnchor.constraint(equalToConstant: diameter),
            icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        return circle
    }
}

// MARK: - «Жмяк» — фирменная тактильная анимация

extension UIView {
    /// Разовый «жмяк»: быстрое сжатие и упругий возврат.
    /// Амплитуда по умолчанию — для крупных карточек; мелким
    /// элементам можно передать масштаб поменьше (сильнее).
    func dqSquish(scale: CGFloat = 0.965) {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 0,
                           usingSpringWithDamping: 0.4,
                           initialSpringVelocity: 6) {
                self.transform = .identity
            }
        })
    }

    /// Сделать вью «жмякаемой» по тапу — чистая тактильная игрушка
    /// без функции. Кнопки внутри вью продолжают работать: они
    /// перехватывают свои касания раньше жеста.
    func dqMakeSquishy(scale: CGFloat = 0.965) {
        isUserInteractionEnabled = true
        addGestureRecognizer(DQSquishTap(scale: scale))
    }
}

/// Тап-жест, который жмякает собственную вью.
final class DQSquishTap: UITapGestureRecognizer {
    private let scale: CGFloat

    init(scale: CGFloat) {
        self.scale = scale
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
    }

    @objc private func fire() {
        Haptics.light()
        view?.dqSquish(scale: scale)
    }
}


/// Жмяк «при прикосновении» для обычных UIView с tap-действием:
/// прожимается, пока палец на вью, пружинит при отпускании.
/// Не мешает основному tap-жесту (распознаётся одновременно).
final class DQPressSquish: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    private let scale: CGFloat

    init(scale: CGFloat = 0.97) {
        self.scale = scale
        super.init(target: nil, action: nil)
        minimumPressDuration = 0
        cancelsTouchesInView = false
        delegate = self
        addTarget(self, action: #selector(handle))
    }

    @objc private func handle() {
        guard let view else { return }
        switch state {
        case .began:
            UIView.animate(withDuration: 0.12, delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = CGAffineTransform(scaleX: self.scale, y: self.scale)
            }
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.4, delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = .identity
            }
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

extension UIView {
    /// Прожатие при касании (для карточек, открывающих экраны).
    func dqMakePressable(scale: CGFloat = 0.97) {
        isUserInteractionEnabled = true
        addGestureRecognizer(DQPressSquish(scale: scale))
    }
}


// MARK: - Конфетти

enum DQConfetti {

    /// Залп конфетти сверху экрана в фирменных цветах.
    /// Эмиттер сам гаснет и убирается — вызвал и забыл.
    @MainActor
    static func burst(in view: UIView) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -12)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        emitter.beginTime = CACurrentMediaTime()

        let colors: [UIColor] = [
            DQColor.accent, DQColor.challenge,
            .systemOrange, .systemYellow, .systemPink
        ]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.contents = confettiPiece(color: color).cgImage
            cell.birthRate = 8
            cell.lifetime = 5
            cell.velocity = 190
            cell.velocityRange = 70
            cell.emissionLongitude = .pi          // вниз
            cell.emissionRange = .pi / 5
            cell.spin = 4
            cell.spinRange = 6
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.yAcceleration = 90
            return cell
        }
        view.layer.addSublayer(emitter)

        // Короткий залп: через 0.7с прекращаем рождение частиц,
        // через 5с убираем слой целиком.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            emitter.removeFromSuperlayer()
        }
    }

    private static func confettiPiece(color: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 7)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                         cornerRadius: 2).fill()
        }
    }
}
