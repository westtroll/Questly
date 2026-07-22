//
//  TodayViewController.swift
//  Questly
//
//  Главный экран (бывший MainViewController). Вместо таблицы —
//  UICollectionView с compositional layout: карточка прогресса сверху
//  и плитки категорий 2×2. Тап по плитке открывает экран категории.
//

import UIKit
import Combine

final class TodayViewController: UIViewController {

    // MARK: - ViewModel

    private let viewModel = TodayViewModel()
    private var cancellables = Set<AnyCancellable>()

    // Запоминаем прошлый балл, чтобы поймать момент достижения 100
    // и отпраздновать его один раз, а не на каждое обновление.
    private weak var moodNav: UINavigationController?
    private var lastScore = -1

    // То же самое для уровня: празднуем только его РОСТ.
    private var lastLevel = -1

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .systemGroupedBackground
        cv.translatesAutoresizingMaskIntoConstraints = false
        // Без задержки касаний «жмяк» плиток невидим: подсветка
        // при быстром тапе вспыхивала бы лишь на мгновение.
        cv.delaysContentTouches = false
        cv.register(CategoryTileCell.self, forCellWithReuseIdentifier: CategoryTileCell.reuseId)
        cv.register(AddCategoryTileCell.self, forCellWithReuseIdentifier: AddCategoryTileCell.reuseId)
        cv.register(
            ScoreHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ScoreHeaderView.reuseId
        )
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Сегодня"
        view.backgroundColor = .systemGroupedBackground

        // Шестерёнка настроек — как на экране профиля.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        // Чек-ин настроения справа.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "face.smiling"),
            style: .plain,
            target: self,
            action: #selector(openMoodPicker)
        )

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupBindings()

        // Возврат из фона: проверяем, не наступил ли новый день.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appWillEnterForeground() {
        viewModel.checkRollover()
    }

    private var didShowPlannedBanner = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Начисляем причитающиеся джокеры (недельный + за идеальные дни).
        // Безопасно при каждом заходе — повторно за ту же неделю не даст.
        DataStore.shared.grantJokersIfNeeded()

        // Предложение спасти вчерашний проваленный день джокером —
        // приоритетнее баннера плана, показываем первым.
        if maybeOfferJokerSave() { return }

        // Один раз за сессию напоминаем, если на сегодня что-то
        // было запланировано заранее (через календарь истории).
        guard !didShowPlannedBanner else { return }
        didShowPlannedBanner = true

        let planned = DataStore.shared.fetchPlanned(on: Date()).filter { !$0.isDone }
        guard !planned.isEmpty else { return }
        let names = planned.prefix(2).map(\.title).joined(separator: ", ")
        let extra = planned.count > 2 ? " и ещё \(planned.count - 2)" : ""
        showBanner("🗓️ На сегодня запланировано: \(names)\(extra)")
    }

    private var didOfferJokerSave = false

    // Возвращает true, если показали предложение спасти стрик.
    private func maybeOfferJokerSave() -> Bool {
        // viewDidAppear срабатывает многократно (в т.ч. когда наш же
        // алерт закрывается). Показываем предложение один раз за сессию.
        guard !didOfferJokerSave else { return false }
        let store = DataStore.shared
        guard store.savableDay != nil, store.jokers > 0 else { return false }
        didOfferJokerSave = true

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let dayText = store.savableDay.map { formatter.string(from: $0) } ?? "вчера"

        DQAlert.present(
            from: self,
            icon: "flame.fill",
            iconTint: .systemOrange,
            title: "Спасти стрик?",
            message: "\(dayText) не удалось набрать нужные баллы. Потрать джокер, чтобы сохранить серию — у тебя их \(store.jokers).",
            actions: [
                .init("Спасти", style: .primary) { [weak self] in
                    if store.spendJokerToSave() {
                        Haptics.success()
                        self?.showBanner("🎟️ Стрик спасён! Осталось джокеров: \(store.jokers)")
                        self?.viewModel.reload()
                    }
                },
                .init("Не спасать", style: .plain) {
                    store.dismissSavableDay()
                }
            ]
        )
        return true
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
        }
        present(nav, animated: true)
    }

    // MARK: - Настроение (чек-ин)

    @objc private func openMoodPicker() {
        let start = DataStore.shared.moodEntry(on: Date())?.value ?? 3
        let picker = MoodPickerViewController(startValue: start)
        let nav = UINavigationController(rootViewController: picker)
        // Кнопка «история» в навбаре шторки.
        picker.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chart.xyaxis.line"),
            style: .plain, target: self, action: #selector(openMoodHistory)
        )
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak nav] _ in nav?.dismiss(animated: true) }
        )
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        moodNav = nav
        present(nav, animated: true)
    }

    @objc private func openMoodHistory() {
        moodNav?.pushViewController(MoodHistoryViewController(), animated: true)
    }

    // Самый верхний контроллер: события (уровень, ачивка) могут
    // случиться, когда TodayVC прикрыт экраном категории или шторкой —
    // показ «from: self» тогда молча проваливается.
    private func topMostController() -> UIViewController {
        var top: UIViewController = tabBarController ?? self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    // MARK: - Поздравление с ачивкой

    // Показывает поздравление с самого верхнего контроллера (ачивка
    // могла открыться на экране категории). Если сейчас показан другой
    // алерт (например, «Новый уровень»), пробует ещё раз чуть позже.
    private func celebrateAchievement(_ achievement: Achievement,
                                      extraCount: Int,
                                      attempt: Int = 0) {
        let top = topMostController()

        if top is DQAlert || top is UIAlertController {
            guard attempt < 3 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.celebrateAchievement(achievement, extraCount: extraCount,
                                           attempt: attempt + 1)
            }
            return
        }

        Haptics.success()
        SoundService.play(.achievement)
        let extra = extraCount > 0 ? "\n\nИ ещё +\(extraCount) — загляни в профиль!" : ""
        DQAlert.present(
            from: top,
            icon: "medal.fill",
            iconTint: .systemYellow,
            title: "Новая ачивка!",
            message: "\(achievement.emoji) «\(achievement.title)» — \(achievement.detail)\(extra)",
            actions: [.init("Заслужил!", style: .primary)]
        )
    }

    // MARK: - Пре-промпт уведомлений

    private func maybeShowNotificationsPrompt(score: Int) {
        // Условия: есть первая выполненная задача, промпт ещё не
        // показывали, уведомления не включены другим путём.
        guard score > 0,
              !NotificationService.hasShownPrePrompt,
              !NotificationService.isEnabled else { return }

        NotificationService.hasShownPrePrompt = true   // один раз и всё

        // Задачу могли отметить на экране категории — тогда TodayVC
        // прикрыт. Показываем алерт с самого верхнего контроллера.
        var top: UIViewController = tabBarController ?? self
        while let presented = top.presentedViewController {
            top = presented
        }

        DQAlert.present(
            from: top,
            icon: "bell.badge.fill",
            title: "Включить умные уведомления?",
            message: "Questly напомнит вечером, сколько осталось до идеального дня, и предупредит, если стрик под угрозой. Передумаешь — тумблер в настройках.",
            actions: [
                .init("Разрешить", style: .primary) {
                    // Только теперь дёргаем СИСТЕМНЫЙ диалог — наш «да» первым
                    // фильтром отсеял тех, кто нажал бы «нет» системе.
                    NotificationService.requestPermission { granted in
                        if granted {
                            NotificationService.isEnabled = true
                            Haptics.success()
                            DataStore.shared.refreshWidgetAndNotifications()
                        }
                    }
                },
                .init("Не сейчас", style: .plain)
            ]
        )
    }

    // MARK: - Layout

    // Compositional layout — современный способ описывать сетки.
    // Читается как конструктор: item → group (ряд из 2 плиток) → section.
    private func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),   // плитка = полширины ряда
            heightDimension: .absolute(132)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(132)
        )
        // Ряд из двух плиток с промежутком 12pt.
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        group.interItemSpacing = .fixed(12)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)

        // Заголовок секции — наша карточка прогресса.
        // .estimated: layout сам посчитает высоту из Auto Layout внутри.
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(260)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Combine Bindings

    private func setupBindings() {
        // Слушаем обе публикации сразу: и категории, и стрик.
        // CombineLatest гарантирует, что шапка перерисуется
        // при изменении любого из значений.
        Publishers.CombineLatest(viewModel.$categories, viewModel.$streak)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                collectionView.reloadData()

                // Празднуем переход через 100 баллов.
                let score = viewModel.dayScore.value
                if lastScore >= 0, lastScore < 100, score >= 100 {
                    Haptics.success()
                    showBanner("⚡️ 100 баллов — идеальный день!")
                    DQConfetti.burst(in: tabBarController?.view ?? view)
                }
                lastScore = score

                // Празднуем новый уровень. Уровень считается от суммы
                // очков за всё время (история + сегодня).
                let totalPoints = DataStore.shared.profileStats().totalPointsEarned
                let userLevel = LevelSystem.userLevel(totalPoints: totalPoints)
                let level = userLevel.level
                if lastLevel >= 0, level > lastLevel {
                    Haptics.success()
                    SoundService.play(.levelUp)
                    DQConfetti.burst(in: topMostController().view)
                    DQAlert.present(
                        from: topMostController(),
                        icon: "trophy.fill",
                        iconTint: .systemYellow,
                        title: "Новый уровень!",
                        message: "Ты достиг \(level)-го уровня — «\(userLevel.title)». Так держать!",
                        actions: [.init("Отлично", style: .primary)]
                    )
                }
                lastLevel = level

                // Новые ачивки — поздравляем в момент открытия.
                let newAchievements = AchievementStore.checkForNewUnlocks(
                    stats: DataStore.shared.profileStats()
                )
                if let achievement = newAchievements.first {
                    celebrateAchievement(achievement, extraCount: newAchievements.count - 1)
                }

                // Первая выполненная задача — подходящий момент
                // предложить уведомления: теперь есть что напоминать.
                maybeShowNotificationsPrompt(score: score)
            }
            .store(in: &cancellables)

        // Раз в секунду обновляем обратный отсчёт квеста дня
        // на видимом заголовке (без перезагрузки коллекции).
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let headers = collectionView.visibleSupplementaryViews(
                    ofKind: UICollectionView.elementKindSectionHeader
                )
                for case let header as ScoreHeaderView in headers {
                    header.refreshQuestTimer()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Баннер-уведомление

    private func showBanner(_ text: String) {
        let banner = PaddedLabel()
        banner.insets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        banner.text = text
        banner.font = .systemFont(ofSize: 15, weight: .semibold)
        banner.textColor = .white
        banner.backgroundColor = .systemGreen
        banner.textAlignment = .center
        banner.layer.cornerRadius = 22
        banner.layer.masksToBounds = true
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        view.layoutIfNeeded()

        UIView.animate(withDuration: 0.3) {
            banner.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                banner.alpha = 0
            } completion: { _ in
                banner.removeFromSuperview()
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TodayViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Все категории + плитка «Новая категория» в конце.
        viewModel.categories.count + 1
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Последняя плитка — «добавить».
        if indexPath.item == viewModel.categories.count {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: AddCategoryTileCell.reuseId, for: indexPath
            )
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryTileCell.reuseId, for: indexPath
        ) as! CategoryTileCell
        cell.configure(with: viewModel.categories[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: ScoreHeaderView.reuseId, for: indexPath
        ) as! ScoreHeaderView
        let totalPoints = DataStore.shared.profileStats().totalPointsEarned
        header.configure(
            score: viewModel.dayScore,
            streak: viewModel.streak,
            level: LevelSystem.userLevel(totalPoints: totalPoints),
            plannedPoints: viewModel.totalPlanned,
            hasCategories: !viewModel.categories.isEmpty
        )
        // Тап по пилюле уровня — переключаемся на вкладку «Профиль».
        // Профиль всегда последняя вкладка: берём индекс динамически,
        // чтобы не ломаться при добавлении новых вкладок.
        header.onLevelTap = { [weak self] in
            guard let tabBar = self?.tabBarController else { return }
            tabBar.selectedIndex = (tabBar.viewControllers?.count ?? 1) - 1
        }
        // Тап по пилюле стрика — объяснение правил серии.
        header.onStreakTap = { [weak self] in
            guard let self else { return }
            let streak = viewModel.streak
            let title = streak > 0
                ? "Стрик: \(streak.daysString) подряд"
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
        // Тап по плашке статуса дня — мотивационный алерт.
        header.onStatusTap = { [weak self] in
            guard let self else { return }
            let score = viewModel.dayScore

            let message: String
            if score.value >= 100 {
                message = "Идеальный день собран! Всё, что запланировал, — сделано. Так держать 💪"
            } else if score.value >= AppConfig.streakThreshold {
                message = "День уже в зачёт стрика! Выполняй оставшиеся задачи — до идеального дня ещё \(100 - score.value) баллов."
            } else {
                message = "Выполняй задачи, которые поставил себе на день, — каждая поднимает статус. До зачёта в стрик нужно \(AppConfig.streakThreshold - score.value) баллов, до идеального дня — \(100 - score.value)."
            }

            DQAlert.present(
                from: self,
                icon: "chart.line.uptrend.xyaxis",
                iconTint: score.color,
                title: "\(score.emoji) \(score.label)",
                message: message,
                actions: [.init("За дело!", style: .primary)]
            )
        }
        // Тап по пилюле джокеров — что это и как заработать.
        header.onJokerTap = { [weak self] in
            guard let self else { return }
            let jokers = DataStore.shared.jokers
            DQAlert.present(
                from: self,
                icon: "ticket.fill",
                title: jokers > 0 ? "Джокеры: \(jokers)" : "Джокеров пока нет",
                message: "Джокер спасает стрик: если день провален, серия не оборвётся — приложение само предложит потратить один.\n\nКак получить: один в начале каждой недели и один за каждые \(AppConfig.perfectDaysPerJoker) идеальных дня. В запасе — до \(AppConfig.maxJokers).",
                actions: [.init("Понятно", style: .primary)]
            )
        }
        // Квест дня.
        header.configureQuest()
        header.onQuestToggle = { [weak self, weak header] in
            let delta = DailyQuestCatalog.toggleToday()
            if delta > 0 {
                DataStore.shared.awardBonusXP(delta)
                Haptics.success()
                SoundService.play(.questDone)
                let questStreak = DailyQuestCatalog.streak
                let streakSuffix = questStreak > 1 ? " · серия \(questStreak) 🔥" : ""
                self?.showBanner("🎯 Квест дня выполнен! +\(delta) XP\(streakSuffix)")
            } else if delta < 0 {
                // Снял отметку — честно забираем награду обратно.
                // awardBonusXP с минусом безопасен: XP не уйдёт ниже нуля.
                DataStore.shared.awardBonusXP(delta)
            }
            header?.configureQuest()
        }
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension TodayViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == viewModel.categories.count {
            // Плитка «Новая категория»
            let addVC = AddCategoryViewController(viewModel: viewModel)
            let nav = UINavigationController(rootViewController: addVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
            }
            present(nav, animated: true)
        } else {
            // Плитка категории → экран с задачами
            let category = viewModel.categories[indexPath.item]
            let detailVC = CategoryDetailViewController(category: category, viewModel: viewModel)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    // Долгое нажатие на плитку — контекстное меню с удалением.
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < viewModel.categories.count else { return nil }
        let category = viewModel.categories[indexPath.item]

        return UIContextMenuConfiguration(actionProvider: { _ in
            let pin = UIAction(
                title: category.isPinned ? "Открепить" : "Закрепить",
                image: UIImage(systemName: category.isPinned ? "pin.slash" : "pin")
            ) { [weak self] _ in
                self?.viewModel.togglePinned(category)
            }
            let delete = UIAction(
                title: "Удалить категорию",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete(category)
            }
            return UIMenu(children: [pin, delete])
        })
    }

    private func confirmDelete(_ category: Category) {
        let alert = UIAlertController(
            title: "Удалить «\(category.name)»?",
            message: "Все задачи категории тоже будут удалены",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.viewModel.deleteCategory(category)
        })
        present(alert, animated: true)
    }
}

