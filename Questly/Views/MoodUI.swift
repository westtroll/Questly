//
//  MoodUI.swift
//  DayQuest
//
//  Эмоциональный дневник: карточка чек-ина для экрана «Сегодня»,
//  шторка выбора настроения с заметкой и экран истории с трендом.
//

import UIKit

// MARK: - Карточка чек-ина (встраивается в «Сегодня»)

final class MoodCheckInView: UIView {

    /// Тап по эмодзи — открыть шторку с этим стартовым значением.
    var onPick: ((Int) -> Void)?
    /// Тап по «истории».
    var onHistory: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let historyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chart.xyaxis.line"), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let emojiRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var emojiButtons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        translatesAutoresizingMaskIntoConstraints = false

        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)

        for value in 1...5 {
            let button = UIButton(type: .system)
            button.setTitle(MoodScale.emoji(for: value), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 30)
            button.tag = value
            button.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
            emojiButtons.append(button)
            emojiRow.addArrangedSubview(button)
        }

        addSubview(titleLabel)
        addSubview(historyButton)
        addSubview(emojiRow)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            historyButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            historyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            emojiRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            emojiRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            emojiRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            emojiRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Обновить вид под сегодняшнюю отметку (или её отсутствие).
    func refresh(todayMood: MoodEntry?) {
        if let mood = todayMood {
            titleLabel.text = "Сегодня: \(MoodScale.emoji(for: mood.value)) \(MoodScale.label(for: mood.value))"
        } else {
            titleLabel.text = "Как ты себя чувствуешь?"
        }
        // Подсветим выбранный эмодзи.
        for button in emojiButtons {
            button.alpha = (todayMood?.value == button.tag) ? 1.0 : (todayMood == nil ? 1.0 : 0.4)
        }
    }

    @objc private func emojiTapped(_ sender: UIButton) {
        Haptics.light()
        onPick?(sender.tag)
    }

    @objc private func historyTapped() {
        onHistory?()
    }
}

// MARK: - Шторка выбора настроения

final class MoodPickerViewController: UIViewController {

    private var selectedValue: Int
    var onSave: (() -> Void)?

    private var emojiButtons: [UIButton] = []

    private let promptLabel: UILabel = {
        let label = UILabel()
        label.text = "Как ты себя чувствуешь?"
        label.font = DQFont.rounded(20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emojiRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let noteField: UITextField = {
        let field = UITextField()
        field.placeholder = "Заметка (необязательно)"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.backgroundColor = .secondarySystemGroupedBackground
        field.layer.cornerRadius = 12
        field.translatesAutoresizingMaskIntoConstraints = false
        // Отступы внутри поля
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        return field
    }()

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Сохранить"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = DQColor.accent
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    init(startValue: Int) {
        self.selectedValue = min(max(startValue, 1), 5)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        // Подставим существующую сегодняшнюю заметку, если есть.
        if let today = DataStore.shared.moodEntry(on: Date()) {
            noteField.text = today.note
        }

        for value in 1...5 {
            let button = UIButton(type: .system)
            button.setTitle(MoodScale.emoji(for: value), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 40)
            button.tag = value
            button.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
            emojiButtons.append(button)
            emojiRow.addArrangedSubview(button)
        }

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        setupLayout()
        refreshSelection()
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [promptLabel, valueLabel, emojiRow, noteField])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(20, after: emojiRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            noteField.heightAnchor.constraint(equalToConstant: 48),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func refreshSelection() {
        valueLabel.text = MoodScale.label(for: selectedValue)
        for button in emojiButtons {
            let isSelected = button.tag == selectedValue
            button.alpha = isSelected ? 1.0 : 0.35
            button.transform = isSelected
                ? CGAffineTransform(scaleX: 1.25, y: 1.25)
                : .identity
        }
    }

    @objc private func emojiTapped(_ sender: UIButton) {
        selectedValue = sender.tag
        Haptics.light()
        UIView.animate(withDuration: 0.15) { self.refreshSelection() }
    }

    @objc private func saveTapped() {
        DataStore.shared.setMoodToday(
            value: selectedValue,
            note: noteField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        )
        Haptics.success()
        onSave?()
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - История настроений

final class MoodHistoryViewController: UIViewController {

    private var entries: [MoodEntry] = []

    private let averageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Дневник настроения"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(averageLabel)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            averageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            averageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            averageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: averageLabel.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self

        reload()
    }

    private func reload() {
        entries = DataStore.shared.allMoodEntries()

        if let avg = DataStore.shared.averageMood(lastDays: 30) {
            let rounded = Int(avg.rounded())
            averageLabel.text = "Среднее за 30 дней: \(MoodScale.emoji(for: rounded)) "
                + String(format: "%.1f из 5 · %@", avg, MoodScale.label(for: rounded))
        } else {
            averageLabel.text = "Отмечай настроение каждый день — здесь появится тренд"
        }
        tableView.reloadData()
    }
}

extension MoodHistoryViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = entries[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"

        var config = cell.defaultContentConfiguration()
        config.text = "\(MoodScale.emoji(for: entry.value))  \(formatter.string(from: entry.date).capitalizedFirst)"
        config.textProperties.font = .systemFont(ofSize: 15)
        config.secondaryText = entry.note.isEmpty ? MoodScale.label(for: entry.value) : entry.note
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }
}

