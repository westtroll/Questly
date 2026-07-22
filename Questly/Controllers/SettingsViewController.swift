//
//  SettingsViewController.swift
//  Questly
//
//  Экран настроек. Пока три секции: действия с сегодняшним днём,
//  управление данными и информация о приложении.
//  Сюда же переехала кнопка «Сбросить день» из навбара главного экрана.
//

import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - Строки таблицы

    private enum Row {
        case profile
        case theme(AppTheme)
        case notifications
        case reminderTime
        case sounds
        case resetToday
        case deleteAll
        case streakInfo
        case version
    }

    // Секции: заголовок, строки, подпись под секцией.
    // computed-свойство, а не let: строки темы читают актуальный выбор.
    private var sections: [(title: String?, rows: [Row], footer: String?)] {
        [
            (nil, [.profile], nil),
            ("Оформление", AppTheme.allCases.map { Row.theme($0) },
             "«Авто» — тёмная тема с 21:00 до 7:00. Для защиты глаз вечером включи также Night Shift в настройках iOS: он убирает синий свет всего экрана."),
            ("Уведомления", [.sounds, .notifications, .reminderTime],
             "Вечернее напоминание о прогрессе, предупреждение о стрике под угрозой и утренний старт."),
            ("Сегодня", [.resetToday], "Все отметки за сегодня будут сняты, баллы обнулятся."),
            ("Данные", [.deleteAll], "Полный сброс: профиль, категории, задачи, история и весь прогресс. Приложение начнёт с приветственного экрана."),
            ("О приложении", [.streakInfo, .version],
             "День идёт в стрик от \(AppConfig.streakThreshold) баллов. Штрафы в полночь: невыполненные задачи — их стоимость ×\(AppConfig.missedTaskPenaltyMultiplier), обрыв стрика от \(AppConfig.streakPenaltyMinLength) дней — \(AppConfig.streakBreakPenalty) XP. Ниже нуля XP не опускается.\n\n🎟️ Джокеры спасают стрик в провальный день. Даётся один в неделю и один за каждые \(AppConfig.perfectDaysPerJoker) идеальных дня, в запасе до \(AppConfig.maxJokers).")
        ]
    }

    // MARK: - UI

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .systemGroupedBackground
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настройки"
        view.backgroundColor = .systemGroupedBackground

        // Если экран показан модально (шторкой из профиля) —
        // добавляем кнопку закрытия.
        if presentingViewController != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: UIAction { [weak self] _ in
                    self?.dismiss(animated: true)
                }
            )
        }

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - Actions

    @objc private func soundsSwitchChanged(_ sender: UISwitch) {
        SoundService.isEnabled = sender.isOn
        if sender.isOn { SoundService.play(.questDone) }   // мгновенная проба звука
    }

    @objc private func notificationsSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            // Сначала системное разрешение, только потом включаем.
            NotificationService.requestPermission { [weak self] granted in
                if granted {
                    NotificationService.isEnabled = true
                    Haptics.light()
                    // Сразу собираем расписание с текущими цифрами.
                    DataStore.shared.refreshWidgetAndNotifications()
                } else {
                    // Отказ: возвращаем тумблер и подсказываем путь.
                    sender.setOn(false, animated: true)
                    self?.showNotificationsDeniedAlert()
                }
            }
        } else {
            NotificationService.isEnabled = false   // сеттер снимет расписание
        }
    }

    private func showNotificationsDeniedAlert() {
        let alert = UIAlertController(
            title: "Уведомления выключены",
            message: "Разреши их в Настройках → Questly → Уведомления",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Понятно", style: .default))
        present(alert, animated: true)
    }

    /// Шторка с колесом времени для вечерней страховки
    private func showReminderTimePicker() {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.translatesAutoresizingMaskIntoConstraints = false

        let current = NotificationService.streakGuardTime
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = current.hour
        components.minute = current.minute
        if let date = Calendar.current.date(from: components) { picker.date = date }

        let sheetVC = UIViewController()
        sheetVC.view.backgroundColor = .systemGroupedBackground

        var config = UIButton.Configuration.filled()
        config.title = "Сохранить"
        config.cornerStyle = .large
        config.buttonSize = .large
        let saveButton = UIButton(configuration: config)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addAction(UIAction { [weak self, weak sheetVC] _ in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            NotificationService.streakGuardTime = (parts.hour ?? 21, parts.minute ?? 30)
            // Пересобрать расписание с новым временем и обновить строку
            DataStore.shared.refreshWidgetAndNotifications()
            self?.tableView.reloadData()
            sheetVC?.dismiss(animated: true)
        }, for: .touchUpInside)

        sheetVC.view.addSubview(picker)
        sheetVC.view.addSubview(saveButton)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: sheetVC.view.topAnchor, constant: 8),
            picker.centerXAnchor.constraint(equalTo: sheetVC.view.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 4),
            saveButton.leadingAnchor.constraint(equalTo: sheetVC.view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: sheetVC.view.trailingAnchor, constant: -20)
        ])

        if let sheet = sheetVC.sheetPresentationController {
            sheet.detents = [.custom { _ in 300 }]
            sheet.prefersGrabberVisible = true
        }
        present(sheetVC, animated: true)
    }

    private func confirmResetToday() {
        let alert = UIAlertController(
            title: "Сбросить сегодняшний день?",
            message: "Все отметки будут сняты",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive) { _ in
            DataStore.shared.resetToday()
        })
        present(alert, animated: true)
    }

    private func confirmDeleteAll() {
        let alert = UIAlertController(
            title: "Удалить все данные?",
            message: "Профиль, категории, задачи, история и весь прогресс будут стёрты безвозвратно. Приложение начнётся с приветственного экрана",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить всё", style: .destructive) { [weak self] _ in
            self?.performFullReset()
        })
        present(alert, animated: true)
    }

    private func performFullReset() {
        // Окно запоминаем ДО любых манипуляций с иерархией.
        let window = view.window

        DataStore.shared.deleteAllData()   // категории, задачи, история, XP
        UserProfile.reset()                // имя, аватар, пол, возраст, онбординг
        UserProfile.resetAvatarExtras()    // вид аватара и файл фото

        // Уведомления — тоже часть профиля: выключаем и даём
        // новому профилю право снова увидеть пре-промпт.
        NotificationService.isEnabled = false
        NotificationService.hasShownPrePrompt = false

        // Меняем корневой контроллер на онбординг. Открытая шторка
        // настроек принадлежит старому дереву и исчезнет вместе с ним.
        let onboarding = OnboardingViewController()
        onboarding.onFinish = {
            UserProfile.hasCompletedOnboarding = true
            window?.rootViewController = MainTabBarController()
            if let window {
                UIView.transition(with: window, duration: 0.4,
                                  options: .transitionCrossDissolve, animations: nil)
            }
        }
        window?.rootViewController = onboarding
        if let window {
            UIView.transition(with: window, duration: 0.4,
                              options: .transitionCrossDissolve, animations: nil)
        }
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Строк мало и они статичные — создаём ячейки напрямую, без reuse.
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()

        switch sections[indexPath.section].rows[indexPath.row] {
        case .profile:
            // Подзаголовком показываем текущий уровень — маленький
            // повод заглянуть в профиль.
            let stats = DataStore.shared.profileStats()
            let level = LevelSystem.userLevel(totalPoints: stats.totalPointsEarned)
            config.text = "Профиль"
            config.secondaryText = "Уровень \(level.level) · \(level.title)"
            config.image = UIImage(systemName: "person.crop.circle.fill")
            config.imageProperties.tintColor = DQColor.accentAdaptive
            cell.accessoryType = .disclosureIndicator

        case .theme(let theme):
            config.text = theme.title
            config.image = UIImage(systemName: theme.icon)
            config.imageProperties.tintColor = DQColor.accentAdaptive
            // Галочка у выбранной темы
            cell.accessoryType = ThemeManager.current == theme ? .checkmark : .none

        case .notifications:
            config.text = "Умные уведомления"
            config.image = UIImage(systemName: "bell.badge.fill")
            config.imageProperties.tintColor = .systemOrange
            let toggle = UISwitch()
            toggle.isOn = NotificationService.isEnabled
            toggle.addTarget(self, action: #selector(notificationsSwitchChanged(_:)),
                             for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none

        case .sounds:
            config.text = "Звуки наград"
            config.image = UIImage(systemName: "speaker.wave.2.fill")
            config.imageProperties.tintColor = DQColor.accentAdaptive
            let toggle = UISwitch()
            toggle.isOn = SoundService.isEnabled
            toggle.addTarget(self, action: #selector(soundsSwitchChanged(_:)),
                             for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none

        case .reminderTime:
            let time = NotificationService.streakGuardTime
            config.text = "Вечерняя страховка"
            config.secondaryText = String(format: "Напомним в %02d:%02d, если день ниже порога стрика", time.hour, time.minute)
            config.secondaryTextProperties.color = .secondaryLabel
            config.secondaryTextProperties.font = .systemFont(ofSize: 12)
            config.image = UIImage(systemName: "clock.badge.exclamationmark")
            config.imageProperties.tintColor = .systemOrange

        case .resetToday:
            config.text = "Сбросить отметки за сегодня"
            config.image = UIImage(systemName: "arrow.counterclockwise")
            config.imageProperties.tintColor = .systemOrange

        case .deleteAll:
            config.text = "Удалить все данные"
            config.textProperties.color = .systemRed
            config.image = UIImage(systemName: "trash")
            config.imageProperties.tintColor = .systemRed

        case .streakInfo:
            config.text = "Порог стрика"
            config.secondaryText = "\(AppConfig.streakThreshold) баллов"
            config.image = UIImage(systemName: "flame")
            config.imageProperties.tintColor = .systemOrange
            cell.selectionStyle = .none

        case .version:
            config.text = "Версия"
            config.secondaryText = "2.0"
            config.image = UIImage(systemName: "info.circle")
            config.imageProperties.tintColor = .secondaryLabel
            cell.selectionStyle = .none
        }

        cell.contentConfiguration = config
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch sections[indexPath.section].rows[indexPath.row] {
        case .profile:
            // Пушим внутри навигации шторки. Шестерёнку скрываем,
            // чтобы не зациклить «настройки → профиль → настройки».
            let profileVC = ProfileViewController(showsSettingsButton: false)
            navigationController?.pushViewController(profileVC, animated: true)
        case .theme(let theme):
            ThemeManager.current = theme   // применяется сразу, с анимацией
            Haptics.light()
            tableView.reloadData()          // перерисовать галочки
        case .reminderTime: showReminderTimePicker()
        case .resetToday: confirmResetToday()
        case .deleteAll:  confirmDeleteAll()
        default: break
        }
    }
}
