//
//  HistoryDayCell.swift
//  Questly
//
//  Ячейка одного дня в календаре истории. Цвет насыщается с баллом
//  (как сетка контрибуций GitHub), сегодняшний день обведён рамкой.
//

import UIKit

final class HistoryDayCell: UICollectionViewCell {

    static let reuseId = "HistoryDayCell"

    // Вся отрисовка — на внутреннем tile: его можно безопасно
    // «жмякать» трансформацией. contentView трогать нельзя —
    // layout коллекции владеет его геометрией.
    private let tile: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(tile)
        tile.addSubview(label)
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor),
            tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            label.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» дня при нажатии: прожимается tile, не contentView.
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1,
                               delay: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                }
            } else {
                UIView.animate(withDuration: 0.35,
                               delay: 0,
                               usingSpringWithDamping: 0.5,
                               initialSpringVelocity: 5,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = .identity
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tile.transform = .identity
    }

    func configure(day: Int, score: Int?, isToday: Bool, isFuture: Bool = false) {
        label.text = "\(day)"

        if let score, score > 0 {
            // Чем выше балл — тем насыщеннее цвет.
            let color = DayScore(value: score).color
            tile.backgroundColor = color.withAlphaComponent(0.2 + 0.5 * CGFloat(score) / 100)
            label.textColor = .label
        } else {
            tile.backgroundColor = .secondarySystemGroupedBackground
            label.textColor = isFuture ? .quaternaryLabel : .secondaryLabel
        }

        // Сегодняшний день обводим рамкой.
        tile.layer.borderWidth = isToday ? 1.5 : 0
        tile.layer.borderColor = UIColor.label
            .resolvedColor(with: traitCollection).cgColor
    }

    func configureEmpty() {
        label.text = ""
        tile.backgroundColor = .clear
        tile.layer.borderWidth = 0
    }
}

