//
//  HistoryViewController.swift
//  Questly
//
//  Экран «История» — тонкий контроллер-сборщик. Календарь месяца,
//  ячейка дня и логика «поделиться» вынесены в компоненты
//  (Views/History/). Здесь: карточка деталей выбранного дня,
//  карточка статьи дня, карточки-планы и роутинг.
//

import UIKit
import Combine

final class HistoryViewController: UIViewController {

    // MARK: - Данные

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    private var recordsByDate: [Date: DayRecord] = [:]

    // MARK: - Компоненты

    private let calendarView = MonthCalendarView()

    private let weekPlanCard = NavCardView(
        symbol: "calendar.day.timeline.left",
        tint: DQColor.accentAdaptive, soft: DQColor.accentSoftAdaptive,
        title: "План на неделю")

    private let monthPlanCard = NavCardView(
        symbol: "list.bullet.clipboard",
        tint: DQColor.accentAdaptive, soft: DQColor.accentSoftAdaptive,
        title: "План на месяц")

    // MARK: - UI: детали дня

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

    private let plansFootnote: UILabel = {
        let l = UILabel()
        l.text = "Выпиши дела без точной даты сейчас — а когда день определится, перенеси в календарь свайпом за два клика."
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

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

        card.dqMakePressable()
        card.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(openArticleOfTheDay)))
        return card
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "История"
        view.backgroundColor = .systemGroupedBackground
        setupNavItems()
        setupViews()
        wireComponents()

        let article = ArticleCatalog.articleOfTheDay
        articleTitleLabel.text = "\(article.emoji) \(article.title)"
        articleMetaLabel.text = ArticleReadStore.isRead(article.id)
            ? "\(article.subtitle) · прочитано ✓"
            : "\(article.subtitle) · \(article.readMinutes) мин"

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

    private func setupNavItems() {
        let shareMenu = UIMenu(children: [
            UIAction(title: "Поделиться отчётом",
                     image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self else { return }
                WeekShareService.share(from: self,
                                       anchor: navigationItem.rightBarButtonItems?.first)
            },
            UIAction(title: "Скопировать текст со ссылкой",
                     image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                WeekShareService.copyText()
                self?.showToast("Текст со ссылкой скопирован ✨")
            }
        ])
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), menu: shareMenu),
            UIBarButtonItem(image: UIImage(systemName: "book"), style: .plain,
                            target: self, action: #selector(openAllArticles))
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet.clipboard"),
            style: .plain, target: self, action: #selector(openMonthPlan))
    }

    private func setupViews() {
        detailCard.addSubview(detailLabel)

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        [calendarView, detailCard, articleCard, weekPlanCard, monthPlanCard, plansFootnote]
            .forEach { scrollView.addSubview($0) }

        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            calendarView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            calendarView.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            calendarView.leadingAnchor.constraint(greaterThanOrEqualTo: frame.leadingAnchor, constant: 16),

            detailCard.topAnchor.constraint(equalTo: calendarView.bottomAnchor, constant: 20),
            detailCard.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            detailCard.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: detailCard.topAnchor, constant: 14),
            detailLabel.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: -14),

            articleCard.topAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: 12),
            articleCard.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            articleCard.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),

            weekPlanCard.topAnchor.constraint(equalTo: articleCard.bottomAnchor, constant: 12),
            weekPlanCard.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            weekPlanCard.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),

            monthPlanCard.topAnchor.constraint(equalTo: weekPlanCard.bottomAnchor, constant: 12),
            monthPlanCard.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            monthPlanCard.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),

            plansFootnote.topAnchor.constraint(equalTo: monthPlanCard.bottomAnchor, constant: 10),
            plansFootnote.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 32),
            plansFootnote.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -32),
            plansFootnote.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func wireComponents() {
        // Балл: сегодня — вживую, прошлое — из истории.
        calendarView.scoreProvider = { [weak self] date in
            guard let self else { return nil }
            let today = calendar.startOfDay(for: Date())
            if date == today { return todayScore }
            return recordsByDate[date]?.score
        }
        calendarView.onSelectDay = { [weak self] date in self?.daySelected(date) }

        weekPlanCard.onTap = { [weak self] in
            self?.navigationController?.pushViewController(WeekPlanViewController(), animated: true)
        }
        monthPlanCard.onTap = { [weak self] in
            self?.navigationController?.pushViewController(MonthPlanViewController(), animated: true)
        }
    }

    // MARK: - Выбор дня

    private func daySelected(_ date: Date) {
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
            if record.penaltyPoints > 0 { text += " · штраф −\(record.penaltyPoints) XP" }
            detailLabel.text = text
        } else {
            detailLabel.text = "\(dateStr) — нет данных за этот день"
        }

        let dayVC = DayPlanViewController(day: date)
        let nav = UINavigationController(rootViewController: dayVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    // MARK: - Данные

    private func reloadData() {
        recordsByDate = Dictionary(
            store.fetchRecords().map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        calendarView.reload()
    }

    private var todayScore: Int {
        let earned = store.fetchCategories().reduce(0) { $0 + $1.earnedPoints }
        return DayScore(earnedPoints: earned).value
    }

    private func refreshPlanCards() {
        let week = DataStore.shared.fetchWeekPlan(for: Date())
        let weekOverdue = DataStore.shared.fetchOverdueWeekPlan(before: Date())
        let weekPending = week.filter { !$0.isDone }.count + weekOverdue.count
        weekPlanCard.setSubtitle(weekPending == 0
            ? "Дела недели без точного дня"
            : "Осталось дел: \(weekPending)")

        let month = DataStore.shared.fetchMonthPlan(for: Date())
        let monthOverdue = DataStore.shared.fetchOverdueMonthPlan(before: Date())
        let monthPending = month.filter { !$0.isDone }.count + monthOverdue.count
        monthPlanCard.setSubtitle(monthPending == 0
            ? "Дела месяца без точной даты"
            : "Осталось дел: \(monthPending)")
    }

    // MARK: - Actions

    @objc private func openArticleOfTheDay() {
        navigationController?.pushViewController(
            ArticleViewController(article: ArticleCatalog.articleOfTheDay), animated: true)
    }

    @objc private func openAllArticles() {
        navigationController?.pushViewController(ArticlesListViewController(), animated: true)
    }

    @objc private func openMonthPlan() {
        navigationController?.pushViewController(MonthPlanViewController(), animated: true)
    }

    // MARK: - Toast

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
}
