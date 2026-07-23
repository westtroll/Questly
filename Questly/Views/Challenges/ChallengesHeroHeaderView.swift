//
//  ChallengeHeroHeaderView.swift
//  Questly
//
//  Индиго-шапка детального экрана челленджа: название, обещание
//  награды и ряд чипсов Пн–Вс. Тап по чипсу отдаётся колбэком
//  onSelectDay — экран проскроллит таблицу к нужной секции.
//
//  Используется как tableHeaderView, поэтому имеет явный frame
//  и не полагается на автолейаут снаружи.
//

import UIKit

final class ChallengeHeroHeaderView: UIView {

    /// Тап по чипсу дня (0 = понедельник)
    var onSelectDay: ((Int) -> Void)?

    private static let dayTitles = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var dayChips: [UILabel] = []

    init(challenge: Challenge, width: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 210))

        // Фон — отдельный слой со скруглением, чтобы шапка мягко
        // «стекала» в список, а не обрывалась прямоугольником.
        let bg = UIView()
        bg.backgroundColor = DQColor.challenge
        bg.layer.cornerRadius = 28
        bg.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        bg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bg)

        let titleLabel = UILabel()
        titleLabel.text = "Челлендж «\(challenge.title)» \(challenge.emoji)"
        titleLabel.font = DQFont.rounded(24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Обещание награды — мотивация прямо в шапке.
        let rewardLabel = UILabel()
        rewardLabel.text = "Пройди до конца — получи +\(Challenge.rewardXP) XP к уровню ⚡️"
        rewardLabel.font = .systemFont(ofSize: 13, weight: .medium)
        rewardLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        rewardLabel.numberOfLines = 0
        rewardLabel.translatesAutoresizingMaskIntoConstraints = false

        // Чипсы дней — кастомные лейблы, а не UIButton: у Configuration
        // свои внутренние паддинги, из-за которых 7 капсул в ряд ужимали
        // текст. Лейбл с фиксированной высотой даёт чистый контроль.
        let chipsStack = UIStackView()
        chipsStack.axis = .horizontal
        chipsStack.spacing = 6
        chipsStack.distribution = .fillEqually
        chipsStack.translatesAutoresizingMaskIntoConstraints = false

        for (index, day) in Self.dayTitles.enumerated() {
            let chip = UILabel()
            chip.text = day
            chip.font = .systemFont(ofSize: 13, weight: .semibold)
            chip.textAlignment = .center
            chip.textColor = .white
            chip.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            chip.layer.cornerRadius = 16
            chip.layer.masksToBounds = true
            chip.isUserInteractionEnabled = true
            chip.tag = index
            chip.heightAnchor.constraint(equalToConstant: 32).isActive = true
            chip.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(chipTapped(_:)))
            )
            dayChips.append(chip)
            chipsStack.addArrangedSubview(chip)
        }

        [titleLabel, rewardLabel, chipsStack].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            // Фон-карточка с отступами: видны все четыре скругления.
            bg.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: bg.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),

            rewardLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            rewardLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            rewardLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),

            chipsStack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -16),
            chipsStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Подсветить чипс текущего дня челленджа (nil — челлендж не начат)
    func highlightToday(_ index: Int?) {
        for (i, chip) in dayChips.enumerated() {
            let isToday = i == index
            chip.backgroundColor = isToday ? .white : UIColor.white.withAlphaComponent(0.18)
            chip.textColor = isToday ? DQColor.challengeDark : .white
        }
    }

    @objc private func chipTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        onSelectDay?(index)
    }
}

