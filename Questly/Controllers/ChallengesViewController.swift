//
//  ChallengesViewController.swift
//  Questly
//
//  Челленджи: список (из каталога) и детальный экран недели —
//  индиго-шапка с чипсами дней, секции Пн–Вс с карточками задач.
//  Полное прохождение недели награждается бонусным XP.
//

import UIKit

// MARK: - Список челленджей

final class ChallengesViewController: UIViewController {

    private let challenges = ChallengeCatalog.all

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Челленджи"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChallengeCardCell.self, forCellReuseIdentifier: ChallengeCardCell.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()   // статусы могли измениться на детальном экране
    }
}

extension ChallengesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        challenges.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ChallengeCardCell.reuseId, for: indexPath
        ) as! ChallengeCardCell
        cell.configure(with: challenges[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detailVC = ChallengeDetailViewController(challenge: challenges[indexPath.row])
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Карточка челленджа в списке

final class ChallengeCardCell: UITableViewCell {

    static let reuseId = "ChallengeCardCell"

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = DQColor.challengeSoftAdaptive
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26)
        label.textAlignment = .center
        return label
    }()

    // Кружок-подложка под эмодзи — единый язык с сеткой ачивок.
    private let emojiCircle: UIView = {
        let v = UIView()
        v.backgroundColor = DQColor.card
        v.layer.cornerRadius = 25
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.required, for: .horizontal)
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(16, weight: .semibold)
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = DQColor.challengeDark
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        emojiCircle.addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [emojiCircle, textStack])
        row.axis = .horizontal
        row.spacing = 14
        // .top: заголовки всех карточек на одном уровне независимо
        // от длины описания (при .center они «гуляли» по вертикали).
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

            emojiCircle.widthAnchor.constraint(equalToConstant: 50),
            emojiCircle.heightAnchor.constraint(equalToConstant: 50),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiCircle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiCircle.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» карточки при нажатии: подсветка не мешает didSelectRowAt
    // (переходу в детали челленджа).
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            UIView.animate(withDuration: 0.12,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = CGAffineTransform(scaleX: 0.965, y: 0.965)
            }
        } else {
            UIView.animate(withDuration: 0.4,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = .identity
            }
        }
    }

    func configure(with challenge: Challenge) {
        emojiLabel.text = challenge.emoji
        titleLabel.text = challenge.title
        detailsLabel.text = challenge.details
        statusLabel.text = ChallengeStore.statusLine(for: challenge)
    }
}

// MARK: - Детальный экран челленджа

final class ChallengeDetailViewController: UIViewController {

    private let challenge: Challenge
    private var run: ChallengeRun?

    private static let dayTitles = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var dayChips: [UILabel] = []

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

        tableView.tableHeaderView = makeHeroHeader()
        updateFooter()
    }

    // MARK: - Хиро-шапка с чипсами дней

    private func makeHeroHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0,
                                          width: view.bounds.width, height: 210))
        // Фон — отдельный слой со скруглённым низом, чтобы шапка
        // мягко «стекала» в список, а не обрывалась прямоугольником.
        let bg = UIView()
        bg.backgroundColor = DQColor.challenge
        bg.layer.cornerRadius = 28
        // Скругляем все четыре угла — шапка-карточка.
        bg.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        bg.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(bg)

        let titleLabel = UILabel()
        titleLabel.text = "Челлендж «\(challenge.title)» \(challenge.emoji)"
        titleLabel.font = DQFont.rounded(24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Обещание награды — мотивация прямо в шапке.
        let rewardLabel = UILabel()
        rewardLabel.text = "Пройди до конца — получи +\(Challenge.rewardXP) XP к уровню ⚡️"
        rewardLabel.font = .systemFont(ofSize: 13, weight: .medium)
        rewardLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        rewardLabel.numberOfLines = 0
        rewardLabel.translatesAutoresizingMaskIntoConstraints = false

        // Чипсы дней — кастомные лейблы, а не UIButton: у Configuration
        // свои внутренние паддинги, из-за которых 7 капсул в ряд ужимали
        // текст. Лейбл с фиксированной высотой и тапом даёт чистый контроль.
        let chipsStack = UIStackView()
        chipsStack.axis = .horizontal
        chipsStack.spacing = 6
        chipsStack.distribution = .fillEqually
        chipsStack.translatesAutoresizingMaskIntoConstraints = false

        for (index, day) in Self.dayTitles.enumerated() {
            let chip = UILabel()
            chip.text = day
            chip.font = .systemFont(ofSize: 13, weight: .semibold)
            chip.textAlignment = .center
            chip.textColor = .white
            chip.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            chip.layer.cornerRadius = 16
            chip.layer.masksToBounds = true
            chip.isUserInteractionEnabled = true
            chip.tag = index
            chip.heightAnchor.constraint(equalToConstant: 32).isActive = true
            chip.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(chipTapped(_:)))
            )
            dayChips.append(chip)
            chipsStack.addArrangedSubview(chip)
        }
        highlightTodayChip()

        header.addSubview(titleLabel)
        header.addSubview(rewardLabel)
        header.addSubview(chipsStack)
        NSLayoutConstraint.activate([
            // Фон-карточка с отступами: видны все четыре скругления.
            bg.topAnchor.constraint(equalTo: header.topAnchor, constant: 6),
            bg.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            bg.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            bg.bottomAnchor.constraint(equalTo: header.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: bg.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),

            rewardLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            rewardLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            rewardLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),

            chipsStack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -16),
            chipsStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -18)
        ])
        return header
    }

    private func highlightTodayChip() {
        let today = run.map { min(ChallengeStore.todayIndex(for: $0), 6) }
        for (index, chip) in dayChips.enumerated() {
            let isToday = index == today
            chip.backgroundColor = isToday ? .white : UIColor.white.withAlphaComponent(0.18)
            chip.textColor = isToday ? DQColor.challengeDark : .white
        }
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
        // под серой disabled-кнопкой («Пройден») она выглядела бы грязно.
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
        highlightTodayChip()
        updateFooter()
        tableView.reloadData()
    }

    @objc private func chipTapped(_ sender: UITapGestureRecognizer) {
        guard let section = sender.view?.tag else { return }
        tableView.scrollToRow(
            at: IndexPath(row: 0, section: section),
            at: .top, animated: true
        )
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

// MARK: - Ячейка задачи челленджа

extension ChallengeDetailViewController {

    @objc fileprivate func shareChallenge() {
        Haptics.light()
        let content = ChallengeInvite.shareContent(for: challenge)

        var items: [Any] = [content.text]
        if let data = content.image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Questly — вызов.png")
            try? data.write(to: url)
            items.insert(url, at: 0)
        }
        // Подпись — заранее в буфер (для приложений, берущих только картинку).
        UIPasteboard.general.string = content.text

        let activity = UIActivityViewController(activityItems: items,
                                                applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activity, animated: true)
    }
}

final class ChallengeTaskCell: UITableViewCell {

    static let reuseId = "ChallengeTaskCell"

    enum State {
        case locked    // будущий день или челлендж не начат
        case pending   // можно выполнять
        case done      // выполнено
    }

    private let card: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }()

    private let checkmark: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.tintColor = .white
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [emojiLabel, textStack, checkmark])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» строки при нажатии — тап отмечает задачу дня.
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            UIView.animate(withDuration: 0.12,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            }
        } else {
            UIView.animate(withDuration: 0.4,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = .identity
            }
        }
    }

    func configure(task: ChallengeTask, state: State) {
        emojiLabel.text = task.emoji
        titleLabel.text = task.title
        subtitleLabel.text = task.subtitle

        switch state {
        case .done:
            // Как на макете: выполненная задача — залитая индиго-карточка.
            card.backgroundColor = DQColor.challenge
            titleLabel.textColor = .white
            subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
            checkmark.isHidden = false
            contentView.alpha = 1
        case .pending:
            card.backgroundColor = .secondarySystemGroupedBackground
            titleLabel.textColor = .label
            subtitleLabel.textColor = .secondaryLabel
            checkmark.isHidden = true
            contentView.alpha = 1
        case .locked:
            card.backgroundColor = .secondarySystemGroupedBackground
            titleLabel.textColor = .label
            subtitleLabel.textColor = .secondaryLabel
            checkmark.isHidden = true
            contentView.alpha = 0.45
        }
    }
}

