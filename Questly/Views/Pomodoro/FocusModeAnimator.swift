//
//  FocusModeAnimator.swift
//  Questly
//
//  Анимация «режима фокуса»: при старте таймера кольцо уезжает
//  в центр экрана и подрастает, кнопки — к нижнему краю, всё
//  лишнее тает; над кольцом появляется название фокуса.
//
//  Только transform и alpha — констрейнты не трогаются, поэтому
//  обратный путь это просто .identity и alpha 1, и анимация
//  не может сломать layout.
//

import UIKit

@MainActor
final class FocusModeAnimator {

    private(set) var isActive = false

    private unowned let host: UIView
    private unowned let scrollView: UIScrollView
    private unowned let ring: UIView
    private weak var controls: UIView?
    private unowned let title: UILabel
    private let fading: [UIView]

    /// - Parameters:
    ///   - host: корневая вью экрана (система координат анимации)
    ///   - ring: контейнер кольца таймера (уезжает в центр)
    ///   - controls: ряд кнопок (уезжает вниз)
    ///   - title: заголовок фокуса над кольцом (появляется)
    ///   - fading: всё, что растворяется в режиме фокуса
    init(host: UIView, scrollView: UIScrollView, ring: UIView,
         controls: UIView?, title: UILabel, fading: [UIView]) {
        self.host = host
        self.scrollView = scrollView
        self.ring = ring
        self.controls = controls
        self.title = title
        self.fading = fading
    }

    func updateTitle(_ text: String) {
        title.text = text
    }

    func setActive(_ on: Bool, animated: Bool, title text: String?) {
        guard isActive != on else { return }
        isActive = on

        let apply = { [self] in
            if on {
                scrollView.setContentOffset(.zero, animated: false)
                host.layoutIfNeeded()

                // Кольцо — в видимый центр, чуть крупнее
                let ringFrame = ring.convert(ring.bounds, to: host)
                let ringDelta = host.bounds.midY - ringFrame.midY - 12
                ring.transform = CGAffineTransform(translationX: 0, y: ringDelta)
                    .scaledBy(x: 1.12, y: 1.12)

                // Кнопки — к нижнему краю
                if let controls {
                    let frame = controls.convert(controls.bounds, to: host)
                    let targetMidY = host.bounds.height - host.safeAreaInsets.bottom - 70
                    controls.transform = CGAffineTransform(
                        translationX: 0, y: targetMidY - frame.midY)
                }

                fading.forEach { $0.alpha = 0 }
                if let text { title.text = text }
                title.alpha = 1
            } else {
                ring.transform = .identity
                controls?.transform = .identity
                fading.forEach { $0.alpha = 1 }
                title.alpha = 0
            }
        }

        scrollView.isScrollEnabled = !on

        guard animated else { apply(); return }
        UIView.animate(withDuration: 0.65, delay: 0,
                       usingSpringWithDamping: 0.82,
                       initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction, .beginFromCurrentState],
                       animations: apply)
    }
}

