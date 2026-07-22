//
//  LevelCardView.swift
//  Questly
//
//  Карточка уровня: бейдж с номером, название уровня, полоса
//  прогресса до следующего и подпись с очками. Тап — система
//  уровней (колбэк onTap).
//

import UIKit

final class LevelCardView: UIView {

    var onTap: (() -> Void)?

    private let badge: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = DQColor.accent
        label.layer.cornerRadius = 26
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let track: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fill: UIView = {
        let view = UIView()
        view.backgroundColor = DQColor.accent
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let caption: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var fillWidth: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = DQColor.accentSoftAdaptive
        layer.cornerRadius = 20
        translatesAutoresizingMaskIntoConstraints = false

        [badge, titleLabel, track, caption].forEach { addSubview($0) }
        track.addSubview(fill)

        dqMakePressable()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            badge.widthAnchor.constraint(equalToConstant: 52),
            badge.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            track.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            track.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 14),
            track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            track.heightAnchor.constraint(equalToConstant: 8),

            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),

            caption.topAnchor.constraint(equalTo: track.bottomAnchor, constant: 8),
            caption.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 14),
            caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh(with level: UserLevel) {
        badge.text = "\(level.level)"
        titleLabel.text = "Уровень \(level.level) · \(level.title)"
        caption.text = "\(level.pointsIntoLevel) / \(level.pointsForLevel) очков · до следующего: \(level.pointsToNext)"

        fillWidth?.isActive = false
        fillWidth = fill.widthAnchor.constraint(
            equalTo: track.widthAnchor,
            multiplier: max(0.001, CGFloat(level.progress))
        )
        fillWidth?.isActive = true
        fill.isHidden = level.pointsIntoLevel == 0
    }

    @objc private func tapped() {
        Haptics.light()
        onTap?()
    }
}

