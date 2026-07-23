//
//  ChallengeCardCell.swift
//  Questly
//
//  Карточка челленджа в списке: эмодзи в кружке, название,
//  описание и строка статуса.
//

import UIKit

final class ChallengeCardCell: PressableCardCell {

    static let reuseId = "ChallengeCardCell"

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = DQColor.challengeSoftAdaptive
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26)
        label.textAlignment = .center
        return label
    }()

    // Кружок-подложка под эмодзи — единый язык с сеткой ачивок.
    private let emojiCircle: UIView = {
        let v = UIView()
        v.backgroundColor = DQColor.card
        v.layer.cornerRadius = 25
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.required, for: .horizontal)
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(16, weight: .semibold)
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = DQColor.challengeDark
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        emojiCircle.addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [emojiCircle, textStack])
        row.axis = .horizontal
        row.spacing = 14
        // .top: заголовки всех карточек на одном уровне независимо
        // от длины описания (при .center они «гуляли» по вертикали).
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(row)
        pressableCard = card   // «жмяк» из PressableCardCell

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

            emojiCircle.widthAnchor.constraint(equalToConstant: 50),
            emojiCircle.heightAnchor.constraint(equalToConstant: 50),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiCircle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiCircle.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with challenge: Challenge) {
        emojiLabel.text = challenge.emoji
        titleLabel.text = challenge.title
        detailsLabel.text = challenge.details
        statusLabel.text = ChallengeStore.statusLine(for: challenge)
    }
}
