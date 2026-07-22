//
//  AppBlockCardView.swift
//  Questly
//
//  Карточка «Блокировка приложений»: иконка, подпись состояния
//  и тумблер. Логика Screen Time остаётся в контроллере — карточка
//  только рисует и сообщает о действиях колбэками.
//

import UIKit

final class AppBlockCardView: UIView {

    var onToggle: ((Bool) -> Void)?
    var onTap: (() -> Void)?

    private let blockSwitch = UISwitch()

    private let subtitle: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: "shield.lefthalf.filled"))
        icon.tintColor = .systemRed
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = UILabel()
        title.text = "Блокировка приложений"
        title.font = .systemFont(ofSize: 15, weight: .medium)

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, textStack, blockSwitch])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        blockSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        // Тап по карточке (мимо тумблера) — выбор приложений.
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSwitch(on: Bool, animated: Bool) {
        blockSwitch.setOn(on, animated: animated)
    }

    func setSubtitle(_ text: String) {
        subtitle.text = text
    }

    @objc private func switchChanged() {
        onToggle?(blockSwitch.isOn)
    }

    @objc private func cardTapped() {
        onTap?()
    }
}

