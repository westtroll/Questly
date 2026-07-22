//
//  OnboardingViewController.swift
//  Questly
//
//  Приветственный онбординг первого запуска:
//  приветствие → три экрана про фичи → имя → пол → возраст → «готово».
//  Можно листать назад; пол и возраст пропускаются, всё правится в профиле.
//

import UIKit

final class OnboardingViewController: UIViewController {

    /// Вызывается по завершении — SceneDelegate сменит корневой экран.
    var onFinish: (() -> Void)?

    // MARK: - Шаги

    private enum Step: Int, CaseIterable {
        case welcome, featureScore, featureFocus, featureExtras,
             name, gender, age, done
    }

    private var step: Step = .welcome

    // MARK: - UI: общие элементы

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 64)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(26, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - UI: поля ввода (по одному на шаг, показываем нужное)

    private let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Твоё имя"
        field.font = .systemFont(ofSize: 17)
        field.textAlignment = .center
        field.backgroundColor = .secondarySystemGroupedBackground
        field.layer.cornerRadius = 12
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let genderControl: UISegmentedControl = {
        let control = UISegmentedControl(items: Gender.allCases.map(\.title))
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let ageField: UITextField = {
        let field = UITextField()
        field.placeholder = "Возраст"
        field.font = .systemFont(ofSize: 17)
        field.textAlignment = .center
        field.keyboardType = .numberPad
        field.backgroundColor = .secondarySystemGroupedBackground
        field.layer.cornerRadius = 12
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    // MARK: - UI: управление

    private let nextButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = DQColor.accent
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Пропустить", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var progressDots: [UIView] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        nameField.delegate = self
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // Тап по фону — скрыть клавиатуру (numberPad без Return).
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        setupLayout()
        configureStep()
    }

    // MARK: - Setup

    private func setupLayout() {
        // Точки прогресса
        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 8
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        for _ in Step.allCases {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            progressDots.append(dot)
            dotsStack.addArrangedSubview(dot)
        }

        [skipButton, backButton, dotsStack, emojiLabel, titleLabel, subtitleLabel,
         nameField, genderControl, ageField, nextButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            dotsStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dotsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            emojiLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            emojiLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            nameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            nameField.heightAnchor.constraint(equalToConstant: 52),

            genderControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            genderControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            genderControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            ageField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            ageField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ageField.widthAnchor.constraint(equalToConstant: 140),
            ageField.heightAnchor.constraint(equalToConstant: 52),

            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            nextButton.heightAnchor.constraint(equalToConstant: 52),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Конфигурация шага

    private func configureStep() {
        // Скрываем все поля, показываем нужное для шага.
        nameField.isHidden = step != .name
        genderControl.isHidden = step != .gender
        ageField.isHidden = step != .age
        // «Пропустить» доступен на всех шагах, кроме финального.
        skipButton.isHidden = step == .done
        // «Назад» — везде, кроме самого первого экрана.
        backButton.isHidden = step == .welcome

        switch step {
        case .welcome:
            emojiLabel.text = "🎯"
            titleLabel.text = "Добро пожаловать\nв Questly!"
            subtitleLabel.text = "Планируй день, зарабатывай очки, прокачивай уровень и держи стрик. Рады знакомству!"
            setButtonTitle("Начать знакомство")

        case .featureScore:
            emojiLabel.text = "💯"
            titleLabel.text = "100 баллов\nкаждый день"
            subtitleLabel.text = "Создай свои категории, наполни их задачами с баллами и закрывай день на 60+ — так растёт стрик 🔥. Сорвался? Джокер спасёт цепочку."
            setButtonTitle("Далее")
            view.endEditing(true)

        case .featureFocus:
            emojiLabel.text = "🍅"
            titleLabel.text = "Фокус-таймер"
            subtitleLabel.text = "Назови, над чем работаешь, и запусти Помодоро. Таймер живёт на экране блокировки, сессии складываются в статистику по каждому фокусу, а за каждую капает XP."
            setButtonTitle("Далее")

        case .featureExtras:
            emojiLabel.text = "🧩"
            titleLabel.text = "И это не всё"
            subtitleLabel.text = "Квест дня, статьи о продуктивности с XP за чтение, ачивки и виджеты — задачи можно отмечать прямо с домашнего экрана, не открывая приложение."
            setButtonTitle("Далее")

        case .name:
            emojiLabel.text = "✍️"
            titleLabel.text = "Как тебя зовут?"
            subtitleLabel.text = "Имя появится в приветствии профиля"
            setButtonTitle("Далее")
            nameField.becomeFirstResponder()

        case .gender:
            emojiLabel.text = "👤"
            titleLabel.text = "Укажи пол"
            subtitleLabel.text = "Если не хочешь — оставь «Не указан»"
            setButtonTitle("Далее")
            view.endEditing(true)

        case .age:
            emojiLabel.text = "🎂"
            titleLabel.text = "Сколько тебе лет?"
            subtitleLabel.text = "Тоже можно пропустить"
            setButtonTitle("Далее")
            ageField.becomeFirstResponder()

        case .done:
            emojiLabel.text = "🚀"
            let name = UserProfile.name.trimmingCharacters(in: .whitespaces)
            titleLabel.text = name.isEmpty ? "Всё готово!" : "Всё готово, \(name)!"
            subtitleLabel.text = "Приятного использования Questly. Твой идеальный день начинается сейчас"
            setButtonTitle("Поехали!")
            view.endEditing(true)
        }

        // Точки прогресса
        for (index, dot) in progressDots.enumerated() {
            dot.backgroundColor = index <= step.rawValue
                ? DQColor.accentAdaptive
                : .tertiarySystemFill
        }
    }

    private func setButtonTitle(_ title: String) {
        var config = nextButton.configuration
        config?.title = title
        nextButton.configuration = config
    }

    // MARK: - Навигация по шагам

    private func advance() {
        // Сохраняем данные текущего шага перед переходом.
        switch step {
        case .name:
            UserProfile.name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        case .gender:
            UserProfile.gender = Gender(rawValue: genderControl.selectedSegmentIndex) ?? .unspecified
        case .age:
            UserProfile.age = Int(ageField.text ?? "") ?? 0
        case .welcome, .featureScore, .featureFocus, .featureExtras, .done:
            break
        }

        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        step = next

        // Плавная смена контента — crossDissolve всей вьюхи.
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve) {
            self.configureStep()
        }
        Haptics.light()
    }

    private func finish() {
        Haptics.success()
        onFinish?()
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if step == .done {
            finish()
        } else {
            advance()
        }
    }

    @objc private func backTapped() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve) {
            self.configureStep()
        }
        Haptics.light()
    }

    // «Пропустить» — сразу в приложение, без сохранения текущего шага.
    @objc private func skipTapped() {
        view.endEditing(true)
        finish()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate

extension OnboardingViewController: UITextFieldDelegate {

    // Enter в поле имени работает как «Далее».
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        advance()
        return true
    }
}

