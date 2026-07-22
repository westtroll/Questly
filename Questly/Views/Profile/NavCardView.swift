//
//  NavCardView.swift
//  Questly
//
//  Карточка-вход: круглая иконка, заголовок, живой подзаголовок,
//  шеврон. На профиле таких было шесть почти одинаковых копий —
//  теперь одна переиспользуемая вью. Тап уходит колбэком onTap,
//  подзаголовок обновляется через setSubtitle().
//

import UIKit

final class NavCardView: UIView {

    var onTap: (() -> Void)?

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    /// - Parameters:
    ///   - symbol: SF Symbol для круглой иконки
    ///   - tint / soft: цвет иконки и её подложки (см. DQIcon.circle)
    ///   - title: заголовок карточки
    ///   - subtitle: стартовый подзаголовок (потом setSubtitle)
    init(symbol: String, tint: UIColor, soft: UIColor,
         title: String, subtitle: String = "") {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        translatesAutoresizingMaskIntoConstraints = false

        let icon = DQIcon.circle(symbol: symbol, tint: tint, soft: soft)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DQFont.rounded(15, weight: .semibold)

        subtitleLabel.text = subtitle

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // Подзаголовок прячется, если пустой — карточка выглядит цельной.
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])

        dqMakePressable()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSubtitle(_ text: String) {
        subtitleLabel.text = text
    }

    @objc private func tapped() {
        Haptics.light()
        onTap?()
    }
}

