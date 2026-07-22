//
//  SplashOverlay.swift
//  Questly
//
//  Живое продолжение лаунч-скрина. Ложится поверх окна пиксель-в-
//  пиксель как статичный лаунч (тот же логотип, фон, подпись) —
//  переход незаметен. Затем лого делает «вдох» с хаптиком,
//  и оверлей растворяется, открывая уже готовое приложение.
//

import UIKit

final class SplashOverlay: UIView {

    // Цвета сняты с логотипа — те же, что в LaunchScreen.storyboard.
    private static let beige = UIColor(red: 0.996, green: 0.980, blue: 0.969, alpha: 1)
    private static let navy  = UIColor(red: 0.180, green: 0.227, blue: 0.314, alpha: 0.75)

    private let logoView = UIImageView(image: UIImage(named: "LaunchLogo"))
    private let caption = UILabel()

    static func show(in window: UIWindow) {
        let splash = SplashOverlay(frame: window.bounds)
        window.addSubview(splash)
        splash.run()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.beige
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoView)

        caption.text = "Каждый день — квест"
        caption.font = .systemFont(ofSize: 16)
        caption.textColor = Self.navy
        caption.textAlignment = .center
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)

        // Геометрия 1-в-1 со сторибордом лаунча: лого 260,
        // centerY -40, подпись через 10pt.
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            logoView.widthAnchor.constraint(equalToConstant: 260),
            logoView.heightAnchor.constraint(equalToConstant: 260),

            caption.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 10),
            caption.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Сценарий

    private func run() {
        // Будим Taptic-движок заранее — иначе первый хаптик на старте
        // приложения глотается (движок ещё спит).
        Haptics.warmUp()
        // Пауза 0.35с в статике (неотличимо от лаунча) → «вдох» лого
        // с хаптиком → короткая пауза → растворение с лёгким зумом.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.breathe()
        }
    }

    private func breathe() {
        Haptics.success()   // ощутимый «оживающий» толчок
        UIView.animate(withDuration: 0.18, animations: {
            self.logoView.transform = CGAffineTransform(scaleX: 1.07, y: 1.07)
        }, completion: { _ in
            UIView.animate(withDuration: 0.45, delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 4) {
                self.logoView.transform = .identity
            } completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.dissolve()
                }
            }
        })
    }

    private func dissolve() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn, animations: {
            self.alpha = 0
            // Лёгкий зум «сквозь» логотип — приложение будто
            // проявляется за ним.
            self.logoView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}

