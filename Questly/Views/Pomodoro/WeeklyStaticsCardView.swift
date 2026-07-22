//
//  WeeklyStatsCardView.swift
//  Questly
//
//  Карточка «Фокус за неделю»: заголовок, график 7 дней,
//  разбор по фокусам и подсказка. Полностью самодостаточна:
//  сама читает PomodoroStats и держит состояние выбранного дня —
//  контроллеру достаточно вызывать refresh().
//

import UIKit

final class WeeklyStatsCardView: UIView {

    // Выбранный день графика (nil — показываем неделю целиком)
    private var selectedDayIndex: Int?

    // MARK: - Сабвью

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = DQFont.rounded(13, weight: .bold)
        l.textColor = DQColor.accentDark
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = DQFont.rounded(20, weight: .bold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Мини-график недели: 7 столбиков ПН–ВС
    private let chartStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.alignment = .fill   // колонки во всю высоту — большая мишень для тапа
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Разбор по фокусам: неделя целиком или выбранный день
    private let breakdownStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let hintLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        dqMakeSquishy()

        [titleLabel, valueLabel, chartStack, breakdownStack, hintLabel]
            .forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            chartStack.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 10),
            chartStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartStack.heightAnchor.constraint(equalToConstant: 56),

            breakdownStack.topAnchor.constraint(equalTo: chartStack.bottomAnchor, constant: 12),
            breakdownStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            breakdownStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            hintLabel.topAnchor.constraint(equalTo: breakdownStack.bottomAnchor, constant: 10),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Обновление

    func refresh() {
        rebuildChart(minutes: PomodoroStats.weekMinutesByDay())

        // Режим одного дня: тап по столбику выбирает день.
        if let index = selectedDayIndex {
            let names = ["Понедельник", "Вторник", "Среда", "Четверг",
                         "Пятница", "Суббота", "Воскресенье"]
            let day = PomodoroStats.weekDetailByDay()[index]
            titleLabel.text = names[index].uppercased()

            valueLabel.text = day.sessions == 0
                ? "Нет сессий"
                : "Сессий: \(day.sessions) · \(PomodoroFormat.timeString(day.minutes))"
            hintLabel.text = "Тапни столбик ещё раз, чтобы вернуться к неделе."
            rebuildBreakdown(PomodoroStats.dayByLabel(index: index))
            return
        }

        // Режим недели.
        let week = PomodoroStats.thisWeek()
        titleLabel.text = "ФОКУС ЗА НЕДЕЛЮ"

        if week.sessions == 0 {
            valueLabel.text = "Пока 0 сессий"
            hintLabel.text = "Запусти таймер и сфокусируйся на одном деле — первая сессия задаст тон неделе."
        } else {
            valueLabel.text = "Сессий: \(week.sessions) · \(PomodoroFormat.timeString(week.minutes))"
            hintLabel.text = "Каждая сессия — +\(AppConfig.pomodoroSessionXP) XP. Тапни столбик — статистика дня."
        }
        rebuildBreakdown(PomodoroStats.weekByLabel())
    }

    // MARK: - График

    // Перестраивает 7 столбиков ПН–ВС. Высота — от максимума недели;
    // пустые дни показываются «пеньком», чтобы сетка недели читалась.
    private func rebuildChart(minutes: [Int]) {
        chartStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let maxMinutes = max(minutes.max() ?? 0, 1)
        let letters = ["П", "В", "С", "Ч", "П", "С", "В"]
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7

        for (index, value) in minutes.enumerated() {
            // Подсветка: выбранный день главнее «сегодня».
            let isSelected = index == selectedDayIndex
            let isToday = index == todayIndex && selectedDayIndex == nil

            let bar = UIView()
            bar.layer.cornerRadius = 3
            bar.backgroundColor = (isSelected || isToday)
                ? DQColor.accentAdaptive
                : DQColor.accentSoftAdaptive
            bar.translatesAutoresizingMaskIntoConstraints = false

            let letter = UILabel()
            letter.text = letters[index]
            letter.font = DQFont.rounded(10, weight: isSelected ? .bold : .medium)
            letter.textColor = (isSelected || isToday) ? DQColor.accentDark : .tertiaryLabel
            letter.textAlignment = .center

            // Прозрачный спейсер растягивает колонку на всю высоту:
            // по пустому дню («пеньку» 4pt) иначе не попасть пальцем.
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

            let column = UIStackView(arrangedSubviews: [spacer, bar, letter])
            column.axis = .vertical
            column.spacing = 3
            column.alignment = .fill
            column.tag = index
            column.isUserInteractionEnabled = true
            column.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(dayColumnTapped(_:)))
            )

            // 40pt под столбик: минимум 4 («пенёк»), максимум — полная высота.
            let height = value == 0 ? 4 : max(6, CGFloat(value) / CGFloat(maxMinutes) * 40)
            bar.heightAnchor.constraint(equalToConstant: height).isActive = true

            chartStack.addArrangedSubview(column)
        }
    }

    @objc private func dayColumnTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        Haptics.light()
        // Повторный тап по выбранному — назад к неделе.
        selectedDayIndex = (selectedDayIndex == index) ? nil : index
        refresh()
    }

    // MARK: - Разбор по фокусам

    /// Строки «по фокусам»: топ-5, остальное — одной строкой «и ещё N».
    private func rebuildBreakdown(_ items: [(label: String, sessions: Int, minutes: Int)]) {
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !items.isEmpty else { return }

        for item in items.prefix(5) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8

            let name = UILabel()
            name.text = "•  \(item.label)"
            name.font = .systemFont(ofSize: 13, weight: .medium)
            name.textColor = .label
            name.adjustsFontSizeToFitWidth = true
            name.minimumScaleFactor = 0.75

            let value = UILabel()
            value.text = "\(PomodoroFormat.timeString(item.minutes)) · \(item.sessions)"
            value.font = .systemFont(ofSize: 13, weight: .medium)
            value.textColor = .secondaryLabel
            value.textAlignment = .right
            value.setContentCompressionResistancePriority(.required, for: .horizontal)
            value.setContentHuggingPriority(.required, for: .horizontal)

            row.addArrangedSubview(name)
            row.addArrangedSubview(value)
            breakdownStack.addArrangedSubview(row)
        }

        if items.count > 5 {
            let more = UILabel()
            more.text = "и ещё \(items.count - 5)"
            more.font = .systemFont(ofSize: 12)
            more.textColor = .tertiaryLabel
            breakdownStack.addArrangedSubview(more)
        }
    }
}

