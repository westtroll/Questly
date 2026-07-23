//
//  ChallengeDetailViewController.swift
//  Questly
//
//  Детальный экран челленджа: индиго-шапка с чипсами дней,
//  секции Пн–Вс с карточками задач и плавающая нижняя панель
//  со стартом. Полное прохождение недели даёт бонусный XP.
//

import UIKit

final class ChallengeDetailViewController: UIViewController {

    private let challenge: Challenge
    private var run: ChallengeRun?

    private static let dayTitles = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var heroHeader: ChallengeHeroHeaderView?

    // MARK: - UI

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // Плавающая панель снизу — держит кнопку старта поверх скролла.
    private lazy var bottomBar: UIView = {
        let bar = UIView()
        bar.backgroundColor = .systemGroupedBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        // Тонкая разделительная линия сверху — визуально отделяет
        // панель от прокручиваемого под ней списка.
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return bar
    }()

    private lazy var startButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.baseBackgroundColor = DQColor.challenge
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "flag.checkered")
        config.imagePadding = 8
        config.imagePlacement = .leading
        // Жирный, чуть крупнее — кнопка-призыв должна звать.
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            return attrs
        }
        let button = UIButton(configuration: config)

        // Мягкая индиго-тень — кнопка «приподнимается» над панелью.
        button.layer.shadowColor = DQColor.challenge.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 4)

        // Микро-анимация нажатия: кнопка слегка «проседает».
        button.addAction(UIAction { _ in
            UIView.animate(withDuration: 0.12) {
                button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
        }, for: .touchDown)
        let liftBack = UIAction { _ in
            UIView.animate(withDuration: 0.12) { button.transform = .identity }
        }
        button.addAction(liftBack, for: .touchUpInside)
        button.addAction(liftBack, for: .touchUpOutside)
        button.addAction(liftBack, for: .touchCancel)

        button.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    init(challenge: Challenge) {
        self.challenge = challenge
        self.run = ChallengeStore.run(for: challenge.id)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        // «Бросить вызов другу»: карточка-приглашение через share sheet.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareChallenge)
        )

        view.addSubview(tableView)
        view.addSubview(bottomBar)
        bottomBar.addSubview(startButton)
        startButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Плавающая панель с кнопкой — прибита к низу поверх таблицы.
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            startButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 10),
            startButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            startButton.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            startButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChallengeTaskCell.self, forCellReuseIdentifier: ChallengeTaskCell.reuseId)

        setupHeader()
        updateFooter()
    }

    private func setupHeader() {
        let header = ChallengeHeroHeaderView(challenge: challenge, width: view.bounds.width)
        header.onSelectDay = { [weak self] section in
            self?.tableView.scrollToRow(
                at: IndexPath(row: 0, section: section), at: .top, animated: true)
        }
        heroHeader = header
        tableView.tableHeaderView = header
        refreshTodayChip()
    }

    private func refreshTodayChip() {
        heroHeader?.highlightToday(run.map { min(ChallengeStore.todayIndex(for: $0), 6) })
    }

    // MARK: - Нижняя панель: старт / рестарт / результат

    private func updateFooter() {
        var config = startButton.configuration

        if let run {
            if ChallengeStore.isFullyCompleted(challenge, run: run) {
                config?.title = "🏅 Челлендж пройден!"
                startButton.isEnabled = false
                bottomBar.isHidden = false
            } else if ChallengeStore.isExpired(run) {
                config?.title = "Начать заново (эта неделя)"
                startButton.isEnabled = true
                bottomBar.isHidden = false
            } else {
                // Челлендж идёт — панель не нужна, прячем целиком.
                bottomBar.isHidden = true
            }
        } else {
            config?.title = "Начать челлендж (эта неделя)"
            startButton.isEnabled = true
            bottomBar.isHidden = false
        }
        startButton.configuration = config

        // Индиго-тень уместна только у активной кнопки-призыва;
        // под серой disabled-кнопкой она выглядела бы грязно.
        startButton.layer.shadowOpacity = startButton.isEnabled ? 0.35 : 0

        // Когда панель видна — резервируем место снизу в таблице,
        // чтобы последняя задача не пряталась под кнопкой.
        tableView.contentInset.bottom = bottomBar.isHidden ? 0 : 76
        tableView.verticalScrollIndicatorInsets.bottom = bottomBar.isHidden ? 0 : 76
    }

    // MARK: - Actions

    @objc private func startTapped() {
        run = ChallengeStore.start(challenge)
        Haptics.success()
        refreshTodayChip()
        updateFooter()
        tableView.reloadData()
    }

    @objc private func shareChallenge() {
        Haptics.light()
        let content = ChallengeInvite.shareContent(for: challenge)
        ShareSheet.present(from: self,
                           image: content.image,
                           text: content.text,
                           fileName: "Questly — вызов.png",
                           anchor: navigationItem.rightBarButtonItem)
    }

    // Права на отметку: челлендж начат, день не в будущем, неделя не прошла.
    private func canToggle(day: Int) -> Bool {
        guard let run else { return false }
        let today = ChallengeStore.todayIndex(for: run)
        return today <= 6 && day <= today
    }

    private func cellState(day: Int, task: Int) -> ChallengeTaskCell.State {
        guard let run else { return .locked }
        if run.isCompleted(day: day, task: task) { return .done }
        return canToggle(day: day) ? .pending : .locked
    }
}

// MARK: - Таблица дней

extension ChallengeDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        challenge.days.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        challenge.days[section].count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let day = Self.dayTitles[section]
        if let run, min(ChallengeStore.todayIndex(for: run), 7) == section {
            return "\(day) — Сегодня"
        }
        return day
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ChallengeTaskCell.reuseId, for: indexPath
        ) as! ChallengeTaskCell
        cell.configure(
            task: challenge.days[indexPath.section][indexPath.row],
            state: cellState(day: indexPath.section, task: indexPath.row)
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard var run, canToggle(day: indexPath.section) else { return }

        // Запоминаем состояние дня ДО отметки — похвала показывается
        // только на переходе «день стал выполнен», а не на каждый тап.
        let dayWasComplete = isDayCompleted(indexPath.section, run: run)

        run.toggle(day: indexPath.section, task: indexPath.row)
        Haptics.light()

        let challengeCompleted = ChallengeStore.isFullyCompleted(challenge, run: run)

        // Награда за полное прохождение — один раз.
        if !run.rewarded, challengeCompleted {
            run.rewarded = true
            DataStore.shared.awardBonusXP(Challenge.rewardXP)
            Haptics.success()

            DQAlert.present(
                from: self,
                icon: "flag.checkered",
                title: "Челлендж пройден!",
                message: "Неделя «\(challenge.title)» позади. Награда: +\(Challenge.rewardXP) XP",
                actions: [.init("Ура!", style: .primary)]
            )

        } else if !dayWasComplete,
                  isDayCompleted(indexPath.section, run: run),
                  !challengeCompleted {
            // День закрыт (и это не финал челленджа — его алерт важнее).
            Haptics.success()
            showDayPraise()
        }

        self.run = run
        ChallengeStore.save(run)
        tableView.reloadRows(at: [indexPath], with: .none)
        updateFooter()
    }

    // Все ли задачи дня отмечены
    private func isDayCompleted(_ day: Int, run: ChallengeRun) -> Bool {
        challenge.days[day].indices.allSatisfy { run.isCompleted(day: day, task: $0) }
    }

    // Похвала за закрытый день. Тексты варьируются,
    // чтобы не приедаться за неделю.
    private func showDayPraise() {
        let praises: [(icon: String, title: String, message: String)] = [
            ("flame.fill", "Ты круто справляешься!",
             "Все задачи дня выполнены. Завтра будет ещё интереснее"),
            ("bolt.fill", "Вот это дисциплина!",
             "Так держать — привычки строятся именно из таких дней"),
            ("star.fill", "День закрыт!",
             "Ещё один шаг к цели. Увидимся завтра!")
        ]
        let praise = praises.randomElement()!

        DQAlert.present(
            from: self,
            icon: praise.icon,
            title: praise.title,
            message: praise.message,
            actions: [.init("Продолжить", style: .primary)]
        )
    }
}
