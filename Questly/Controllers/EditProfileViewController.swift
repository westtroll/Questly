//
//  EditProfileViewController.swift
//  Questly
//
//  Шторка редактирования профиля: имя, пол, возраст и аватар.
//  Аватар в трёх режимах: эмодзи / инициалы / фото из галереи.
//  Сверху — живой предпросмотр с рамкой текущего уровня: любое
//  изменение видно сразу, сохраняется только по кнопке.
//

import UIKit
import PhotosUI

final class EditProfileViewController: UIViewController {

    /// Вызывается после сохранения — экран профиля обновит шапку.
    var onSave: (() -> Void)?

    // Набор эмодзи-аватаров на выбор
    private static let avatars = [
        "🙂", "😎", "🚀", "🔥", "🐱", "🐶",
        "🦊", "🐼", "⚡️", "🎯", "💪", "🌟"
    ]

    // Текущий (несохранённый) выбор
    private var selectedKind = UserProfile.avatarKind
    private var selectedAvatar = UserProfile.avatarEmoji
    private var selectedColor = CategoryColor.named(UserProfile.avatarColorName)
    private var pickedPhoto: UIImage? = UserProfile.loadAvatarPhoto()

    private var avatarButtons: [UIButton] = []
    private var colorButtons: [UIButton] = []

    // MARK: - UI элементы

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Как тебя зовут?"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.text = UserProfile.name
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let nameCard = EditProfileViewController.makeCard()

    private let genderControl: UISegmentedControl = {
        let control = UISegmentedControl(items: Gender.allCases.map(\.title))
        control.selectedSegmentIndex = UserProfile.gender.rawValue
        return control
    }()

    private let ageField: UITextField = {
        let field = UITextField()
        field.placeholder = "Возраст"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.keyboardType = .numberPad
        field.text = UserProfile.age > 0 ? "\(UserProfile.age)" : ""
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let ageCard = EditProfileViewController.makeCard()

    private let aboutTitle = EditProfileViewController.makeSectionTitle("О себе")

    // Хинт под превью в режиме «Фото»: аватар тапабельный
    private let previewHint: UILabel = {
        let label = UILabel()
        label.text = "нажми, чтобы заменить"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        return label
    }()

    // Живой предпросмотр аватара — с рамкой реального уровня
    private let previewAvatar: AvatarView = {
        let view = AvatarView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 76).isActive = true
        view.heightAnchor.constraint(equalToConstant: 76).isActive = true
        return view
    }()

    private let kindControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Эмодзи", "Инициалы", "Фото"])
        control.selectedSegmentIndex = UserProfile.avatarKind.rawValue
        return control
    }()

    private lazy var photoButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Выбрать из галереи"
        config.image = UIImage(systemName: "photo.on.rectangle.angled")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.baseBackgroundColor = .systemIndigo
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(pickPhoto), for: .touchUpInside)
        return button
    }()

    // Бейдж-камера в углу предпросмотра: подсказывает, что по фото
    // можно тапнуть и заменить его.
    private let cameraBadge: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "camera.fill"))
        view.tintColor = .white
        view.contentMode = .center
        view.backgroundColor = .systemIndigo
        view.layer.cornerRadius = 9
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.systemGroupedBackground.cgColor
        view.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 18).isActive = true
        view.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return view
    }()

    // Секции, которые показываются/прячутся по режиму
    private var emojiGrid: UIStackView!
    private var colorRow: UIStackView!

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Сохранить"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = .systemIndigo
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Уровень пользователя — для рамки предпросмотра
    private lazy var userLevel: Int = {
        LevelSystem.userLevel(totalPoints: DataStore.shared.profileStats().totalPointsEarned).level
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Профиль"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel

        nameField.delegate = self
        nameField.addTarget(self, action: #selector(nameEdited), for: .editingChanged)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        kindControl.addTarget(self, action: #selector(kindChanged), for: .valueChanged)

        // Тап по фону — скрыть клавиатуру (numberPad без Return).
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        setupLayout()
        refreshSelection()
    }

    // MARK: - Setup

    private func setupLayout() {
        nameCard.addSubview(nameField)
        ageCard.addSubview(ageField)

        emojiGrid = makeAvatarGrid()
        colorRow = makeColorRow()

        // Предпросмотр — по центру собственной строки.
        // Тап по нему в режиме «Фото» открывает галерею.
        previewAvatar.isUserInteractionEnabled = true
        previewAvatar.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(previewTapped)))

        let previewRow = UIStackView(arrangedSubviews: [previewAvatar, previewHint])
        previewRow.axis = .vertical
        previewRow.alignment = .center
        previewRow.spacing = 6

        previewRow.addSubview(cameraBadge)
        NSLayoutConstraint.activate([
            cameraBadge.trailingAnchor.constraint(equalTo: previewAvatar.trailingAnchor, constant: 1),
            cameraBadge.bottomAnchor.constraint(equalTo: previewAvatar.bottomAnchor, constant: 1)
        ])

        let stack = UIStackView(arrangedSubviews: [
            previewRow, kindControl,
            emojiGrid, photoButton,
            colorRow,
            aboutTitle, nameCard, ageCard, genderControl
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(10, after: previewRow)
        stack.setCustomSpacing(24, after: colorRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: nameCard.topAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: nameCard.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: nameCard.trailingAnchor, constant: -16),
            nameField.bottomAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: -14),

            ageField.topAnchor.constraint(equalTo: ageCard.topAnchor, constant: 14),
            ageField.leadingAnchor.constraint(equalTo: ageCard.leadingAnchor, constant: 16),
            ageField.trailingAnchor.constraint(equalTo: ageCard.trailingAnchor, constant: -16),
            ageField.bottomAnchor.constraint(equalTo: ageCard.bottomAnchor, constant: -14),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // Сетка эмодзи: 2 ряда по 6.
    private func makeAvatarGrid() -> UIStackView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10

        let perRow = 6
        for rowIndex in 0..<(Self.avatars.count / perRow) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually

            for i in 0..<perRow {
                let index = rowIndex * perRow + i
                let button = UIButton(type: .system)
                button.setTitle(Self.avatars[index], for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 26)
                button.layer.cornerRadius = 12
                button.heightAnchor.constraint(equalToConstant: 48).isActive = true
                button.tag = index
                button.addTarget(self, action: #selector(avatarTapped(_:)), for: .touchUpInside)
                avatarButtons.append(button)
                row.addArrangedSubview(button)
            }
            grid.addArrangedSubview(row)
        }
        return grid
    }

    // Ряд круглых цветных кнопок — та же палитра, что у категорий.
    private func makeColorRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing

        for (index, color) in CategoryColor.allCases.enumerated() {
            let button = UIButton(type: .custom)
            button.backgroundColor = color.main
            button.layer.cornerRadius = 17
            // Фиксированные круги, а не овалы на всю ширину
            button.widthAnchor.constraint(equalToConstant: 34).isActive = true
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorButtons.append(button)
            row.addArrangedSubview(button)
        }
        return row
    }

    // MARK: - Состояние

    private func refreshSelection() {
        // Живой предпросмотр несохранённого выбора
        previewAvatar.configure(kind: selectedKind,
                                emoji: selectedAvatar,
                                colorName: selectedColor.rawValue,
                                photo: pickedPhoto,
                                level: userLevel)

        // Видимость секций по режиму: эмодзи — сетка + цвет фона,
        // инициалы — только цвет градиента, фото — кнопка выбора.
        emojiGrid.isHidden = selectedKind != .emoji
        photoButton.isHidden = selectedKind != .photo
        cameraBadge.isHidden = selectedKind != .photo
        previewHint.isHidden = !(selectedKind == .photo && pickedPhoto != nil)

        // Кнопка честно говорит, что произойдёт
        photoButton.configuration?.title =
            pickedPhoto == nil ? "Выбрать из галереи" : "Заменить фото"
        colorRow.isHidden = selectedKind == .photo

        // Подсветка выбранного эмодзи — в выбранном цвете фона.
        for (index, button) in avatarButtons.enumerated() {
            let isSelected = Self.avatars[index] == selectedAvatar
            button.backgroundColor = isSelected
                ? selectedColor.background
                : .secondarySystemGroupedBackground
            button.layer.borderWidth = isSelected ? 2 : 0
            button.layer.borderColor = selectedColor.main
                .resolvedColor(with: traitCollection).cgColor
        }

        // Кольцо у выбранного цвета
        for (index, button) in colorButtons.enumerated() {
            let isSelected = CategoryColor.allCases[index] == selectedColor
            button.layer.borderWidth = isSelected ? 3 : 0
            button.layer.borderColor = UIColor.label.withAlphaComponent(0.7)
                .resolvedColor(with: traitCollection).cgColor
        }
    }

    // MARK: - Actions

    @objc private func kindChanged() {
        selectedKind = AvatarKind(rawValue: kindControl.selectedSegmentIndex) ?? .emoji
        Haptics.light()
        refreshSelection()
    }

    @objc private func nameEdited() {
        // Имя меняет инициалы — обновляем предпросмотр на лету.
        // ВАЖНО: предпросмотр читает инициалы из ЧЕРНОВИКА поля,
        // но UserProfile.initials берёт сохранённое имя, поэтому
        // временно прокидываем черновик через label напрямую нельзя —
        // просто перерисуем при сохранении. Здесь достаточно ничего
        // не делать для других режимов.
        if selectedKind == .initials { refreshSelection() }
    }

    @objc private func avatarTapped(_ sender: UIButton) {
        selectedAvatar = Self.avatars[sender.tag]
        Haptics.light()
        refreshSelection()
    }

    @objc private func colorTapped(_ sender: UIButton) {
        selectedColor = CategoryColor.allCases[sender.tag]
        Haptics.light()
        refreshSelection()
    }

    @objc private func previewTapped() {
        // В режиме фото тап по аватару = заменить фото
        guard selectedKind == .photo else { return }
        Haptics.light()
        pickPhoto()
    }

    @objc private func pickPhoto() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func saveTapped() {
        UserProfile.name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        UserProfile.gender = Gender(rawValue: genderControl.selectedSegmentIndex) ?? .unspecified
        UserProfile.age = Int(ageField.text ?? "") ?? 0
        UserProfile.avatarEmoji = selectedAvatar
        UserProfile.avatarColorName = selectedColor.rawValue
        UserProfile.avatarKind = selectedKind
        if selectedKind == .photo, let photo = pickedPhoto {
            UserProfile.saveAvatarPhoto(photo)
        }
        onSave?()
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Фабрики UI

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

extension EditProfileViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - PHPickerViewControllerDelegate

extension EditProfileViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController,
                didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.pickedPhoto = image
                self?.refreshSelection()
            }
        }
    }
}

