//
//  YearGoalsViewController.swift
//  Questly
//
//  Цели года: крупные ориентиры («пробежать полумарафон»).
//  Не задачи с баллами, а компас. Показываются и виджетом
//  «Цели года» на домашнем экране.
//

import UIKit
import SwiftData

final class YearGoalsViewController: UIViewController {

    private var goals: [YearGoal] = []
    private let year = Calendar.current.component(.year, from: Date())
    private let store = DataStore.shared

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Цели на \(year)"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        emptyLabel.text = "Какими будут твои главные\nдостижения в \(year) году?\n\nНажми + чтобы поставить цель"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped)
        )

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
        tableView.delegate = self

        reload()
    }

    private func reload() {
        goals = store.fetchYearGoals(year: year)
        emptyLabel.isHidden = !goals.isEmpty
        tableView.reloadData()
    }

    @objc private func addTapped() {
        let alert = UIAlertController(
            title: "Цель на \(year) год",
            message: "Например: Пробежать полумарафон",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Цель"
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Поставить", style: .default) { [weak self] _ in
            guard let self,
                  let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !title.isEmpty else { return }
            store.context.insert(YearGoal(title: title, year: year))
            store.save()   // save() обновит и виджет
            reload()
        })
        present(alert, animated: true)
    }
}

extension YearGoalsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        goals.count
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        goals.isEmpty ? nil : "Невыполненные цели показываются виджетом «Цели года» на домашнем экране"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let goal = goals[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.text = goal.title
        config.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
        config.textProperties.color = goal.isDone ? .tertiaryLabel : .label
        config.image = UIImage(systemName: goal.isDone ? "checkmark.seal.fill" : "scope")
        config.imageProperties.tintColor = goal.isDone ? .systemGreen : DQColor.accentAdaptive
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }

    // Тап — цель достигнута (или вернуть в работу)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = goals[indexPath.row]
        goal.isDone.toggle()
        if goal.isDone { Haptics.success() } else { Haptics.light() }
        store.save()
        reload()
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let goal = goals[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") {
            [weak self] _, _, done in
            guard let self else { return }
            store.context.delete(goal)
            store.save()
            reload()
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

