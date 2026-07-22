//
//  MonthPlanViewController.swift
//  Questly
//
//  Планировщик месяца: задачи без точной даты («сходить к врачу»).
//  Свайпом переносятся в план конкретного дня, когда дата созрела,
//  или на следующий месяц, если не успел. Хвосты прошлых месяцев
//  не пропадают — висят отдельной секцией.
//

import UIKit
import SwiftData

final class MonthPlanViewController: UIViewController {

    private var items: [MonthPlanItem] = []      // текущий месяц
    private var overdue: [MonthPlanItem] = []    // хвосты прошлых

    private let store = DataStore.shared

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Запиши дела на этот месяц,\nдаже если точная дата пока неизвестна.\n\nНажми + чтобы добавить"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        title = "План на \(formatter.string(from: Date()))"

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
        items = store.fetchMonthPlan(for: Date())
        overdue = store.fetchOverdueMonthPlan(before: Date())
        emptyLabel.isHidden = !(items.isEmpty && overdue.isEmpty)
        tableView.reloadData()
    }

    private func item(at indexPath: IndexPath) -> MonthPlanItem {
        indexPath.section == 0 && !overdue.isEmpty ? overdue[indexPath.row] : items[indexPath.row]
    }

    // MARK: - Добавление

    @objc private func addTapped() {
        let alert = UIAlertController(
            title: "Дело на этот месяц",
            message: "Например: Осмотр у врача",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Название"
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default) { [weak self] _ in
            guard let self,
                  let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !title.isEmpty else { return }
            store.context.insert(MonthPlanItem(title: title, month: Date()))
            store.save()
            reload()
        })
        present(alert, animated: true)
    }

    // MARK: - Перенос в конкретный день

    private func pickDay(for item: MonthPlanItem) {
        let pickerVC = UIViewController()
        pickerVC.view.backgroundColor = .systemGroupedBackground

        let hint = UILabel()
        hint.text = "«\(item.title)» — на какой день?"
        hint.font = DQFont.rounded(17, weight: .semibold)
        hint.textAlignment = .center
        hint.numberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.minimumDate = Calendar.current.startOfDay(for: Date())
        picker.translatesAutoresizingMaskIntoConstraints = false

        let confirm = UIButton.dqPrimary(title: "Перенести в календарь")
        confirm.translatesAutoresizingMaskIntoConstraints = false
        confirm.addAction(UIAction { [weak self, weak pickerVC] _ in
            guard let self else { return }
            // Переезд: месячная задача становится планом конкретного дня.
            store.context.insert(PlannedItem(title: item.title, date: picker.date))
            store.context.delete(item)
            store.save()
            Haptics.success()
            reload()
            pickerVC?.dismiss(animated: true)
        }, for: .touchUpInside)

        pickerVC.view.addSubview(hint)
        pickerVC.view.addSubview(picker)
        pickerVC.view.addSubview(confirm)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: pickerVC.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hint.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor, constant: -20),

            picker.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor, constant: 12),
            picker.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor, constant: -12),

            confirm.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor, constant: 20),
            confirm.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor, constant: -20),
            confirm.heightAnchor.constraint(equalToConstant: 52),
            confirm.bottomAnchor.constraint(equalTo: pickerVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        if let sheet = pickerVC.sheetPresentationController {
            sheet.detents = [.large()]
        }
        present(pickerVC, animated: true)
    }
}

// MARK: - Table

extension MonthPlanViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        overdue.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 && !overdue.isEmpty ? overdue.count : items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !overdue.isEmpty {
            return section == 0 ? "С прошлых месяцев" : "Этот месяц"
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let planItem = item(at: indexPath)
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.text = planItem.title
        config.textProperties.color = planItem.isDone ? .tertiaryLabel : .label
        config.image = UIImage(systemName: planItem.isDone ? "checkmark.circle.fill" : "circle")
        config.imageProperties.tintColor = planItem.isDone ? .systemGreen : .tertiaryLabel
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }

    // Тап — отметить выполненным
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let planItem = item(at: indexPath)
        planItem.isDone.toggle()
        Haptics.light()
        store.save()
        reload()
    }

    // Свайп: в календарь / на след. месяц / удалить
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let planItem = item(at: indexPath)

        let delete = UIContextualAction(style: .destructive, title: "Удалить") {
            [weak self] _, _, done in
            guard let self else { return }
            store.context.delete(planItem)
            store.save()
            reload()
            done(true)
        }
        delete.image = UIImage(systemName: "trash")

        let toCalendar = UIContextualAction(style: .normal, title: "В календарь") {
            [weak self] _, _, done in
            self?.pickDay(for: planItem)
            done(true)
        }
        toCalendar.image = UIImage(systemName: "calendar.badge.plus")
        toCalendar.backgroundColor = DQColor.accent

        let nextMonth = UIContextualAction(style: .normal, title: "След. месяц") {
            [weak self] _, _, done in
            guard let self else { return }
            planItem.month = Calendar.current.date(
                byAdding: .month, value: 1,
                to: MonthPlanItem.startOfMonth(Date())
            )!
            store.save()
            Haptics.light()
            reload()
            done(true)
        }
        nextMonth.image = UIImage(systemName: "arrow.uturn.forward")
        nextMonth.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [delete, nextMonth, toCalendar])
    }
}

