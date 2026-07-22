//
//  HistoryViewController.swift
//  Questly
//
//  Экран «История»: календарь месяца, где каждый день окрашен
//  по набранным баллам (как сетка контрибуций на GitHub).
//  Тап по дню показывает детали внизу.
//

import UIKit
import Combine

final class HistoryViewController: UIViewController {

    // MARK: - Данные

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    // Записи истории, сгруппированные по дате (startOfDay).
    private var recordsByDate: [Date: DayRecord] = [:]

    // Календарь с понедельником как первым днём недели.
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    // Первое число отображаемого месяца.
    private lazy var monthStart: Date = currentMonthStart

    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
    }

    // Метрики сетки текущего месяца.
    private var daysInMonth = 30
    private var leadingBlanks = 0   // пустые ячейки до 1-го числа

    // Размеры сетки: 7 колонок по 42pt с промежутком 4pt.
    private let cellSize: CGFloat = 42
    private let cellSpacing: CGFloat = 4
    private var gridWidth: CGFloat { cellSize * 7 + cellSpacing * 6 }

    // MARK: - UI элементы

    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private lazy var prevButton = makeChevronButton("chevron.left", action: #selector(prevMonth))
    private lazy var nextButton = makeChevronButton("chevron.right", action: #selector(nextMonth))

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: cellSize, height: cellSize)
        layout.minimumInteritemSpacing = cellSpacing
        layout.minimumLineSpacing = cellSpacing
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        // Мгновенная подсветка при тапе — иначе «жмяк» дня не виден.
        cv.delaysContentTouches = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(HistoryDayCell.self, forCellWithReuseIdentifier: HistoryDayCell.reuseId)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    // Высота сетки меняется от месяца к месяцу (5 или 6 рядов).
    private var collectionHeight: NSLayoutConstraint!

    private let detailCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Выбери день, чтобы посмотреть детали"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - UI: статья дня

    private let articleTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        return label
    }()

    private let articleMetaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    // Скролл всего экрана: с карточками планов контент выше экрана.
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let weekPlanSubtitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        return l
    }()

    private let monthPlanSubtitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        return l
    }()

    // Карточка-вход в план недели/месяца — стиль карточек профиля.
    private func makePlanCard(symbol: String, title: String,
                              subtitle: UILabel, action: Selector) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = DQIcon.circle(
            symbol: symbol,
            tint: DQColor.accentAdaptive,
            soft: DQColor.accentSoftAdaptive
        )

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DQFont.rounded(15, weight: .semibold)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        card.dqMakePressable()
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        return card
    }

    // Подсказка под планами: объясняет идею «выписал сейчас —
    // за два клика перенёс в календарь, когда день определился».
    private let plansFootnote: UILabel = {
        let l = UILabel()
        l.text = "Выпиши дела без точной даты сейчас — а когда день определится, перенеси в календарь свайпом за два клика."
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var weekPlanCard = makePlanCard(
        symbol: "calendar.day.timeline.left",
        title: "План на неделю",
        subtitle: weekPlanSubtitle,
        action: #selector(openWeekPlan)
    )

    private lazy var monthPlanCard = makePlanCard(
        symbol: "list.bullet.clipboard",
        title: "План на месяц",
        subtitle: monthPlanSubtitle,
        action: #selector(openMonthPlanCard)
    )

    private lazy var articleCard: UIView = {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.attributedText = .withIcon(
            "book.fill", text: "СТАТЬЯ ДНЯ",
            font: DQFont.rounded(11, weight: .bold), color: DQColor.accentDark
        )
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = DQColor.accentDark

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [badge, articleTitleLabel, articleMetaLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let row = UIStackView(arrangedSubviews: [textStack, chevron])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(openArticleOfTheDay))
        card.addGestureRecognizer(tap)
        return card
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "История"
        view.backgroundColor = .systemGroupedBackground

        // Справа: поделиться неделей (меню) + архив статей.
        let shareMenu = UIMenu(children: [
            UIAction(title: "Поделиться отчётом",
                     image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareWeek()
            },
            UIAction(title: "Скопировать текст со ссылкой",
                     image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                self?.copyShareText()
            }
        ])
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                menu: shareMenu
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "book"),
                style: .plain,
                target: self,
                action: #selector(openAllArticles)
            )
        ]
        // Планировщик месяца — дела без точной даты.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet.clipboard"),
            style: .plain,
            target: self,
            action: #selector(openMonthPlan)
        )

        setupViews()

        // Заполняем карточку статьи дня.
        let article = ArticleCatalog.articleOfTheDay
        articleTitleLabel.text = "\(article.emoji) \(article.title)"
        articleMetaLabel.text = ArticleReadStore.isRead(article.id)
            ? "\(article.subtitle) · прочитано ✓"
            : "\(article.subtitle) · \(article.readMinutes) мин"

        // Обновляемся при любых изменениях данных
        // (например, отметили задачу на вкладке «Сегодня»).
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reloadData() }
            .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPlanCards()
        reloadData()
    }

    // MARK: - Setup

    private func setupViews() {
        // Шапка: ← Июль 2026 →
        let headerStack = UIStackView(arrangedSubviews: [prevButton, monthLabel, nextButton])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Ряд с днями недели: Пн Вт Ср Чт Пт Сб Вс
        let weekdayStack = UIStackView(
            arrangedSubviews: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].map { day in
                let label = UILabel()
                label.text = day
                label.font = .systemFont(ofSize: 11, weight: .medium)
                label.textColor = .tertiaryLabel
                label.textAlignment = .center
                return label
            }
        )
        weekdayStack.axis = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.translatesAutoresizingMaskIntoConstraints = false

        detailCard.addSubview(detailLabel)

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        [headerStack, weekdayStack, collectionView, detailCard, articleCard,
         weekPlanCard, monthPlanCard, plansFootnote].forEach { scrollView.addSubview($0) }

        collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: 300)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            headerStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            monthLabel.widthAnchor.constraint(equalToConstant: 180),

            weekdayStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 20),
            weekdayStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            weekdayStack.widthAnchor.constraint(equalToConstant: gridWidth),

            collectionView.topAnchor.constraint(equalTo: weekdayStack.bottomAnchor, constant: 8),
            collectionView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            collectionView.widthAnchor.constraint(equalToConstant: gridWidth),
            collectionHeight,

            detailCard.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
            detailCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            detailCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: detailCard.topAnchor, constant: 14),
            detailLabel.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: -14),

            articleCard.topAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: 12),
            articleCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            articleCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            // Планы недели и месяца — под статьёй дня.
            weekPlanCard.topAnchor.constraint(equalTo: articleCard.bottomAnchor, constant: 12),
            weekPlanCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            weekPlanCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            monthPlanCard.topAnchor.constraint(equalTo: weekPlanCard.bottomAnchor, constant: 12),
            monthPlanCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            monthPlanCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            plansFootnote.topAnchor.constraint(equalTo: monthPlanCard.bottomAnchor, constant: 10),
            plansFootnote.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 32),
            plansFootnote.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -32),

            // Низ подписи замыкает contentSize скролла.
            plansFootnote.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func openArticleOfTheDay() {
        let reader = ArticleViewController(article: ArticleCatalog.articleOfTheDay)
        navigationController?.pushViewController(reader, animated: true)
    }

    // Копирует подпись со ссылкой в буфер — гарантированный путь
    // для текста (системный Copy в шторке берёт только картинку).
    private func copyShareText() {
        UIPasteboard.general.string = WeeklyReport.shareContent().text
        Haptics.success()
        showToast("Текст со ссылкой скопирован ✨")
    }

    private func showToast(_ text: String) {
        let toast = PaddedLabel()
        toast.text = text
        toast.font = DQFont.rounded(14, weight: .semibold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toast.layer.cornerRadius = 18
        toast.layer.masksToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
        UIView.animate(withDuration: 0.25) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    // Поделиться результатом недели: рендерим карточку и отдаём
    // в системный share sheet (соцсети, мессенджеры, сохранение).
    private func shareWeek() {
        Haptics.light()
        let content = WeeklyReport.shareContent()

        // Делимся ФАЙЛОМ, а не голым UIImage: файлу шторка гарантированно
        // рисует превью и имя, Copy/Сохранить работают предсказуемо.
        var items: [Any] = [content.text]
        if let data = content.image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Questly — моя неделя.png")
            try? data.write(to: url)
            items.insert(url, at: 0)
        }

        let activity = UIActivityViewController(activityItems: items,
                                                applicationActivities: nil)
        // На iPad share sheet требует якорь-поповер.
        activity.popoverPresentationController?.barButtonItem =
            navigationItem.rightBarButtonItems?.first
        // Подпись дублируем в буфер заранее: в приложениях, которые
        // берут только картинку, текст можно просто вставить.
        UIPasteboard.general.string = content.text
        present(activity, animated: true)
    }

    @objc private func openWeekPlan() {
        navigationController?.pushViewController(WeekPlanViewController(), animated: true)
    }

    @objc private func openMonthPlanCard() {
        navigationController?.pushViewController(MonthPlanViewController(), animated: true)
    }

    private func refreshPlanCards() {
        let week = DataStore.shared.fetchWeekPlan(for: Date())
        let weekOverdue = DataStore.shared.fetchOverdueWeekPlan(before: Date())
        let weekPending = week.filter { !$0.isDone }.count + weekOverdue.count
        weekPlanSubtitle.text = weekPending == 0
            ? "Дела недели без точного дня"
            : "Осталось дел: \(weekPending)"

        let month = DataStore.shared.fetchMonthPlan(for: Date())
        let monthOverdue = DataStore.shared.fetchOverdueMonthPlan(before: Date())
        let monthPending = month.filter { !$0.isDone }.count + monthOverdue.count
        monthPlanSubtitle.text = monthPending == 0
            ? "Дела месяца без точной даты"
            : "Осталось дел: \(monthPending)"
    }

    @objc private func openMonthPlan() {
        navigationController?.pushViewController(MonthPlanViewController(), animated: true)
    }

    @objc private func openAllArticles() {
        navigationController?.pushViewController(ArticlesListViewController(), animated: true)
    }

    private func makeChevronButton(_ symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Данные и обновление

    private func reloadData() {
        // Собираем словарь [дата: запись] для быстрого поиска.
        recordsByDate = Dictionary(
            store.fetchRecords().map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        updateMonth()
    }

    private func updateMonth() {
        daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count

        // Сколько пустых ячеек до 1-го числа месяца:
        // weekday: 1 = воскресенье ... 7 = суббота, наш первый день — понедельник (2).
        let weekday = calendar.component(.weekday, from: monthStart)
        leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7

        let rows = Int(ceil(Double(leadingBlanks + daysInMonth) / 7.0))
        collectionHeight.constant = CGFloat(rows) * (cellSize + cellSpacing) - cellSpacing

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        monthLabel.text = formatter.string(from: monthStart).capitalizedFirst

        nextButton.isEnabled = monthStart < currentMonthStart

        collectionView.reloadData()
    }

    // Балл сегодняшнего дня считаем «вживую» — записи за сегодня ещё нет.
    private var todayScore: Int {
        let earned = store.fetchCategories().reduce(0) { $0 + $1.earnedPoints }
        return DayScore(earnedPoints: earned).value
    }

    private func date(forItem item: Int) -> Date? {
        let day = item - leadingBlanks + 1
        guard day >= 1, day <= daysInMonth else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    // MARK: - Actions

    @objc private func prevMonth() {
        monthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        updateMonth()
    }

    @objc private func nextMonth() {
        monthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        updateMonth()
    }
}

// MARK: - UICollectionViewDataSource

extension HistoryViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        leadingBlanks + daysInMonth
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HistoryDayCell.reuseId, for: indexPath
        ) as! HistoryDayCell

        guard let date = date(forItem: indexPath.item) else {
            cell.configureEmpty()
            return cell
        }

        let today = calendar.startOfDay(for: Date())
        let day = calendar.component(.day, from: date)

        if date == today {
            cell.configure(day: day, score: todayScore, isToday: true)
        } else if date > today {
            cell.configure(day: day, score: nil, isToday: false, isFuture: true)
        } else {
            cell.configure(day: day, score: recordsByDate[date]?.score, isToday: false)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension HistoryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = date(forItem: indexPath.item) else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let dateStr = formatter.string(from: date)

        let today = calendar.startOfDay(for: Date())

        if date == today {
            let score = DayScore(value: todayScore)
            detailLabel.text = "Сегодня: \(score.value) баллов \(score.emoji) — день ещё идёт"
        } else if date > today {
            detailLabel.text = "\(dateStr) — впереди. Можно запланировать дела"
        } else if let record = recordsByDate[date] {
            let score = DayScore(value: record.score)
            var text = "\(dateStr): \(record.score) баллов \(score.emoji) · " +
                "задач выполнено \(record.completedTasks) из \(record.totalTasks)"
            if record.penaltyPoints > 0 {
                text += " · штраф −\(record.penaltyPoints) XP"
            }
            detailLabel.text = text
        } else {
            detailLabel.text = "\(dateStr) — нет данных за этот день"
        }

        // Тап по дню открывает его лист: план на будущее/сегодня,
        // просмотр запланированного на прошлое.
        let dayVC = DayPlanViewController(day: date)
        let nav = UINavigationController(rootViewController: dayVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }
}

// MARK: - HistoryDayCell

final class HistoryDayCell: UICollectionViewCell {

    static let reuseId = "HistoryDayCell"

    // Вся отрисовка — на внутреннем tile: его можно безопасно
    // «жмякать» трансформацией. contentView трогать нельзя —
    // layout коллекции владеет его геометрией (уроки плиток категорий).
    private let tile: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(tile)
        tile.addSubview(label)
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor),
            tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            label.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» дня при нажатии: прожимается tile, не contentView.
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1,
                               delay: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                }
            } else {
                UIView.animate(withDuration: 0.35,
                               delay: 0,
                               usingSpringWithDamping: 0.5,
                               initialSpringVelocity: 5,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = .identity
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tile.transform = .identity
    }

    func configure(day: Int, score: Int?, isToday: Bool, isFuture: Bool = false) {
        label.text = "\(day)"

        if let score, score > 0 {
            // Чем выше балл — тем насыщеннее цвет (как у GitHub contributions).
            let color = DayScore(value: score).color
            tile.backgroundColor = color.withAlphaComponent(0.2 + 0.5 * CGFloat(score) / 100)
            label.textColor = .label
        } else {
            tile.backgroundColor = .secondarySystemGroupedBackground
            label.textColor = isFuture ? .quaternaryLabel : .secondaryLabel
        }

        // Сегодняшний день обводим рамкой.
        tile.layer.borderWidth = isToday ? 1.5 : 0
        tile.layer.borderColor = UIColor.label
            .resolvedColor(with: traitCollection).cgColor
    }

    func configureEmpty() {
        label.text = ""
        tile.backgroundColor = .clear
        tile.layer.borderWidth = 0
    }
}
