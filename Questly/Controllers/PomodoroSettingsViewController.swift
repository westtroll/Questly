//
//  PomodoroSettingsViewController.swift
//  Questly
//
//  Шторка настройки длительностей Помодоро. Каждое значение можно
//  менять двумя способами: степпером или вводом с клавиатуры —
//  оба синхронизированы между собой.
//

import UIKit

final class PomodoroSettingsViewController: UIViewController {

    /// Вызывается при каждом изменении — Помодоро-экран
    /// применит новые значения, если таймер не запущен.
    var onChange: (() -> Void)?

    // Конфигурация строк. Индекс массива = tag степпера и поля —
    // так один обработчик знает, с какой настройкой работает.
    private let rowConfigs: [(title: String, range: ClosedRange<Int>, step: Double)] = [
        ("Фокус",            5...90, 5),
        ("Перерыв",          1...30, 1),
        ("Длинный перерыв",  5...60, 5)
    ]

    private var textFields: [UITextField] = []
    private var steppers: [UIStepper] = []

    // Чтение/запись настройки по индексу строки.
    private func value(at index: Int) -> Int {
        switch index {
        case 0:  return PomodoroSettings.workMinutes
        case 1:  return PomodoroSettings.shortBreakMinutes
        default: return PomodoroSettings.longBreakMinutes
        }
    }

    private func setValue(_ minutes: Int, at index: Int) {
        switch index {
        case 0:  PomodoroSettings.workMinutes = minutes
        case 1:  PomodoroSettings.shortBreakMinutes = minutes
        default: PomodoroSettings.longBreakMinutes = minutes
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Длительность"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                // Сначала завершаем редактирование (сохранит значение
                // через editingDidEnd), потом закрываем шторку.
                self?.view.endEditing(true)
                self?.dismiss(animated: true)
            }
        )

        // Тап в любое место — скрыть клавиатуру. Стандартный приём
        // для numberPad, у которого нет кнопки Return.
        // cancelsTouchesInView = false — жест не «съедает» тапы
        // по степперам и полям, они продолжают работать.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        setupLayout()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Setup

    private func setupLayout() {
        let rows = UIStackView(
            arrangedSubviews: rowConfigs.indices.map { makeRow(index: $0) }
        )
        rows.axis = .vertical
        rows.spacing = 12
        rows.translatesAutoresizingMaskIntoConstraints = false

        let hint = UILabel()
        hint.text = "Время можно ввести вручную — тапни по числу. Изменения применятся сразу, если таймер остановлен, иначе — со следующей фазы"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabel
        hint.numberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(rows)
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            hint.topAnchor.constraint(equalTo: rows.bottomAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func makeRow(index: Int) -> UIView {
        let config = rowConfigs[index]

        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12

        let titleLabel = UILabel()
        titleLabel.text = config.title
        titleLabel.font = .systemFont(ofSize: 16)

        // Поле ручного ввода
        let field = UITextField()
        field.text = "\(value(at: index))"
        field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        field.textAlignment = .center
        field.keyboardType = .numberPad
        field.backgroundColor = .tertiarySystemFill
        field.layer.cornerRadius = 8
        field.tag = index
        field.addTarget(self, action: #selector(fieldEditingEnded(_:)), for: .editingDidEnd)
        field.widthAnchor.constraint(equalToConstant: 52).isActive = true
        field.heightAnchor.constraint(equalToConstant: 32).isActive = true
        textFields.append(field)

        let suffix = UILabel()
        suffix.text = "мин"
        suffix.font = .systemFont(ofSize: 14)
        suffix.textColor = .secondaryLabel

        let stepper = UIStepper()
        stepper.minimumValue = Double(config.range.lowerBound)
        stepper.maximumValue = Double(config.range.upperBound)
        stepper.stepValue = config.step
        stepper.value = Double(value(at: index))
        stepper.tag = index
        stepper.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
        steppers.append(stepper)

        let stack = UIStackView(arrangedSubviews: [titleLabel, field, suffix, stepper])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        suffix.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    // MARK: - Применение значения
    //
    // Единая точка: и степпер, и поле проходят через неё —
    // значение зажимается в диапазон, оба контрола синхронизируются.

    private func apply(_ minutes: Int, at index: Int) {
        let range = rowConfigs[index].range
        let clamped = min(max(minutes, range.lowerBound), range.upperBound)

        setValue(clamped, at: index)
        textFields[index].text = "\(clamped)"
        steppers[index].value = Double(clamped)

        onChange?()
    }

    // MARK: - Actions

    @objc private func stepperChanged(_ sender: UIStepper) {
        Haptics.light()
        apply(Int(sender.value), at: sender.tag)
    }

    @objc private func fieldEditingEnded(_ sender: UITextField) {
        // Пустое или нечисловое значение — возвращаем текущее из настроек.
        let minutes = Int(sender.text ?? "") ?? value(at: sender.tag)
        apply(minutes, at: sender.tag)
    }
}

