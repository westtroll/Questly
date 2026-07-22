//
//  GoodHabitsUI.swift
//  DayQuest
//
//  UI сегмента «Внедряю»: карточка полезной привычки
//  (стрик, полоска недели, кнопка отметки) и форма создания.
//

import UIKit
import Combine
import SwiftData

// MARK: - Ячейка полезной привычки

protocol GoodHabitCellDelegate: AnyObject {
    func goodHabitCell(_ cell: GoodHabitCell, didToggleToday habit: GoodHabit)
}

final class GoodHabitCell: UITableViewCell {

    static let reuseId = "GoodHabitCell"

    weak var delegate: GoodHabitCellDelegate?
    private var habit: GoodHabit?

    private let card: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        return label
    }()

    private let streakLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    // Семь кружков последних дней
    private var dayDots: [UILabel] = []
    private let weekStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        return stack
    }()

    // Большая кнопка «отметить сегодня»
    private let checkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 34, weight: .regular),
            forImageIn: .normal
        )
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        // Кружки недели: маленькие лейблы-«точки» с буквой дня.
        for _ in 0..<7 {
            let dot = UILabel()
            dot.font = .systemFont(ofSize: 10, weight: .semibold)
            dot.textAlignment = .center
            dot.layer.cornerRadius = 11
            dot.layer.masksToBounds = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 22).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 22).isActive = true
            dayDots.append(dot)
            weekStack.addArrangedSubview(dot)
        }

        let textStack = UIStackView(arrangedSubviews: [nameLabel, streakLabel, weekStack])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        // Без жмяка: тап по карточке открывает редактирование
        // (didSelectRowAt), а жест-жмяк перехватывал бы касание.
        card.addSubview(textStack)
        card.addSubview(checkButton)

        checkButton.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: checkButton.leadingAnchor, constant: -8),

            checkButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            checkButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            checkButton.widthAnchor.constraint(equalToConstant: 44),
            checkButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» на прикосновение через подсветку ячейки: не глушит
    // выбор строки (didSelectRowAt открывает редактирование),
    // в отличие от тап-жеста на карточке.
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            UIView.animate(withDuration: 0.12,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = CGAffineTransform(scaleX: 0.965, y: 0.965)
            }
        } else {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.4,
                           initialSpringVelocity: 6,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = .identity
            }
        }
    }

    func configure(with habit: GoodHabit) {
        self.habit = habit
        let color = CategoryColor.named(habit.colorName)

        card.backgroundColor = color.background
        nameLabel.text = habit.name
        checkButton.tintColor = color.main

        let streak = habit.currentStreak
        if streak > 0 {
            streakLabel.attributedText = .withIcon(
                "flame.fill", text: "\(streak.daysString) подряд",
                font: .systemFont(ofSize: 13), color: .secondaryLabel,
                iconColor: .systemOrange
            )
        } else {
            streakLabel.attributedText = nil
            streakLabel.text = "Начни серию сегодня"
        }

        checkButton.setImage(
            UIImage(systemName: habit.isCheckedToday ? "checkmark.circle.fill" : "circle"),
            for: .normal
        )

        // Полоска недели
        for (dot, day) in zip(dayDots, habit.weekStrip()) {
            dot.text = day.letter
            if day.checked {
                dot.backgroundColor = color.main
                dot.textColor = .white
            } else {
                dot.backgroundColor = UIColor.systemFill
                dot.textColor = .secondaryLabel
            }
            // Сегодняшний день обведён
            dot.layer.borderWidth = day.isToday ? 1.5 : 0
            dot.layer.borderColor = color.main.resolvedColor(with: traitCollection).cgColor
        }
    }

    @objc private func checkTapped() {
        guard let habit else { return }
        delegate?.goodHabitCell(self, didToggleToday: habit)
    }
}

// MARK: - Форма полезной привычки

final class GoodHabitFormViewController: UIViewController {

    private let habitToEdit: GoodHabit?
    private var isEditMode: Bool { habitToEdit != nil }

    private var selectedColor: CategoryColor
    private var colorButtons: [UIButton] = []

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Например: Читать 20 минут"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let nameCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = isEditMode ? "Сохранить" : "Начать внедрять"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(habitToEdit: GoodHabit? = nil) {
        self.habitToEdit = habitToEdit
        self.selectedColor = habitToEdit.map { CategoryColor.named($0.colorName) } ?? .green
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isEditMode ? "Изменить привычку" : "Новая привычка"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel

        nameField.delegate = self
        nameField.text = habitToEdit?.name

        setupLayout()
        setupBindings()
        refreshSelection()

        // Тап по фону скрывает клавиатуру. cancelsTouchesInView = false —
        // чтобы жест не «съедал» тапы по цветным кнопкам.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isEditMode {
            nameField.becomeFirstResponder()
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        nameCard.addSubview(nameField)

        let colorTitle = UILabel()
        colorTitle.text = "Стиль"
        colorTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        colorTitle.textColor = .secondaryLabel

        let hint = UILabel()
        hint.text = "Отмечай привычку каждый день — и наблюдай, как растёт серия 🔥"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabel
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [nameCard, colorTitle, makeColorRow(), hint])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: nameCard)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: nameCard.topAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: nameCard.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: nameCard.trailingAnchor, constant: -16),
            nameField.bottomAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: -14),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makeColorRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually

        for (index, color) in CategoryColor.allCases.enumerated() {
            let button = UIButton(type: .custom)
            button.backgroundColor = color.main
            button.layer.cornerRadius = 17
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorButtons.append(button)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func setupBindings() {
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: nameField)
            .map { ($0.object as? UITextField)?.text ?? "" }
            .prepend(nameField.text ?? "")
            .map { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.saveButton.isEnabled = isValid
                UIView.animate(withDuration: 0.2) {
                    self?.saveButton.alpha = isValid ? 1.0 : 0.5
                }
            }
            .store(in: &cancellables)

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }

    private func refreshSelection() {
        for (index, button) in colorButtons.enumerated() {
            let isSelected = CategoryColor.allCases[index] == selectedColor
            button.layer.borderWidth = isSelected ? 3 : 0
            button.layer.borderColor = UIColor.label.withAlphaComponent(0.7)
                .resolvedColor(with: traitCollection).cgColor
        }
        var config = saveButton.configuration
        config?.baseBackgroundColor = selectedColor.main
        saveButton.configuration = config
    }

    // MARK: - Actions

    @objc private func colorTapped(_ sender: UIButton) {
        selectedColor = CategoryColor.allCases[sender.tag]
        Haptics.light()
        refreshSelection()
    }

    @objc private func saveTapped() {
        guard let name = nameField.text?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty else { return }

        if let habit = habitToEdit {
            habit.name = name
            habit.colorName = selectedColor.rawValue
        } else {
            let habit = GoodHabit(name: name, colorName: selectedColor.rawValue)
            DataStore.shared.context.insert(habit)
        }
        DataStore.shared.save()
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension GoodHabitFormViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

