//
//  ChallengeTaskCell.swift
//  Questly
//
//  Задача внутри дня челленджа. Три состояния: выполнена
//  (залитая индиго-карточка), доступна, заблокирована.
//

import UIKit

final class ChallengeTaskCell: PressableCardCell {

    static let reuseId = "ChallengeTaskCell"

    override var pressScale: CGFloat { 0.97 }

    enum State {
        case locked    // будущий день или челлендж не начат
        case pending   // можно выполнять
        case done      // выполнено
    }

    private let card: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }()

    private let checkmark: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.tintColor = .white
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [emojiLabel, textStack, checkmark])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(row)
        pressableCard = card

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(task: ChallengeTask, state: State) {
        emojiLabel.text = task.emoji
        titleLabel.text = task.title
        subtitleLabel.text = task.subtitle

        switch state {
        case .done:
            // Выполненная задача — залитая индиго-карточка.
            card.backgroundColor = DQColor.challenge
            titleLabel.textColor = .white
            subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
            checkmark.isHidden = false
            contentView.alpha = 1
        case .pending:
            card.backgroundColor = .secondarySystemGroupedBackground
            titleLabel.textColor = .label
            subtitleLabel.textColor = .secondaryLabel
            checkmark.isHidden = true
            contentView.alpha = 1
        case .locked:
            card.backgroundColor = .secondarySystemGroupedBackground
            titleLabel.textColor = .label
            subtitleLabel.textColor = .secondaryLabel
            checkmark.isHidden = true
            contentView.alpha = 0.45
        }
    }
}

