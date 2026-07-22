//
//  MoodInsightsViewController.swift
//  Questly
//
//  «Настроение × продуктивность»: склеивает отметки настроения
//  с баллами дней и показывает связь — главный инсайт словами
//  («в хорошие дни ты набираешь на N% больше») и разбивку
//  среднего балла по каждому настроению.
//

import UIKit

final class MoodInsightsViewController: UIViewController {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настроение × продуктивность"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])

        buildContent()
    }

    // MARK: - Данные

    /// Пары «настроение — балл дня», склеенные по дате.
    private func pairs() -> [(mood: Int, score: Int)] {
        let store = DataStore.shared
        let calendar = Calendar.current

        // Баллы прошлых дней — из истории; сегодняшний — живой.
        var scoreByDay: [Date: Int] = [:]
        for record in store.fetchRecords() {
            scoreByDay[record.date] = record.score
        }
        let today = calendar.startOfDay(for: Date())
        let earnedToday = store.fetchCategories().reduce(0) { $0 + $1.earnedPoints }
        if earnedToday > 0 {
            scoreByDay[today] = DayScore(earnedPoints: earnedToday).value
        }

        return store.allMoodEntries().compactMap { entry in
            guard let score = scoreByDay[entry.date] else { return nil }
            return (entry.value, score)
        }
    }

    // MARK: - Контент

    private func buildContent() {
        let data = pairs()

        // Мало данных — честное пустое состояние с инструкцией.
        guard data.count >= 5 else {
            stack.addArrangedSubview(makeCard(text:
                "Пока мало данных: дней с отметкой настроения и баллами — \(data.count).\n\nОтмечай настроение каждый вечер (кнопка на главном экране) — примерно через неделю здесь появится связь между твоим состоянием и продуктивностью.",
                emphasized: false
            ))
            return
        }

        // Главный инсайт: хорошие (4–5) против тяжёлых (1–2) дней.
        let goodScores = data.filter { $0.mood >= 4 }.map(\.score)
        let lowScores = data.filter { $0.mood <= 2 }.map(\.score)

        if !goodScores.isEmpty && !lowScores.isEmpty {
            let goodAvg = goodScores.reduce(0, +) / goodScores.count
            let lowAvg = max(1, lowScores.reduce(0, +) / lowScores.count)
            let delta = (goodAvg - lowAvg) * 100 / lowAvg

            let text: String
            if delta >= 10 {
                text = "В дни с хорошим настроением ты набираешь в среднем на \(delta)% больше баллов (\(goodAvg) против \(lowAvg)).\n\nЗабота о состоянии — это тоже продуктивность."
            } else if delta <= -10 {
                text = "Неожиданно: в тяжёлые дни ты набираешь в среднем на \(-delta)% больше баллов (\(lowAvg) против \(goodAvg)).\n\nПохоже, дела для тебя — способ вытащить себя из ямы. Это сильно."
            } else {
                text = "Твоя продуктивность стабильна при любом настроении: \(goodAvg) баллов в хорошие дни против \(lowAvg) в тяжёлые.\n\nДисциплина сильнее настроения — редкое качество."
            }
            stack.addArrangedSubview(makeCard(text: text, emphasized: true))
        }

        // Разбивка: средний балл по каждому настроению.
        let breakdown = makeBreakdownCard(data: data)
        stack.addArrangedSubview(breakdown)

        let footnote = UILabel()
        footnote.text = "Считаются дни, где есть и отметка настроения, и баллы. Всего таких дней: \(data.count)."
        footnote.font = .systemFont(ofSize: 12)
        footnote.textColor = .secondaryLabel
        footnote.numberOfLines = 0
        stack.addArrangedSubview(footnote)
    }

    // Карточка с текстом (инсайт или пустое состояние).
    private func makeCard(text: String, emphasized: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = emphasized
            ? DQColor.accentSoftAdaptive
            : .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16

        let label = UILabel()
        label.text = text
        label.font = emphasized
            ? DQFont.rounded(17, weight: .semibold)
            : .systemFont(ofSize: 15)
        label.textColor = emphasized ? DQColor.accentDark : .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    // Карточка-разбивка: строка на каждое настроение с баром балла.
    private func makeBreakdownCard(data: [(mood: Int, score: Int)]) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16

        let title = UILabel()
        title.text = "СРЕДНИЙ БАЛЛ ПО НАСТРОЕНИЮ"
        title.font = DQFont.rounded(12, weight: .bold)
        title.textColor = .secondaryLabel

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 12

        for mood in (1...5).reversed() {
            let scores = data.filter { $0.mood == mood }.map(\.score)
            rows.addArrangedSubview(makeMoodRow(
                mood: mood,
                average: scores.isEmpty ? nil : scores.reduce(0, +) / scores.count,
                count: scores.count
            ))
        }

        let content = UIStackView(arrangedSubviews: [title, rows])
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeMoodRow(mood: Int, average: Int?, count: Int) -> UIView {
        let emoji = UILabel()
        emoji.text = MoodScale.emoji(for: mood)
        emoji.font = .systemFont(ofSize: 24)
        emoji.setContentHuggingPriority(.required, for: .horizontal)
        emoji.alpha = average == nil ? 0.3 : 1

        // Бар: дорожка + заполнение по среднему баллу.
        let track = UIView()
        track.backgroundColor = DQColor.accentSoftAdaptive
        track.layer.cornerRadius = 5
        track.translatesAutoresizingMaskIntoConstraints = false

        let fill = UIView()
        fill.backgroundColor = average.map { DayScore(value: $0).color } ?? .clear
        fill.layer.cornerRadius = 5
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        let value = UILabel()
        value.text = average.map { "\($0)" } ?? "—"
        value.font = DQFont.roundedMono(16, weight: .bold)
        value.textColor = average == nil ? .tertiaryLabel : .label
        value.textAlignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)

        let days = UILabel()
        days.text = count > 0 ? "· \(count) дн." : ""
        days.font = .systemFont(ofSize: 12)
        days.textColor = .tertiaryLabel
        days.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [emoji, track, value, days])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center

        NSLayoutConstraint.activate([
            track.heightAnchor.constraint(equalToConstant: 10),
            value.widthAnchor.constraint(equalToConstant: 36),
            days.widthAnchor.constraint(equalToConstant: 52),

            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(
                equalTo: track.widthAnchor,
                multiplier: CGFloat(max(1, average ?? 1)) / 100
            )
        ])
        return row
    }
}

