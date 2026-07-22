//
//  AddTaskViewController.swift
//  Questly
//
//  Экран создания/редактирования задачи. Новое: опциональные дата
//  и время (тумблер раскрывает пикер) и предложение добавить
//  задачу в Календарь Apple после сохранения.
//

import UIKit
import Combine

final class AddTaskViewController: UIViewController {

    // MARK: - Свойства

    private let category: Category
    private weak var viewModel: TodayViewModel?

    // Режим экрана: nil — создаём новую задачу,
    // не nil — редактируем существующую. Один экран, два режима.
    private let taskToEdit: TaskItem?

    private var isEditMode: Bool { taskToEdit != nil }

    // MARK: - UI элементы

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Название задачи"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.returnKeyType = .next
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let pointsField: UITextField = {
        let field = UITextField()
        field.placeholder = "Очки за выполнение"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.keyboardType = .numberPad
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let noteField: UITextField = {
        let field = UITextField()
        field.placeholder = "Заметка (необязательно)"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let nameCard = AddTaskViewController.makeCard()
    private let pointsCard = AddTaskViewController.makeCard()
    private let noteCard = AddTaskViewController.makeCard()
    private let dateCard = AddTaskViewController.makeCard()

    private let pointsHint: UILabel = {
        let label = UILabel()
        label.text = "Рекомендуем: лёгкое = 5–10, среднее = 15–20, сложное = 25+"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Тумблер «Дата и время»
    private let dateSwitch = UISwitch()

    // Компактный пикер даты и времени — раскрывается тумблером
    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "ru_RU")
        picker.minuteInterval = 5
        return picker
    }()

    // Пикер конца задачи
    private let endPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "ru_RU")
        picker.minuteInterval = 5
        return picker
    }()

    // Ряды «Начало» и «Конец» — прячем/показываем вместе с тумблером.
    private var pickerRows: [UIView] = []

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = isEditMode ? "Сохранить" : "Добавить задачу"
        config.cornerStyle = .large
        config.baseBackgroundColor = CategoryColor.named(category.colorName).main
        config.baseForegroundColor = .white
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameCard, pointsCard, pointsHint, noteCard, dateCard])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var saveButtonBottom: NSLayoutConstraint!

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(category: Category, viewModel: TodayViewModel, taskToEdit: TaskItem? = nil) {
        self.category = category
        self.viewModel = viewModel
        self.taskToEdit = taskToEdit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupViews()
        setupConstraints()

        // ВАЖНО: поля заполняем ДО setupBindings — publisher-ы стартуют
        // с текущих значений полей через .prepend (см. setupBindings).
        if let task = taskToEdit {
            nameField.text = task.name
            pointsField.text = "\(task.points)"
            noteField.text = task.note
            if let due = task.dueDate {
                dateSwitch.isOn = true
                datePicker.date = due
                // У старых задач конца может не быть — подставляем +час.
                endPicker.date = task.endDate ?? due.addingTimeInterval(3600)
                endPicker.minimumDate = due
                pickerRows.forEach { $0.isHidden = false }
            }
        }

        setupBindings()
        setupKeyboardHandling()

        nameField.delegate = self
        pointsField.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isEditMode {
            nameField.becomeFirstResponder()
        }
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = isEditMode ? "Изменить задачу" : "Новая задача"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel
    }

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground

        nameCard.addSubview(nameField)
        pointsCard.addSubview(pointsField)
        noteCard.addSubview(noteField)

        // Карточка даты: тумблер, под ним ряды «Начало» и «Конец».
        let dateTitle = UILabel()
        dateTitle.text = "Дата и время"
        dateTitle.font = .systemFont(ofSize: 16)

        let toggleRow = UIStackView(arrangedSubviews: [dateTitle, dateSwitch])
        toggleRow.axis = .horizontal
        toggleRow.alignment = .center

        let startRow = makeDateRow(title: "Начало", picker: datePicker)
        let endRow = makeDateRow(title: "Конец", picker: endPicker)
        pickerRows = [startRow, endRow]
        pickerRows.forEach { $0.isHidden = true }   // по умолчанию скрыты

        let dateStack = UIStackView(arrangedSubviews: [toggleRow, startRow, endRow])
        dateStack.axis = .vertical
        dateStack.spacing = 10
        dateStack.alignment = .fill
        dateStack.translatesAutoresizingMaskIntoConstraints = false

        dateCard.addSubview(dateStack)
        NSLayoutConstraint.activate([
            dateStack.topAnchor.constraint(equalTo: dateCard.topAnchor, constant: 12),
            dateStack.leadingAnchor.constraint(equalTo: dateCard.leadingAnchor, constant: 16),
            dateStack.trailingAnchor.constraint(equalTo: dateCard.trailingAnchor, constant: -16),
            dateStack.bottomAnchor.constraint(equalTo: dateCard.bottomAnchor, constant: -12)
        ])

        dateSwitch.addTarget(self, action: #selector(dateSwitchChanged), for: .valueChanged)
        // Следим за началом: конец не может быть раньше него.
        datePicker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)

        view.addSubview(stackView)
        view.addSubview(saveButton)

        saveButton.isEnabled = false
        saveButton.alpha = 0.5
    }

    private func setupConstraints() {
        [nameField, pointsField, noteField].forEach { field in
            let card = field.superview!
            NSLayoutConstraint.activate([
                field.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
                field.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                field.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                field.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
            ])
        }

        saveButtonBottom = saveButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -16
        )

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButtonBottom
        ])
    }

    // MARK: - Combine Bindings

    private func setupBindings() {
        // .prepend — publisher сразу выдаёт стартовое значение поля.
        // Без него в режиме редактирования кнопка была бы неактивна,
        // пока пользователь не потрогает поля.
        let namePublisher = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: nameField)
            .map { ($0.object as? UITextField)?.text ?? "" }
            .prepend(nameField.text ?? "")

        let pointsPublisher = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: pointsField)
            .map { ($0.object as? UITextField)?.text ?? "" }
            .prepend(pointsField.text ?? "")

        Publishers.CombineLatest(namePublisher, pointsPublisher)
            .map { name, points in
                !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                (Int(points) ?? 0) > 0
            }
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

    // MARK: - Клавиатура

    private func setupKeyboardHandling() {
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                else { return }

                self.saveButtonBottom.constant = -keyboardFrame.height - 12 + self.view.safeAreaInsets.bottom
                UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                else { return }

                self.saveButtonBottom.constant = -16
                UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    // Ряд «Название — пикер» для карточки даты
    private func makeDateRow(title: String, picker: UIDatePicker) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [label, picker])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    @objc private func dateSwitchChanged() {
        if dateSwitch.isOn {
            view.endEditing(true)
            // Разумные значения по умолчанию: конец = начало + час.
            endPicker.date = datePicker.date.addingTimeInterval(3600)
            endPicker.minimumDate = datePicker.date
        }
        // Прячем/показываем ряды внутри stack view — он сам
        // анимирует изменение высоты.
        UIView.animate(withDuration: 0.25) {
            self.pickerRows.forEach { $0.isHidden = !self.dateSwitch.isOn }
            self.view.layoutIfNeeded()
        }
    }

    @objc private func startDateChanged() {
        // Конец не может быть раньше начала: двигаем минимум,
        // а если конец «отстал» — тянем его на час вперёд от начала.
        endPicker.minimumDate = datePicker.date
        if endPicker.date < datePicker.date {
            endPicker.date = datePicker.date.addingTimeInterval(3600)
        }
    }

    @objc private func saveTapped() {
        guard
            let name = nameField.text?.trimmingCharacters(in: .whitespaces),
            let pointsText = pointsField.text,
            let points = Int(pointsText),
            !name.isEmpty, points > 0
        else { return }

        let note = noteField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let dueDate = dateSwitch.isOn ? datePicker.date : nil
        // Подстраховка: конец строго после начала (минимум 5 минут).
        let endDate = dueDate.map { max(endPicker.date, $0.addingTimeInterval(300)) }

        if let task = taskToEdit {
            viewModel?.updateTask(task, name: name, points: points, note: note,
                                  dueDate: dueDate, endDate: endDate)
        } else {
            viewModel?.addTask(name: name, points: points, note: note,
                               dueDate: dueDate, endDate: endDate, to: category)
        }

        // Если дата указана — предлагаем календарь, иначе просто закрываемся.
        if let dueDate, let endDate {
            offerCalendar(taskName: name, points: points, start: dueDate, end: endDate)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Календарь

    private func offerCalendar(taskName: String, points: Int, start: Date, end: Date) {
        view.endEditing(true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"

        let time = DateFormatter()
        time.locale = Locale(identifier: "ru_RU")
        time.dateFormat = "HH:mm"

        // Один день: «5 июля, 15:00–16:30», разные: обе даты целиком.
        let range = Calendar.current.isDate(start, inSameDayAs: end)
            ? "\(formatter.string(from: start))–\(time.string(from: end))"
            : "\(formatter.string(from: start)) → \(formatter.string(from: end))"

        DQAlert.present(
            from: self,
            icon: "calendar.badge.plus",
            title: "Добавить в Календарь?",
            message: "«\(taskName)» — \(range)",
            actions: [
                .init("Добавить", style: .primary) { [weak self] in
                    CalendarService.addEvent(
                        title: taskName,
                        startDate: start,
                        endDate: end,
                        notes: "Questly · +\(points) баллов"
                    ) { success in
                        if success {
                            Haptics.success()
                            self?.dismiss(animated: true)
                        } else {
                            self?.showCalendarDeniedAlert()
                        }
                    }
                },
                .init("Не нужно", style: .plain) { [weak self] in
                    self?.dismiss(animated: true)
                }
            ]
        )
    }

    private func showCalendarDeniedAlert() {
        let alert = UIAlertController(
            title: "Нет доступа к Календарю",
            message: "Разреши доступ в Настройках → Questly → Календари",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Понятно", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    // MARK: - Фабричный метод для карточек

    private static func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}

// MARK: - UITextFieldDelegate

extension AddTaskViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameField {
            pointsField.becomeFirstResponder()
        }
        return true
    }
}
