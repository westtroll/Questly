//
//  DayPlanViewController.swift
//  Questly
//
//  Лист конкретного дня из календаря истории. Для сегодня и будущих
//  дней позволяет добавлять запланированные пункты (барбершоп, встречи).
//  Эти пункты не влияют на дневной счёт и штрафы — это напоминания.
//

import UIKit
import SwiftData

final class DayPlanViewController: UIViewController {

    private let day: Date
    private var planned: [PlannedItem] = []

    private let store = DataStore.shared

    // Можно ли планировать на этот день (сегодня и будущее)
    private var isPlannable: Bool {
        Calendar.current.startOfDay(for: day) >= Calendar.current.startOfDay(for: Date())
    }

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        title = formatter.string(from: day)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        if isPlannable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .add,
                target: self, action: #selector(addTapped)
            )
        }

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Заглушку центрируем по экрану, а не растягиваем фоном таблицы —
            // так текст стоит ровно посередине.
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
        planned = store.fetchPlanned(on: day)
        emptyLabel.isHidden = !planned.isEmpty
        emptyLabel.text = isPlannable
            ? "На этот день пока ничего не запланировано.\n\nНажми + чтобы добавить"
            : "В этот день ничего не было запланировано"
        tableView.reloadData()
    }

    // MARK: - Add / edit

    @objc private func addTapped() {
        presentEditor(existing: nil)
    }

    private func presentEditor(existing: PlannedItem?) {
        let alert = UIAlertController(
            title: existing == nil ? "Что запланировать?" : "Изменить",
            message: "Например: Барбершоп",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Название"
            tf.text = existing?.title
            tf.autocapitalizationType = .sentences
        }
        alert.addTextField { tf in
            tf.placeholder = "Время, напр. 15:00"
            tf.text = existing?.timeText
            tf.keyboardType = .numbersAndPunctuation
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            guard let self else { return }
            let title = (alert.textFields?[0].text ?? "").trimmingCharacters(in: .whitespaces)
            let time = (alert.textFields?[1].text ?? "").trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return }

            if let existing {
                existing.title = title
                existing.timeText = time
                store.save()
                reload()
            } else {
                let item = PlannedItem(title: title, date: day, timeText: time)
                store.context.insert(item)
                store.save()
                reload()
                offerCalendar(for: item)
            }
        })
        present(alert, animated: true)
    }

    // Предложение добавить в Календарь Apple (у нас уже есть сервис).
    private func offerCalendar(for item: PlannedItem) {
        // Стартовое время: если указано «15:00» — парсим, иначе 9:00.
        let start = combine(day: day, timeText: item.timeText)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"

        let alert = UIAlertController(
            title: "Добавить в Календарь?",
            message: "«\(item.title)» — \(formatter.string(from: start))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Не нужно", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default) { _ in
            CalendarService.addEvent(
                title: item.title,
                startDate: start,
                endDate: start.addingTimeInterval(3600),
                notes: "Запланировано в Questly"
            ) { _ in }
        })
        present(alert, animated: true)
    }

    // «15:00» + день → Date. Пусто или мусор → 9:00 того же дня.
    private func combine(day: Date, timeText: String) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        let parts = timeText.split(separator: ":")
        comps.hour = parts.count == 2 ? Int(parts[0]) ?? 9 : 9
        comps.minute = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        return calendar.date(from: comps) ?? day
    }
}

// MARK: - Table

extension DayPlanViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        planned.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = planned[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        if item.isDone {
            config.text = item.title
            config.textProperties.color = .tertiaryLabel
        }
        config.secondaryText = item.timeText.isEmpty ? nil : item.timeText
        config.image = UIImage(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
        config.imageProperties.tintColor = item.isDone ? .systemGreen : .tertiaryLabel
        cell.contentConfiguration = config
        return cell
    }

    // Тап — отметить выполненным (для сегодня/прошлого)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = planned[indexPath.row]
        item.isDone.toggle()
        Haptics.light()
        store.save()
        reload()
    }

    // Свайп — удалить / изменить
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let item = planned[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") {
            [weak self] _, _, done in
            guard let self else { return }
            store.context.delete(item)
            store.save()
            reload()
            done(true)
        }
        delete.image = UIImage(systemName: "trash")

        let edit = UIContextualAction(style: .normal, title: "Изменить") {
            [weak self] _, _, done in
            self?.presentEditor(existing: item)
            done(true)
        }
        edit.image = UIImage(systemName: "pencil")
        return UISwipeActionsConfiguration(actions: [delete, edit])
    }
}

