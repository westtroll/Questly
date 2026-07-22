//
//  WeeklyReport.swift
//  Questly
//
//  «Поделиться результатом недели»: рендерит фирменную карточку
//  с графиком баллов по дням и итогами — готовую картинку для
//  соцсетей. UIView собирается в памяти и снимается в UIImage.
//

import UIKit

enum WeeklyReport {

    /// Готовый контент для «поделиться»: картинка + живой текст
    /// с реальными цифрами недели и ссылкой на App Store.
    @MainActor
    static func shareContent() -> (image: UIImage, text: String) {
        let data = weekData()
        let image = render(scores: data.scores, average: data.average,
                           perfect: data.perfect, streak: data.streak, range: data.range)

        // Текст с конкретикой: цифры убеждают лучше лозунгов.
        var lines: [String] = ["Так прошла моя неделя в Questly 🎯"]
        var facts: [String] = []
        if data.average > 0 { facts.append("средний балл — \(data.average)/100") }
        if data.perfect > 0 { facts.append("идеальных дней — \(data.perfect)") }
        if data.streak > 0 { facts.append("стрик — \(data.streak.daysString) 🔥") }
        if !facts.isEmpty {
            let sentence = facts.joined(separator: ", ")
            lines.append(sentence.prefix(1).uppercased() + String(sentence.dropFirst()) + ".")
        }
        lines.append("Становлюсь продуктивнее с каждым днём. Присоединяйся:")
        lines.append(AppConfig.appStoreURL)

        return (image, lines.joined(separator: "\n"))
    }

    // MARK: - Данные недели

    private struct WeekData {
        let scores: [Int?]
        let average: Int
        let perfect: Int
        let streak: Int
        let range: String
    }

    @MainActor
    private static func weekData() -> WeekData {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())

        // Баллы по дням недели (пн...вс). Сегодняшний день берём живым.
        let records = DataStore.shared.fetchRecords()
        let byDay = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0.score) })
        let today = calendar.startOfDay(for: Date())

        var scores: [Int?] = []
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            if day == today {
                let earned = DataStore.shared.fetchCategories().reduce(0) { $0 + $1.earnedPoints }
                scores.append(DayScore(earnedPoints: earned).value)
            } else if day < today {
                scores.append(byDay[day] ?? 0)
            } else {
                scores.append(nil)   // будущее — не рисуем столбик
            }
        }

        let known = scores.compactMap { $0 }
        let average = known.isEmpty ? 0 : known.reduce(0, +) / known.count
        let perfect = known.filter { $0 >= 100 }.count
        let streak = DataStore.shared.profileStats().currentStreak

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let range = "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"

        return WeekData(scores: scores, average: average,
                        perfect: perfect, streak: streak, range: range)
    }

    // MARK: - Рендер

    @MainActor
    private static func render(scores: [Int?], average: Int,
                               perfect: Int, streak: Int, range: String) -> UIImage {
        let size = CGSize(width: 600, height: 780)
        let card = UIView(frame: CGRect(origin: .zero, size: size))
        card.backgroundColor = UIColor(red: 0.992, green: 0.976, blue: 0.965, alpha: 1)

        // Шапка: марка + имя + период
        let mark = UIImageView(image: UIImage(systemName: "checkmark.seal.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)))
        mark.tintColor = DQColor.accent
        mark.frame = CGRect(x: 48, y: 52, width: 52, height: 50)
        card.addSubview(mark)

        let name = UILabel(frame: CGRect(x: 114, y: 50, width: 300, height: 34))
        name.text = "Questly"
        name.font = DQFont.rounded(28, weight: .bold)
        name.textColor = DQColor.accentDark
        card.addSubview(name)

        let period = UILabel(frame: CGRect(x: 114, y: 84, width: 400, height: 20))
        period.text = "Моя неделя · \(range)"
        period.font = .systemFont(ofSize: 15)
        period.textColor = .darkGray
        card.addSubview(period)

        // График: 7 столбиков высотой до 300
        let letters = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
        let chartTop: CGFloat = 170, chartHeight: CGFloat = 300
        let barWidth: CGFloat = 52, gap: CGFloat = 22
        let totalWidth = 7 * barWidth + 6 * gap
        var x = (size.width - totalWidth) / 2

        for (index, score) in scores.enumerated() {
            let value = score ?? 0
            let h = max(10, chartHeight * CGFloat(value) / 100)
            let bar = UIView(frame: CGRect(x: x, y: chartTop + chartHeight - h,
                                           width: barWidth, height: h))
            bar.layer.cornerRadius = 10
            if score == nil {
                bar.backgroundColor = UIColor.black.withAlphaComponent(0.05)
            } else {
                let color = DayScore(value: value).color
                bar.backgroundColor = value == 0
                    ? UIColor.black.withAlphaComponent(0.08)
                    : color.withAlphaComponent(0.35 + 0.6 * CGFloat(value) / 100)
            }
            card.addSubview(bar)

            // Балл над столбиком
            if let score, score > 0 {
                let scoreLabel = UILabel(frame: CGRect(x: x, y: bar.frame.minY - 26,
                                                       width: barWidth, height: 22))
                scoreLabel.text = "\(score)"
                scoreLabel.font = DQFont.rounded(16, weight: .bold)
                scoreLabel.textColor = .darkGray
                scoreLabel.textAlignment = .center
                card.addSubview(scoreLabel)
            }

            let letter = UILabel(frame: CGRect(x: x, y: chartTop + chartHeight + 8,
                                               width: barWidth, height: 18))
            letter.text = letters[index]
            letter.font = DQFont.rounded(13, weight: .semibold)
            letter.textColor = .gray
            letter.textAlignment = .center
            card.addSubview(letter)

            x += barWidth + gap
        }

        // Итоги: три числа в ряд
        let stats: [(String, String)] = [
            ("\(average)", "средний балл"),
            ("\(perfect)", "идеальных дней"),
            ("\(streak)", "дней стрик 🔥")
        ]
        let statWidth = (size.width - 96) / 3
        for (index, stat) in stats.enumerated() {
            let sx = 48 + CGFloat(index) * statWidth
            let value = UILabel(frame: CGRect(x: sx, y: 540, width: statWidth, height: 44))
            value.text = stat.0
            value.font = DQFont.rounded(38, weight: .bold)
            value.textColor = DQColor.accentDark
            value.textAlignment = .center
            card.addSubview(value)

            let caption = UILabel(frame: CGRect(x: sx, y: 586, width: statWidth, height: 20))
            caption.text = stat.1
            caption.font = .systemFont(ofSize: 14)
            caption.textColor = .gray
            caption.textAlignment = .center
            card.addSubview(caption)
        }

        // Футер: послание + ссылка впечены в картинку — что бы ни
        // копировалось, призыв и адрес всегда при карточке.
        let slogan = UILabel(frame: CGRect(x: 0, y: 654, width: size.width, height: 22))
        slogan.text = "Каждый день — квест. Присоединяйся!"
        slogan.font = .systemFont(ofSize: 16)
        slogan.textColor = UIColor(red: 0.180, green: 0.227, blue: 0.314, alpha: 0.75)
        slogan.textAlignment = .center
        card.addSubview(slogan)

        let link = UILabel(frame: CGRect(x: 0, y: 682, width: size.width, height: 24))
        link.text = AppConfig.appStoreURL
            .replacingOccurrences(of: "https://", with: "")
        link.font = DQFont.rounded(17, weight: .semibold)
        link.textColor = DQColor.accent
        link.textAlignment = .center
        card.addSubview(link)

        let brand = UILabel(frame: CGRect(x: 0, y: 726, width: size.width, height: 18))
        brand.text = "Questly для iPhone"
        brand.font = .systemFont(ofSize: 12)
        brand.textColor = .gray
        brand.textAlignment = .center
        card.addSubview(brand)

        // Снимок вью в картинку (масштаб 3x — чётко для соцсетей).
        // layer.render — надёжен для вью, не добавленной в окно
        // (drawHierarchy офскрин может отдать пустоту).
        card.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            card.layer.render(in: context.cgContext)
        }
    }
}
