//
//  MonthCalendarView.swift
//  Questly
//
//  Календарь месяца: шапка «← Июль 2026 →», ряд дней недели и
//  сетка 7×N с окрашенными по баллам днями. Полностью автономен:
//  сам считает метрики месяца и переключает месяцы; наружу отдаёт
//  выбранный день колбэком onSelectDay. Балл дня и запись за день
//  запрашивает у контроллера через провайдеры (calendar не знает
//  про DataStore напрямую — это оставляет его переиспользуемым).
//

import UIKit

final class MonthCalendarView: UIView {

    /// Тап по дню (со всей вычисленной датой)
    var onSelectDay: ((Date) -> Void)?
    /// Балл дня: сегодня считается вживую, прошлое — из истории.
    var scoreProvider: ((Date) -> Int?)?

    // MARK: - Календарь и метрики

    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2   // понедельник
        return cal
    }()

    private lazy var monthStart: Date = currentMonthStart

    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
    }

    private var daysInMonth = 30
    private var leadingBlanks = 0

    private let cellSize: CGFloat = 42
    private let cellSpacing: CGFloat = 4
    private var gridWidth: CGFloat { cellSize * 7 + cellSpacing * 6 }

    // MARK: - Сабвью

    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private lazy var prevButton = makeChevron("chevron.left", #selector(prevMonth))
    private lazy var nextButton = makeChevron("chevron.right", #selector(nextMonth))

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: cellSize, height: cellSize)
        layout.minimumInteritemSpacing = cellSpacing
        layout.minimumLineSpacing = cellSpacing
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.delaysContentTouches = false   // мгновенный «жмяк» дня
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(HistoryDayCell.self, forCellWithReuseIdentifier: HistoryDayCell.reuseId)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    private var collectionHeight: NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let headerStack = UIStackView(arrangedSubviews: [prevButton, monthLabel, nextButton])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false

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

        [headerStack, weekdayStack, collectionView].forEach { addSubview($0) }
        collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: 300)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor),
            headerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            monthLabel.widthAnchor.constraint(equalToConstant: 180),

            weekdayStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 20),
            weekdayStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            weekdayStack.widthAnchor.constraint(equalToConstant: gridWidth),

            collectionView.topAnchor.constraint(equalTo: weekdayStack.bottomAnchor, constant: 8),
            collectionView.centerXAnchor.constraint(equalTo: centerXAnchor),
            collectionView.widthAnchor.constraint(equalToConstant: gridWidth),
            collectionHeight,
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - API

    /// Пересобрать сетку (после смены данных или месяца)
    func reload() {
        daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count

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

    // MARK: - Helpers

    private func date(forItem item: Int) -> Date? {
        let day = item - leadingBlanks + 1
        guard day >= 1, day <= daysInMonth else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    private func makeChevron(_ symbol: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func prevMonth() {
        monthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        reload()
    }

    @objc private func nextMonth() {
        monthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        reload()
    }
}

// MARK: - DataSource / Delegate

extension MonthCalendarView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
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
            cell.configure(day: day, score: scoreProvider?(date), isToday: true)
        } else if date > today {
            cell.configure(day: day, score: nil, isToday: false, isFuture: true)
        } else {
            cell.configure(day: day, score: scoreProvider?(date), isToday: false)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = date(forItem: indexPath.item) else { return }
        onSelectDay?(date)
    }
}
