//
//  CategoryHeaderView.swift
//  DayQuest
//

import UIKit

// UITableViewHeaderFooterView — специальный класс для заголовков секций.
// Используем его вместо обычного UIView потому что UITableView
// умеет переиспользовать их так же как и ячейки — через dequeueReusableHeaderFooterView.
final class CategoryHeaderView: UITableViewHeaderFooterView {

    static let reuseId = "CategoryHeaderView"

    // MARK: - UI элементы

    // Круглый фон для иконки
    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.88, green: 0.97, blue: 0.93, alpha: 1) // светло-зелёный
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // SF Symbol иконка категории
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Название категории: "Здоровье"
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Прогресс категории: "+35 / 55 xp"
    private let xpLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Публичный метод настройки

    func configure(with category: Category) {
        // UIImage(systemName:) берёт иконку из SF Symbols по имени.
        // Отображаем через UIImageView было бы правильнее,
        // но для простоты используем эмодзи-лейбл через конфигурацию.
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = UIImage(systemName: category.icon, withConfiguration: config) {
            // Рисуем иконку как NSTextAttachment внутри лейбла
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(
                UIColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1),
                renderingMode: .alwaysOriginal
            )
            iconLabel.attributedText = NSAttributedString(attachment: attachment)
        }

        // Название в верхнем регистре — как в мокапе
        nameLabel.text = category.name.uppercased()

        // XP: показываем заработанные и доступные очки
        let earned = category.earnedPoints
        let total  = category.totalPoints
        xpLabel.text = "+\(earned) / \(total) xp"

        // Если все задачи выполнены — делаем xpLabel серым
        xpLabel.textColor = earned == total && total > 0
            ? .secondaryLabel
            : UIColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1)
    }

    // MARK: - Setup

    private func setupViews() {
        // contentView — стандартное свойство UITableViewHeaderFooterView,
        // добавляем сабвью именно в него, а не в self.
        contentView.backgroundColor = .systemBackground

        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(xpLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Контейнер иконки — квадрат 32х32, по левому краю по центру
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),

            // Иконка — по центру контейнера
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            // Название — справа от иконки
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // XP — по правому краю
            xpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            xpLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            xpLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),

            // Высота заголовка секции
            contentView.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
}

