//
//  AddCategoryViewController.swift
//  Questly
//
//  Новый экран: создание категории. Пользователь вводит название
//  и выбирает иконку (SF Symbols) и цвет из палитры.
//

import UIKit
import Combine

final class AddCategoryViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Данные

    private weak var viewModel: TodayViewModel?

    // Набор иконок на выбор. Все — валидные имена SF Symbols.
    private static let icons = [
        "figure.run", "dumbbell.fill", "book.fill", "graduationcap.fill",
        "briefcase.fill", "heart.fill", "house.fill", "pawprint.fill",
        "fork.knife", "bed.double.fill", "music.note", "paintbrush.fill"
    ]

    private var selectedIcon = AddCategoryViewController.icons[0]
    private var selectedColor = CategoryColor.allCases[0]

    // Храним кнопки, чтобы обновлять их вид при смене выбора.
    private var iconButtons: [UIButton] = []
    private var colorButtons: [UIButton] = []

    // MARK: - UI элементы

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Название категории"
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

    private let iconTitle = AddCategoryViewController.makeSectionTitle("Иконка")
    private let colorTitle = AddCategoryViewController.makeSectionTitle("Цвет")

    // Тумблер «повторять каждый день». Включён по умолчанию —
    // ежедневные категории это основной сценарий.
    private let dailySwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = true
        return toggle
    }()

    private lazy var dailyCard: UIView = {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12

        let label = UILabel()
        label.text = "Повторять каждый день"
        label.font = .systemFont(ofSize: 16)

        let hint = UILabel()
        hint.text = "Если выключить — категория исчезнет в конце дня"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabel
        hint.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [label, hint])
        textStack.axis = .vertical
        textStack.spacing = 2

        let stack = UIStackView(arrangedSubviews: [textStack, dailySwitch])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }()

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Создать категорию"
        config.cornerStyle = .large
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: TodayViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        nameField.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        setupNavigation()
        setupViews()
        setupConstraints()
        setupBindings()
        refreshSelection()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Новая категория"
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

        // Собираем контент вертикальным стеком:
        // поле имени → «Иконка» → сетка иконок → «Цвет» → ряд цветов.
        contentStack.addArrangedSubview(nameCard)
        contentStack.setCustomSpacing(20, after: nameCard)
        contentStack.addArrangedSubview(iconTitle)
        contentStack.addArrangedSubview(makeIconGrid())
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(colorTitle)
        contentStack.addArrangedSubview(makeColorRow())
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(dailyCard)

        view.addSubview(contentStack)
        view.addSubview(saveButton)

        saveButton.isEnabled = false
        saveButton.alpha = 0.5
    }

    // Сетка иконок: 2 ряда по 6 кнопок через вложенные UIStackView.
    private func makeIconGrid() -> UIStackView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10

        let perRow = 6
        for rowIndex in 0..<(Self.icons.count / perRow) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually

            for i in 0..<perRow {
                let index = rowIndex * perRow + i
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: Self.icons[index]), for: .normal)
                button.layer.cornerRadius = 12
                button.heightAnchor.constraint(equalToConstant: 46).isActive = true
                button.tag = index
                button.addTarget(self, action: #selector(iconTapped(_:)), for: .touchUpInside)
                iconButtons.append(button)
                row.addArrangedSubview(button)
            }
            grid.addArrangedSubview(row)
        }
        return grid
    }

    // Ряд цветов: 8 круглых кнопок.
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

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: nameCard.topAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: nameCard.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: nameCard.trailingAnchor, constant: -16),
            nameField.bottomAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: -14),

            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func setupBindings() {
        // Кнопка активна, когда название не пустое.
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: nameField)
            .map { ($0.object as? UITextField)?.text ?? "" }
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

    // MARK: - Обновление выбора

    // Перекрашиваем все кнопки в зависимости от текущего выбора.
    private func refreshSelection() {
        for (index, button) in iconButtons.enumerated() {
            let isSelected = Self.icons[index] == selectedIcon
            button.backgroundColor = isSelected ? selectedColor.background : .secondarySystemGroupedBackground
            button.tintColor = isSelected ? selectedColor.main : .secondaryLabel
        }

        for (index, button) in colorButtons.enumerated() {
            let isSelected = CategoryColor.allCases[index] == selectedColor
            button.layer.borderWidth = isSelected ? 3 : 0
            button.layer.borderColor = UIColor.label.withAlphaComponent(0.7)
                .resolvedColor(with: traitCollection).cgColor
        }

        var config = saveButton.configuration
        config?.baseBackgroundColor = selectedColor.main
        config?.baseForegroundColor = .white
        saveButton.configuration = config
    }

    // MARK: - Actions

    @objc private func iconTapped(_ sender: UIButton) {
        selectedIcon = Self.icons[sender.tag]
        Haptics.light()
        refreshSelection()
    }

    @objc private func colorTapped(_ sender: UIButton) {
        selectedColor = CategoryColor.allCases[sender.tag]
        Haptics.light()
        refreshSelection()
    }

    @objc private func saveTapped() {
        guard let name = nameField.text?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty else { return }

        viewModel?.addCategory(
            name: name,
            icon: selectedIcon,
            colorName: selectedColor.rawValue,
            isDaily: dailySwitch.isOn
        )
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Хелперы

    private static func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }
}

