//
//  CategoryCells.swift
//  DayQuest
//
//  Две ячейки сетки на главном экране:
//  - CategoryTileCell — плитка категории;
//  - AddCategoryTileCell — плитка «+ Новая категория» с пунктирной рамкой.
//

import UIKit

// MARK: - CategoryTileCell

final class CategoryTileCell: UICollectionViewCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        // Сбрасываем состояние подсветки при переиспользовании.
        contentView.alpha = 1.0
    }

    // Отклик на нажатие — затемнение, как у системных ячеек.
    // Масштаб тут нельзя: layout коллекции сам двигает frame
    // contentView, а frame при активном transform не определён —
    // плитка «уезжала» в угол.
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.contentView.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }


    static let reuseId = "CategoryTileCell"

    // MARK: UI

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let pointsPill: PaddedLabel = {
        let label = PaddedLabel()
        label.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressTrack: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressFill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var fillWidth: NSLayoutConstraint?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        [iconContainer, pointsPill, nameLabel, subLabel, progressTrack].forEach {
            contentView.addSubview($0)
        }
        iconContainer.addSubview(iconView)
        progressTrack.addSubview(progressFill)

        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Конфигурация

    func configure(with category: Category) {
        let color = CategoryColor.named(category.colorName)

        iconContainer.backgroundColor = color.background
        iconView.image = UIImage(systemName: category.icon)
        iconView.tintColor = color.main

        pointsPill.text = "+\(category.earnedPoints)"
        pointsPill.backgroundColor = color.background
        pointsPill.textColor = color.main

        // Закреплённые помечаем булавкой-иконкой перед названием.
        if category.isPinned {
            nameLabel.attributedText = .withIcon(
                "pin.fill", text: category.name,
                font: nameLabel.font, color: nameLabel.textColor,
                iconColor: DQColor.accentAdaptive
            )
        } else {
            nameLabel.attributedText = nil
            nameLabel.text = category.name
        }
        let progress = "\(category.completedCount) из \(category.tasks.count) выполнено"
        subLabel.text = category.isDaily ? progress : progress + " · разовая"

        let total = category.totalPoints
        let fraction = total > 0 ? CGFloat(category.earnedPoints) / CGFloat(total) : 0
        progressFill.backgroundColor = color.main
        progressFill.isHidden = fraction == 0

        fillWidth?.isActive = false
        fillWidth = progressFill.widthAnchor.constraint(
            equalTo: progressTrack.widthAnchor, multiplier: max(0.001, fraction)
        )
        fillWidth?.isActive = true
    }

    // MARK: Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            pointsPill.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            pointsPill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            nameLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            subLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            subLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            progressTrack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            progressTrack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            progressTrack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            progressTrack.heightAnchor.constraint(equalToConstant: 5),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor)
        ])
    }
}

// MARK: - AddCategoryTileCell

final class AddCategoryTileCell: UICollectionViewCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        // Сбрасываем состояние подсветки при переиспользовании.
        contentView.alpha = 1.0
    }

    // Отклик на нажатие — затемнение, как у системных ячеек.
    // Масштаб тут нельзя: layout коллекции сам двигает frame
    // contentView, а frame при активном transform не определён —
    // плитка «уезжала» в угол.
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.contentView.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }


    static let reuseId = "AddCategoryTileCell"

    // Пунктирную рамку рисуем CAShapeLayer-ом:
    // обычный border у CALayer не умеет пунктир.
    private let dashLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.lineWidth = 1.5
        layer.lineDashPattern = [6, 4]  // 6pt штрих, 4pt пробел
        return layer
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "plus"))
        iv.tintColor = .secondaryLabel
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.text = "Новая категория"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.addSublayer(dashLayer)
        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Путь рамки зависит от размера ячейки, поэтому обновляем его здесь.
    // Заодно перечитываем цвет — CGColor не адаптируется к смене темы сам.
    override func layoutSubviews() {
        super.layoutSubviews()
        dashLayer.frame = contentView.bounds
        dashLayer.path = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        dashLayer.strokeColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }
}
