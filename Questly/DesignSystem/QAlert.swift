//
//  DQAlert.swift
//  Questly
//
//  Кастомный алерт в фирменном стиле: карточка со скруглением,
//  иконка в бирюзовом кружке, наши кнопки. Заменяет системные
//  UIAlertController в праздничных и мотивационных моментах.
//  Деструктивные подтверждения («Удалить?») остаются системными —
//  там уместна строгая казённость.
//

import UIKit

final class DQAlert: UIViewController {

    // MARK: - Конфиг кнопки

    struct Action {
        enum Style { case primary, plain, destructive }
        let title: String
        let style: Style
        let handler: (() -> Void)?

        init(_ title: String, style: Style = .plain, handler: (() -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }

    // MARK: - Данные

    private let iconName: String       // SF Symbol
    private let iconTint: UIColor
    private let titleText: String
    private let messageText: String
    private let actions: [Action]

    // MARK: - Вьюхи

    private let dimView = UIView()
    private let cardView = UIView()

    // MARK: - Init

    init(icon: String,
         iconTint: UIColor = DQColor.accentAdaptive,
         title: String,
         message: String,
         actions: [Action]) {
        self.iconName = icon
        self.iconTint = iconTint
        self.titleText = title
        self.messageText = message
        self.actions = actions.isEmpty ? [Action("OK", style: .primary)] : actions
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        // Никакого системного перехода — всю анимацию делаем руками,
        // иначе crossDissolve дерётся с нашей пружиной («мигание»).
        modalTransitionStyle = .coverVertical
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDim()
        setupCard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Стартовое состояние задаём ДО показа экрана — иначе будет
        // виден «кадр» полностью показанного алерта перед анимацией.
        dimView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        cardView.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Плавно проявляем затемнение и пружиним карточку.
        UIView.animate(withDuration: 0.2) {
            self.dimView.alpha = 1
        }
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
        }
    }

    // MARK: - Setup

    private func setupDim() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimView.frame = view.bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(dimView)
    }

    private func setupCard() {
        cardView.backgroundColor = DQColor.card
        cardView.layer.cornerRadius = 22
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // Иконка в кружке
        let iconCircle = UIView()
        iconCircle.backgroundColor = iconTint.withAlphaComponent(0.15)
        iconCircle.layer.cornerRadius = 32
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(
            image: UIImage(systemName: iconName)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold))
        )
        iconView.tintColor = iconTint
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = DQFont.rounded(18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Кнопки
        let buttonsStack = UIStackView()
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 8
        for action in actions {
            buttonsStack.addArrangedSubview(makeButton(for: action))
        }

        let stack = UIStackView(arrangedSubviews: [iconCircle, titleLabel, messageLabel, buttonsStack])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.setCustomSpacing(14, after: iconCircle)
        stack.setCustomSpacing(6, after: titleLabel)
        stack.setCustomSpacing(20, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),

            // Иконка-кружок 64pt, отцентрована в своём ряду
            iconCircle.heightAnchor.constraint(equalToConstant: 64),
            iconCircle.widthAnchor.constraint(equalToConstant: 64),
            iconCircle.centerXAnchor.constraint(equalTo: stack.centerXAnchor),

            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor)
        ])
    }

    private func makeButton(for action: Action) -> UIButton {
        var config: UIButton.Configuration
        switch action.style {
        case .primary:
            config = .filled()
            config.baseBackgroundColor = DQColor.accent
            config.baseForegroundColor = .white
        case .plain:
            config = .filled()
            config.baseBackgroundColor = DQColor.accentSoftAdaptive
            config.baseForegroundColor = DQColor.accentDark
        case .destructive:
            config = .filled()
            config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
            config.baseForegroundColor = .systemRed
        }
        config.cornerStyle = .large
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = DQFont.rounded(16, weight: .semibold)
            return attrs
        }
        config.title = action.title

        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in
            self?.animateOut { action.handler?() }
        }, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    /// Плавное закрытие: гасим карточку и затемнение, потом dismiss
    /// без системной анимации — единый визуальный язык вход/выход.
    private func animateOut(then completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.2, animations: {
            self.cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.cardView.alpha = 0
            self.dimView.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false) { completion?() }
        })
    }

    // MARK: - Удобный показ

    /// Показать алерт с любого видимого контроллера.
    static func present(from presenter: UIViewController,
                        icon: String,
                        iconTint: UIColor = DQColor.accentAdaptive,
                        title: String,
                        message: String,
                        actions: [Action]) {
        // Защита от двойного показа: viewDidAppear может сработать
        // несколько раз, а презентовать алерт поверх уже открытого
        // нельзя — iOS проигнорирует второй показ или устроит «мигание».
        guard presenter.presentedViewController == nil else { return }

        let alert = DQAlert(icon: icon, iconTint: iconTint,
                            title: title, message: message, actions: actions)
        // animated: false — системный переход выключен, всю анимацию
        // (затемнение + пружина карточки) DQAlert проигрывает сам.
        presenter.present(alert, animated: false)
    }
}

