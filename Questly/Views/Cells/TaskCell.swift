//
//  TaskCell.swift
//  DayQuest
//
//  Ячейка задачи. Название и (опционально) срок «сегодня, 18:00»
//  собраны в вертикальный стек; просроченные сроки подсвечиваются.
//

import UIKit

protocol TaskCellDelegate: AnyObject {
    func taskCell(_ cell: TaskCell, didToggle task: TaskItem)
}

final class TaskCell: UITableViewCell {

    static let reuseId = "TaskCell"

    // MARK: - Делегат

    weak var delegate: TaskCellDelegate?

    // MARK: - Данные

    private var task: TaskItem?
    private var color: CategoryColor = .green

    // MARK: - UI элементы

    private let checkboxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    // Срок задачи: «сегодня, 18:00». Скрыт, если даты нет.
    private let dueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    // Вертикальный стек: название + срок. UIStackView сам убирает
    // место под dueLabel, когда тот скрыт, — не нужно жонглировать
    // констрейнтами для двух вариантов высоты ячейки.
    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameLabel, dueLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let pointsBadge: PaddedLabel = {
        let label = PaddedLabel()
        label.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Конфигурация

    func configure(with task: TaskItem, color: CategoryColor) {
        self.task = task
        self.color = color
        nameLabel.text = task.name
        pointsBadge.text = "+\(task.points)"
        checkboxButton.tintColor = color.main

        if let due = task.dueDate {
            dueLabel.isHidden = false
            let dueText = Self.dueText(start: due, end: task.endDate)
            // Заметка — в той же подстроке, через разделитель.
            dueLabel.text = task.note.isEmpty ? dueText : "\(dueText) · \(task.note)"
            // Просрочено и не выполнено — красным (по времени конца,
            // если оно есть: задача «идёт» до самого конца).
            let deadline = task.endDate ?? due
            dueLabel.textColor = (deadline < Date() && !task.isCompleted)
                ? .systemRed
                : .secondaryLabel
        } else if !task.note.isEmpty {
            // Даты нет, но есть заметка — показываем её.
            dueLabel.isHidden = false
            dueLabel.text = task.note
            dueLabel.textColor = .secondaryLabel
        } else {
            dueLabel.isHidden = true
        }

        updateAppearance(isCompleted: task.isCompleted)
    }

    // «сегодня, 15:00–16:30» / «завтра, 09:30» / «12 июля, 15:00 → 13 июля, 10:00»
    private static func dueText(start: Date, end: Date?) -> String {
        let calendar = Calendar.current
        let time = DateFormatter()
        time.locale = Locale(identifier: "ru_RU")
        time.dateFormat = "HH:mm"

        let startText: String
        if calendar.isDateInToday(start) {
            startText = "сегодня, \(time.string(from: start))"
        } else if calendar.isDateInTomorrow(start) {
            startText = "завтра, \(time.string(from: start))"
        } else {
            let full = DateFormatter()
            full.locale = Locale(identifier: "ru_RU")
            full.dateFormat = "d MMMM, HH:mm"
            startText = full.string(from: start)
        }

        guard let end else { return startText }

        if calendar.isDate(start, inSameDayAs: end) {
            // Тот же день — дописываем только время конца.
            return "\(startText)–\(time.string(from: end))"
        }
        let full = DateFormatter()
        full.locale = Locale(identifier: "ru_RU")
        full.dateFormat = "d MMMM, HH:mm"
        return "\(startText) → \(full.string(from: end))"
    }

    // MARK: - Приватные методы

    private func updateAppearance(isCompleted: Bool) {
        let name = task?.name ?? ""

        if isCompleted {
            nameLabel.attributedText = NSAttributedString(string: name, attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.tertiaryLabel
            ])
            checkboxButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            pointsBadge.backgroundColor = .systemFill
            pointsBadge.textColor = .tertiaryLabel
        } else {
            // Тонкость UIKit: если лейблу хоть раз присвоили attributedText,
            // обычное `text = ...` может унаследовать старые атрибуты —
            // поэтому всегда присваиваем attributedText и ЯВНО
            // выключаем зачёркивание нулём.
            nameLabel.attributedText = NSAttributedString(string: name, attributes: [
                .strikethroughStyle: 0,
                .foregroundColor: UIColor.label
            ])
            checkboxButton.setImage(UIImage(systemName: "circle"), for: .normal)
            pointsBadge.backgroundColor = color.background
            pointsBadge.textColor = color.main
        }
    }

    @objc private func checkboxTapped() {
        guard let task else { return }
        // Пружинный «поп» галочки: сжатие и упругий возврат —
        // отметка ощущается физически, не только визуально.
        UIView.animate(withDuration: 0.1, animations: {
            self.checkboxButton.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }, completion: { _ in
            UIView.animate(withDuration: 0.45, delay: 0,
                           usingSpringWithDamping: 0.4,
                           initialSpringVelocity: 8,
                           options: .allowUserInteraction) {
                self.checkboxButton.transform = .identity
            }
        })
        delegate?.taskCell(self, didToggle: task)
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(checkboxButton)
        contentView.addSubview(textStack)
        contentView.addSubview(pointsBadge)
    }

    private func setupConstraints() {
        // Пилюля держит размер, текстовая колонка растягивается.
        pointsBadge.setContentHuggingPriority(.required, for: .horizontal)
        pointsBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Минимальная высота ячейки — чтобы даже короткая задача
        // без срока выглядела полноценной плашкой, а не полоской.
        // Приоритет ниже required, чтобы не конфликтовать с растущим
        // содержимым (двухстрочное название + срок).
        let minHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        minHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            minHeight,

            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 26),
            checkboxButton.heightAnchor.constraint(equalToConstant: 26),

            pointsBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            pointsBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: pointsBadge.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }
}

