//
//  LevelSystemViewController.swift
//  Questly
//
//  «Система уровней»: лестница титулов с порогами XP, текущее
//  положение и прогресс. Открывается тапом по карточке уровня
//  в профиле — прокачка перестаёт быть чёрным ящиком.
//

import UIKit

final class LevelSystemViewController: UIViewController {

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var userLevel = LevelSystem.userLevel(totalPoints: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Система уровней"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        userLevel = LevelSystem.userLevel(
            totalPoints: DataStore.shared.profileStats().totalPointsEarned
        )

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self
        tableView.tableHeaderView = makeHeader()
    }

    // Шапка: текущий уровень крупно + прогресс до следующего.
    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0,
                                          width: view.bounds.width, height: 150))

        let circle = DQIcon.circle(
            symbol: "bolt.fill",
            tint: DQColor.accentAdaptive,
            soft: DQColor.accentSoftAdaptive,
            diameter: 56, symbolSize: 26
        )
        header.addSubview(circle)

        let title = UILabel()
        title.text = "Уровень \(userLevel.level) — «\(userLevel.title)»"
        title.font = DQFont.rounded(20, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)

        let subtitle = UILabel()
        subtitle.text = "\(userLevel.totalPoints) XP · до следующего — \(userLevel.pointsToNext)"
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabel
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitle)

        let track = UIView()
        track.backgroundColor = DQColor.accentSoftAdaptive
        track.layer.cornerRadius = 5
        track.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(track)

        let fill = UIView()
        fill.backgroundColor = DQColor.accentAdaptive
        fill.layer.cornerRadius = 5
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: header.topAnchor, constant: 20),
            circle.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),

            title.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: header.topAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -24),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),

            track.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 18),
            track.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            track.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            track.heightAnchor.constraint(equalToConstant: 10),

            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor,
                                        multiplier: max(0.02, min(1, userLevel.progress)))
        ])
        return header
    }
}

// MARK: - Table

extension LevelSystemViewController: UITableViewDataSource {

    // Показываем 6 титулов; дальше — бесконечная «Легенда».
    private var levels: [Int] { Array(1...6) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        levels.count
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "После «Гуру» каждый следующий уровень — «Легенда», ещё +3000 XP за уровень. XP приносят задачи, квесты дня, челленджи и фокус-сессии."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let level = levels[indexPath.row]
        let threshold = LevelSystem.threshold(toReach: level)
        let sample = LevelSystem.userLevel(totalPoints: threshold)

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.text = "\(level) · \(sample.title)"
        config.secondaryText = level == 1 ? "старт" : "от \(threshold) XP"
        config.secondaryTextProperties.font = DQFont.rounded(14, weight: .semibold)

        if level < userLevel.level {
            // Пройден
            config.image = UIImage(systemName: "checkmark.circle.fill")
            config.imageProperties.tintColor = .systemGreen
            config.textProperties.color = .secondaryLabel
            config.secondaryTextProperties.color = .tertiaryLabel
        } else if level == userLevel.level {
            // Текущий
            config.image = UIImage(systemName: "location.circle.fill")
            config.imageProperties.tintColor = DQColor.accentAdaptive
            config.textProperties.font = DQFont.rounded(17, weight: .bold)
            config.secondaryTextProperties.color = DQColor.accentDark
        } else {
            // Впереди
            config.image = UIImage(systemName: "circle.dashed")
            config.imageProperties.tintColor = .tertiaryLabel
            config.secondaryTextProperties.color = .secondaryLabel
        }

        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }
}

