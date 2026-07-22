//
//  ProfileViewController.swift
//  Questly
//
//  Экран «Профиль» — тонкий контроллер-сборщик. Шапка, карточка
//  уровня и карточки-входы вынесены в компоненты (Views/Profile/).
//  Здесь остаются: карточка стрика, сетка статистики 2×2 (обе
//  тесно связаны с алертами по тапу) и роутинг.
//

import UIKit
import Combine

final class ProfileViewController: UIViewController {

    // MARK: - Данные

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    // Показывать ли шестерёнку настроек. Когда профиль открыт
    // ИЗ настроек, шестерёнка не нужна — иначе рекурсия
    // «настройки → профиль → настройки → ...».
    private let showsSettingsButton: Bool

    init(showsSettingsButton: Bool = true) {
        self.showsSettingsButton = showsSettingsButton
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Компоненты

    private let headerCard = ProfileHeaderCardView()
    private let levelCard = LevelCardView()

    private let challengesCard = NavCardView(
        symbol: "flag.checkered",
        tint: DQColor.challengeAdaptive, soft: DQColor.challengeSoftAdaptive,
        title: "Челленджи", subtitle: "Недельные испытания для новых привычек")

    private let achievementsCard = NavCardView(
        symbol: "medal.fill",
        tint: UIColor(hex: 0xEF9F27), soft: UIColor(hex: 0xFAEEDA),
        title: "Ачивки")

    private let goalsCard = NavCardView(
        symbol: "scope",
        tint: DQColor.accentAdaptive, soft: DQColor.accentSoftAdaptive,
        title: "Цели года")

    private let moodCard = NavCardView(
        symbol: "chart.line.uptrend.xyaxis",
        tint: .systemPink, soft: UIColor.systemPink.withAlphaComponent(0.12),
        title: "Настроение × продуктивность")

    // MARK: - UI: карточка стрика (остаётся здесь ради алерта по тапу)

    private let heroCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.14)
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let heroEmoji: UILabel = {
        let label = UILabel()
        label.text = "🔥"
        label.font = .systemFont(ofSize: 36)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let heroValueLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(22, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let heroSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "текущий стрик"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - UI: сетка статистики (тоже остаётся ради алертов)

    private let bestStreakValue = ProfileViewController.makeValueLabel()
    private let perfectDaysValue = ProfileViewController.makeValueLabel()
    private let tasksValue = ProfileViewController.makeValueLabel()
    private let pointsValue = ProfileViewController.makeValueLabel()

    // Скролл всего профиля: карточек больше, чем влезает в экран.
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Профиль"
        view.backgroundColor = .systemGroupedBackground

        if showsSettingsButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "gearshape"),
                style: .plain,
                target: self,
                action: #selector(openSettings)
            )
        }

        setupLayout()
        wireCardActions()

        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Setup

    private func setupLayout() {
        // Стрик
        heroCard.addSubview(heroEmoji)
        heroCard.addSubview(heroValueLabel)
        heroCard.addSubview(heroSubtitleLabel)
        heroCard.isUserInteractionEnabled = true
        heroCard.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(streakCardTapped)))

        // Сетка 2×2
        let grid = UIStackView(arrangedSubviews: [
            makeRow(
                makeStatCard(value: bestStreakValue, title: "Лучший стрик", kind: .bestStreak),
                makeStatCard(value: perfectDaysValue, title: "Идеальных дней", kind: .perfectDays)
            ),
            makeRow(
                makeStatCard(value: tasksValue, title: "Задач выполнено", kind: .tasks),
                makeStatCard(value: pointsValue, title: "Всего XP", kind: .xp)
            )
        ])
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        let cards: [UIView] = [headerCard, levelCard, heroCard, grid,
                               challengesCard, achievementsCard, goalsCard, moodCard]
        cards.forEach { scrollView.addSubview($0) }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Все карточки — на всю ширину с полями 16; вертикальная
        // цепочка сверху вниз. Задаём общим циклом, чтобы не плодить
        // одинаковые leading/trailing-констрейнты руками.
        let frame = scrollView.frameLayoutGuide
        for card in cards {
            card.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16).isActive = true
            card.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16).isActive = true
        }

        var previous: UIView?
        for card in cards {
            if let previous {
                card.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 12).isActive = true
            } else {
                card.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12).isActive = true
            }
            previous = card
        }
        // Низ последней карточки замыкает contentSize скролла.
        previous?.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16).isActive = true

        // Стрик: внутренняя раскладка
        NSLayoutConstraint.activate([
            heroEmoji.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            heroEmoji.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),

            heroValueLabel.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 16),
            heroValueLabel.leadingAnchor.constraint(equalTo: heroEmoji.trailingAnchor, constant: 16),
            heroValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -16),

            heroSubtitleLabel.topAnchor.constraint(equalTo: heroValueLabel.bottomAnchor, constant: 2),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroValueLabel.leadingAnchor),
            heroSubtitleLabel.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -16)
        ])
    }

    private func wireCardActions() {
        headerCard.onTap = { [weak self] in self?.openEditProfile() }
        levelCard.onTap = { [weak self] in self?.push(LevelSystemViewController()) }
        challengesCard.onTap = { [weak self] in self?.push(ChallengesViewController()) }
        achievementsCard.onTap = { [weak self] in self?.push(AchievementsViewController()) }
        goalsCard.onTap = { [weak self] in self?.push(YearGoalsViewController()) }
        moodCard.onTap = { [weak self] in self?.push(MoodInsightsViewController()) }
    }

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Обновление данных

    private func reload() {
        let stats = store.profileStats()
        let level = LevelSystem.userLevel(totalPoints: stats.totalPointsEarned)

        headerCard.refresh(level: level.level)
        levelCard.refresh(with: level)

        // Стрик + джокеры
        heroValueLabel.text = stats.currentStreak.daysString + " подряд"
        let jokers = store.jokers
        heroSubtitleLabel.text = jokers > 0
            ? "текущий стрик · джокеров: \(jokers)"
            : "текущий стрик"

        bestStreakValue.text = "\(stats.bestStreak)"
        perfectDaysValue.text = "\(stats.perfectDays)"
        tasksValue.text = "\(stats.totalTasksCompleted)"
        pointsValue.text = "\(stats.totalPointsEarned)"

        // Живые подзаголовки карточек-входов
        let unlocked = AchievementStore.unlockedIDs(stats: stats).count
        achievementsCard.setSubtitle("Открыто \(unlocked) из \(AchievementCatalog.all.count)")

        let year = Calendar.current.component(.year, from: Date())
        let goals = store.fetchYearGoals(year: year)
        goalsCard.setSubtitle(goals.isEmpty
            ? "Поставь главные ориентиры на \(year)"
            : "Достигнуто \(goals.filter(\.isDone).count) из \(goals.count)")

        let moodDays = store.allMoodEntries().count
        moodCard.setSubtitle(moodDays < 5
            ? "Отмечай настроение — открой связь"
            : "Дней с отметкой: \(moodDays)")
    }

    // MARK: - Actions

    private func openEditProfile() {
        let editVC = EditProfileViewController()
        // Шторка не вызывает viewWillAppear у экрана под ней,
        // поэтому обновляемся через замыкание.
        editVC.onSave = { [weak self] in self?.reload() }
        presentSheet(editVC, detent: .large())
    }

    @objc private func openSettings() {
        presentSheet(SettingsViewController(), detent: .large())
    }

    private func presentSheet(_ vc: UIViewController, detent: UISheetPresentationController.Detent) {
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [detent]
        }
        present(nav, animated: true)
    }

    // Жмяк + объяснение стрика — тот же алерт, что на главном экране.
    @objc private func streakCardTapped() {
        Haptics.light()
        heroCard.dqSquish()

        let stats = store.profileStats()
        let title = stats.currentStreak > 0
            ? "Стрик: \(stats.currentStreak.daysString) подряд"
            : "Начни свой стрик!"
        DQAlert.present(
            from: self,
            icon: "flame.fill",
            iconTint: .systemOrange,
            title: title,
            message: "Выполняй задачи каждый день и набирай минимум \(AppConfig.streakThreshold) баллов — серия будет расти. Пропустишь день — стрик оборвётся, но его можно спасти джокером.",
            actions: [.init("Понял, продолжаю", style: .primary)]
        )
    }

    // MARK: - Сетка статистики

    private static func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = DQFont.rounded(26, weight: .bold)
        label.textColor = .label
        return label
    }

    private enum StatKind: Int {
        case bestStreak, perfectDays, tasks, xp
    }

    private func makeStatCard(value: UILabel, title: String, kind: StatKind) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.tag = kind.rawValue
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(statCardTapped(_:)))
        )

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [value, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    // Жмяк карточки + алерт с объяснением метрики.
    @objc private func statCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view,
              let kind = StatKind(rawValue: card.tag) else { return }

        Haptics.light()
        card.dqSquish(scale: 0.94)

        let stats = store.profileStats()
        let icon: String
        let tint: UIColor
        let alertTitle: String
        let message: String

        switch kind {
        case .bestStreak:
            icon = "flame.fill"
            tint = .systemOrange
            alertTitle = "Лучший стрик: \(stats.bestStreak.daysString)"
            message = "Твоя самая длинная серия дней с \(AppConfig.streakThreshold)+ баллами за всю историю. Сейчас серия — \(stats.currentStreak.daysString). Побей свой рекорд!"
        case .perfectDays:
            icon = "star.fill"
            tint = .systemYellow
            alertTitle = "Идеальных дней: \(stats.perfectDays)"
            message = "Столько раз ты набирал 100 баллов за день. Каждые \(AppConfig.perfectDaysPerJoker) идеальных дня приносят джокер для спасения стрика."
        case .tasks:
            icon = "checkmark.circle.fill"
            tint = .systemGreen
            alertTitle = "Задач выполнено: \(stats.totalTasksCompleted)"
            message = "Все выполненные задачи за время в Questly. Каждая — кирпичик твоей дисциплины."
        case .xp:
            let level = LevelSystem.userLevel(totalPoints: stats.totalPointsEarned)
            icon = "bolt.fill"
            tint = DQColor.accentAdaptive
            alertTitle = "Всего XP: \(stats.totalPointsEarned)"
            message = "Очки за всё время: задачи, квесты дня, челленджи. Твой уровень — «\(level.title)», до следующего осталось \(level.pointsToNext) XP."
        }

        DQAlert.present(
            from: self,
            icon: icon,
            iconTint: tint,
            title: alertTitle,
            message: message,
            actions: [.init("Понятно", style: .primary)]
        )
    }

    private func makeRow(_ left: UIView, _ right: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [left, right])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }
}
