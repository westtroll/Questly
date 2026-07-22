//
//  HabitsTopViewController.swift
//  Questly
//
//  «Топ привычек»: рекорды по лучшим сериям. Две секции —
//  «Внедряю» (лучшая цепочка отметок) и «Бросаю» (самый долгий
//  заход между срывами). Тройка лидеров — с медалями.
//

import UIKit

final class HabitsTopViewController: UIViewController {

    private var goodHabits: [(name: String, days: Int, colorName: String)] = []
    private var counters: [(name: String, days: Int, colorName: String)] = []

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Здесь появятся рекорды твоих привычек — заведи первую!"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Топ привычек"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        tableView.dataSource = self

        reload()
    }

    private func reload() {
        // Собираем рекорды и сортируем по убыванию — это и есть «топ».
        goodHabits = DataStore.shared.fetchGoodHabits()
            .map { ($0.name, $0.bestStreak, $0.colorName) }
            .sorted { $0.1 > $1.1 }

        counters = DataStore.shared.fetchHabitCounters()
            .map { ($0.name, $0.bestDays, $0.colorName) }
            .sorted { $0.1 > $1.1 }

        emptyLabel.isHidden = !(goodHabits.isEmpty && counters.isEmpty)
        tableView.reloadData()
    }

    // Медаль для тройки лидеров, номер — остальным.
    private func rankPrefix(_ index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(index + 1)."
        }
    }
}

// MARK: - Table

extension HabitsTopViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? goodHabits.count : counters.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Внедряю — лучшие серии" : "Бросаю — рекорды продержки"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0 where !goodHabits.isEmpty:
            return "Самая длинная цепочка отметок подряд за всю историю"
        case 1 where !counters.isEmpty:
            return "Самый долгий заход — даже если потом был срыв, рекорд остаётся"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = indexPath.section == 0
            ? goodHabits[indexPath.row]
            : counters[indexPath.row]

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.text = "\(rankPrefix(indexPath.row)) \(item.name)"
        config.textProperties.font = .systemFont(ofSize: 15, weight: .medium)

        // Справа — рекорд в днях, цветом привычки.
        config.secondaryText = item.days.daysString
        config.secondaryTextProperties.font = DQFont.rounded(15, weight: .bold)
        config.secondaryTextProperties.color = CategoryColor.named(item.colorName).main

        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }
}

