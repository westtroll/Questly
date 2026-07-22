//
//  HabitCounterFormViewController.swift
//  Questly
//
//  Создание и редактирование счётчика привычки: название, стиль (цвет),
//  формат отображения времени, дата начала отсчёта и денежный блок —
//  траты на привычку за период, чтобы считать экономию.
//

import UIKit
import Combine
import SwiftData

final class HabitCounterFormViewController: UIViewController {

    // MARK: - Режим

    private let counterToEdit: HabitCounter?
    private var isEditMode: Bool { counterToEdit != nil }

    // MARK: - Состояние выбора

    private var selectedColor: CategoryColor
    private var selectedFormat: CounterFormat
    private var selectedCurrency: String

    private var colorButtons: [UIButton] = []

    // Валюты на выбор: символ + код
    private static let currencies: [(symbol: String, code: String)] = [
        ("₽", "RUB"), ("$", "USD"), ("€", "EUR"),
        ("₸", "KZT"), ("Br", "BYN"), ("₴", "UAH")
    ]

    // MARK: - UI элементы

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Например: Не пью колу"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let nameCard = HabitCounterFormViewController.makeCard()

    // Кнопка-меню выбора формата. changesSelectionAsPrimaryAction —
    // UIKit сам ведёт галочку в меню и подставляет выбранное в заголовок.
    private let formatButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.indicator = .popup
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        return button
    }()

    private let startPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "ru_RU")
        picker.maximumDate = Date()   // отсчёт не может начаться в будущем
        return picker
    }()

    // Денежный блок
    private let moneyQuestion: UILabel = {
        let label = UILabel()
        label.text = "Сколько денег ты тратишь на привычку?"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let moneyHint: UILabel = {
        let label = UILabel()
        label.text = "Questly поможет посчитать экономию денег"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let periodControl: UISegmentedControl = {
        let control = UISegmentedControl(items: SpendPeriod.allCases.map(\.title))
        control.selectedSegmentIndex = 0
        return control
    }()

    private let amountField: UITextField = {
        let field = UITextField()
        field.placeholder = "0"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.keyboardType = .decimalPad
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let amountCard = HabitCounterFormViewController.makeCard()

    // MARK: - UI: обещание (необязательное)

    private static let promiseDurations: [(title: String, days: Int)] = [
        ("1 день", 1), ("3 дня", 3), ("Неделя", 7),
        ("2 недели", 14), ("Месяц", 30), ("3 месяца", 90)
    ]

    private var selectedPromiseDays = 7

    private let promiseHint: UILabel = {
        let label = UILabel()
        label.text = "Ответь: почему я это делаю? Оставь пустым, если пока не готов"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let promiseTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .secondarySystemGroupedBackground
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let promiseDurationButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.indicator = .popup
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        return button
    }()

    private let currencyButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.indicator = .popup
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = isEditMode ? "Сохранить" : "Создать счётчик"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // Кнопка сброса — только в режиме редактирования.
    // Сброс применяется ПРИ СОХРАНЕНИИ: до «Сохранить» можно
    // передумать и выйти через «Отмена» без последствий.
    private lazy var resetButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Сбросить счётчик"
        config.image = UIImage(systemName: "arrow.counterclockwise")
        config.imagePadding = 8
        config.baseForegroundColor = .systemRed
        // Мягкий полупрозрачный красный фон вместо бледного tinted.
        config.background.backgroundColor = UIColor.systemRed.withAlphaComponent(0.14)
        config.cornerStyle = .capsule    // овальная капсула
        config.buttonSize = .medium
        // Симметричные отступы — фон-капсула сидит ровно вокруг текста.
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            return attrs
        }
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        return button
    }()

    // Контент в скролле — с клавиатурой форма длинная.
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(counterToEdit: HabitCounter? = nil) {
        self.counterToEdit = counterToEdit
        self.selectedColor = counterToEdit.map { CategoryColor.named($0.colorName) } ?? .green
        self.selectedFormat = counterToEdit?.format ?? .daysHoursMinutes
        self.selectedCurrency = counterToEdit?.currencyCode ?? "RUB"
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isEditMode ? "Изменить счётчик" : "Новый счётчик"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel

        nameField.delegate = self

        // Заполнение в режиме редактирования — до биндингов (.prepend).
        if let counter = counterToEdit {
            nameField.text = counter.name
            startPicker.date = counter.startDate
            periodControl.selectedSegmentIndex = counter.spendPeriod.rawValue
            if counter.spendAmount > 0 {
                amountField.text = String(format: "%g", counter.spendAmount)
            }
            promiseTextView.text = counter.promiseText
        }

        setupMenus()
        setupLayout()
        setupBindings()
        refreshSelection()

        // Тап по фону — скрыть клавиатуру.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Меню (формат и валюта)

    private func setupMenus() {
        formatButton.menu = UIMenu(children: CounterFormat.allCases.map { format in
            UIAction(title: format.title,
                     state: format == selectedFormat ? .on : .off) { [weak self] _ in
                self?.selectedFormat = format
            }
        })

        currencyButton.menu = UIMenu(children: Self.currencies.map { currency in
            UIAction(title: "\(currency.symbol) \(currency.code)",
                     state: currency.code == selectedCurrency ? .on : .off) { [weak self] _ in
                self?.selectedCurrency = currency.code
            }
        })

        promiseDurationButton.menu = UIMenu(children: Self.promiseDurations.map { duration in
            UIAction(title: duration.title,
                     state: duration.days == selectedPromiseDays ? .on : .off) { [weak self] _ in
                self?.selectedPromiseDays = duration.days
            }
        })
    }

    // MARK: - Layout

    private func setupLayout() {
        nameCard.addSubview(nameField)

        // Ряд суммы: поле + кнопка валюты в одной карточке.
        let amountRow = UIStackView(arrangedSubviews: [amountField, currencyButton])
        amountRow.axis = .horizontal
        amountRow.spacing = 8
        amountRow.alignment = .center
        amountRow.translatesAutoresizingMaskIntoConstraints = false
        amountCard.addSubview(amountRow)

        let stack = UIStackView(arrangedSubviews: [
            nameCard,
            Self.makeSectionTitle("Стиль"), makeColorRow(),
            Self.makeSectionTitle("Формат времени"), makeRowCard(title: nil, control: formatButton),
            Self.makeSectionTitle("Начало отсчёта"), makeRowCard(title: "Когда бросил?", control: startPicker),
            moneyQuestion, moneyHint, periodControl, amountCard,
            Self.makeSectionTitle("Обещание"), promiseHint, promiseTextView,
            makeRowCard(title: "На какой срок?", control: promiseDurationButton)
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: nameCard)
        stack.setCustomSpacing(4, after: moneyQuestion)
        stack.setCustomSpacing(10, after: moneyHint)
        stack.setCustomSpacing(20, after: amountCard)
        stack.setCustomSpacing(4, after: promiseHint)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Сброс доступен только для существующего счётчика.
        // Оборачиваем в контейнер, чтобы капсула была по центру
        // и обнимала текст, а не растягивалась на всю ширину стека.
        if isEditMode {
            let resetContainer = UIView()
            resetContainer.addSubview(resetButton)
            resetButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                resetButton.topAnchor.constraint(equalTo: resetContainer.topAnchor),
                resetButton.bottomAnchor.constraint(equalTo: resetContainer.bottomAnchor),
                resetButton.centerXAnchor.constraint(equalTo: resetContainer.centerXAnchor)
            ])
            stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(resetContainer)
        }

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: nameCard.topAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: nameCard.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: nameCard.trailingAnchor, constant: -16),
            nameField.bottomAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: -14),

            amountRow.topAnchor.constraint(equalTo: amountCard.topAnchor, constant: 8),
            amountRow.leadingAnchor.constraint(equalTo: amountCard.leadingAnchor, constant: 16),
            amountRow.trailingAnchor.constraint(equalTo: amountCard.trailingAnchor, constant: -8),
            amountRow.bottomAnchor.constraint(equalTo: amountCard.bottomAnchor, constant: -8),

            promiseTextView.heightAnchor.constraint(equalToConstant: 80),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            // Ширина контента = ширина экрана минус отступы — иначе
            // скролл станет горизонтальным.
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

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

    private func makeRowCard(title: String?, control: UIView) -> UIView {
        let card = Self.makeCard()

        var views: [UIView] = []
        if let title {
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 15)
            label.textColor = .secondaryLabel
            views.append(label)
        }
        views.append(control)

        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.distribution = title == nil ? .fill : .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        return card
    }

    // MARK: - Bindings

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

    // MARK: - Выбор цвета

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

    @objc private func resetTapped() {
        var message = "Отсчёт начнётся заново с этой минуты. Изменение применится при сохранении."
        if counterToEdit?.isPromiseActive == true {
            message += "\n\n⚠️ Активное обещание будет нарушено."
        }

        let alert = UIAlertController(
            title: "Сбросить счётчик?",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            // Двигаем форму, а не модель: сохранение применит всё разом,
            // «Отмена» — откатит. Пустой текст обещания в saveTapped
            // автоматически снимет и обещание.
            startPicker.date = .now
            promiseTextView.text = ""

            var config = resetButton.configuration
            config?.title = "Будет сброшен при сохранении ✓"
            resetButton.configuration = config
            resetButton.isEnabled = false
            Haptics.light()
        })
        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        guard let name = nameField.text?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty else { return }

        // Десятичный разделитель: пользователь мог ввести запятую.
        let amountText = (amountField.text ?? "").replacingOccurrences(of: ",", with: ".")
        let amount = max(0, Double(amountText) ?? 0)
        let period = SpendPeriod(rawValue: periodControl.selectedSegmentIndex) ?? .day

        let promiseText = promiseTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let counter = counterToEdit {
            counter.recordCurrentRun()   // фиксируем заход до смены даты
            counter.name = name
            counter.colorName = selectedColor.rawValue
            counter.startDate = startPicker.date
            counter.format = selectedFormat
            counter.spendAmount = amount
            counter.spendPeriod = period
            counter.currencyCode = selectedCurrency

            // Обещание при редактировании:
            // - текст стёрли → обещание снимается;
            // - текст изменили или обещания не было → новое, срок с этой минуты;
            // - текст не трогали и обещание уже идёт → НЕ перезапускаем,
            //   иначе правка цвета сбрасывала бы срок. Явный перезапуск —
            //   через «Обновить обещание» в меню счётчика.
            if promiseText.isEmpty {
                counter.promiseText = ""
                counter.promiseUntil = nil
            } else if promiseText != counter.promiseText || counter.promiseUntil == nil {
                counter.promiseText = promiseText
                counter.promiseUntil = Date().addingTimeInterval(Double(selectedPromiseDays) * 86_400)
            }
        } else {
            let counter = HabitCounter(
                name: name,
                colorName: selectedColor.rawValue,
                startDate: startPicker.date,
                format: selectedFormat,
                spendAmount: amount,
                spendPeriod: period,
                currencyCode: selectedCurrency
            )
            if !promiseText.isEmpty {
                counter.promiseText = promiseText
                counter.promiseUntil = Date().addingTimeInterval(Double(selectedPromiseDays) * 86_400)
            }
            DataStore.shared.context.insert(counter)
        }
        DataStore.shared.save()
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Фабрики

    private static func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private static func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }
}

// MARK: - UITextFieldDelegate

extension HabitCounterFormViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
