//
//  HabitsViewController.swift
//  Questly
//
//  Вкладка «Привычки»: счётчики отказа от вредных привычек.
//  Карточка показывает время без привычки, экономию денег
//  и активное обещание. Сброс — свайпом или из меню.
//

import UIKit
import Combine
import SwiftData

final class HabitsViewController: UIViewController {

    // MARK: - Данные

    private let store = DataStore.shared
    private var counters: [HabitCounter] = []
    private var goodHabits: [GoodHabit] = []
    private var cancellables = Set<AnyCancellable>()

    // Какой сегмент показан: 0 — «Бросаю» (счётчики), 1 — «Внедряю».
    private var isBuildingSegment: Bool { segmentControl.selectedSegmentIndex == 1 }

    private let segmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Бросаю", "Внедряю"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    // MARK: - UI

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Добавь первый счётчик —\nи начни отсчёт свободы 🌱"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Привычки"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )
        // Топ привычек — рекорды лучших серий.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trophy"),
            style: .plain,
            target: self,
            action: #selector(topTapped)
        )

        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentControl)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(HabitCounterCell.self, forCellReuseIdentifier: HabitCounterCell.reuseId)
        tableView.register(GoodHabitCell.self, forCellReuseIdentifier: GoodHabitCell.reuseId)
        tableView.backgroundView = emptyLabel

        // Перезагрузка при изменении данных (создание/правка/удаление).
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        // Живое время нужно только счётчикам («Бросаю») с форматом
        // таймер. Полезные привычки в секундном обновлении не нуждаются.
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !isBuildingSegment else { return }
                tableView.visibleCells.forEach { ($0 as? HabitCounterCell)?.refreshTime() }
            }
            .store(in: &cancellables)

        reload()
    }

    // MARK: - Данные

    private func reload() {
        counters = store.fetchHabitCounters()
        goodHabits = store.fetchGoodHabits()

        let isEmpty = isBuildingSegment ? goodHabits.isEmpty : counters.isEmpty
        emptyLabel.isHidden = !isEmpty
        emptyLabel.text = isBuildingSegment
            ? "Добавь полезную привычку\nи отмечай её каждый день 🌱"
            : "Добавь первый счётчик —\nи начни отсчёт свободы 🌱"
        tableView.reloadData()
    }

    @objc private func segmentChanged() {
        Haptics.light()
        reload()
    }

    // MARK: - Actions

    @objc private func topTapped() {
        navigationController?.pushViewController(HabitsTopViewController(), animated: true)
    }

    @objc private func addTapped() {
        if isBuildingSegment {
            presentGoodHabitForm(habitToEdit: nil)
        } else {
            presentForm(counterToEdit: nil)
        }
    }

    private func presentGoodHabitForm(habitToEdit: GoodHabit?) {
        let formVC = GoodHabitFormViewController(habitToEdit: habitToEdit)
        let nav = UINavigationController(rootViewController: formVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    private func confirmDeleteGoodHabit(_ habit: GoodHabit) {
        let alert = UIAlertController(
            title: "Удалить «\(habit.name)»?",
            message: "Привычка и вся история отметок будут удалены",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            store.context.delete(habit)
            store.save()
        })
        present(alert, animated: true)
    }

    private func presentForm(counterToEdit: HabitCounter?) {
        let formVC = HabitCounterFormViewController(counterToEdit: counterToEdit)
        let nav = UINavigationController(rootViewController: formVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
        }
        present(nav, animated: true)
    }

    private func presentPromise(for counter: HabitCounter) {
        let promiseVC = HabitPromiseViewController(counter: counter)
        let nav = UINavigationController(rootViewController: promiseVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    private func confirmReset(_ counter: HabitCounter) {
        var message = "Сорвался — бывает. Отсчёт начнётся заново с этой минуты, экономия обнулится."
        if counter.isPromiseActive {
            message += "\n\n⚠️ Активное обещание будет нарушено."
        }

        let alert = UIAlertController(
            title: "Сбросить «\(counter.name)»?",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive) { [weak self] _ in
            counter.recordCurrentRun()   // рекорд — до обнуления!
            counter.startDate = .now
            // Срыв обнуляет и обещание — оно больше не действует.
            counter.promiseText = ""
            counter.promiseUntil = nil
            self?.store.save()
        })
        present(alert, animated: true)
    }

    private func confirmDelete(_ counter: HabitCounter) {
        let alert = UIAlertController(
            title: "Удалить «\(counter.name)»?",
            message: "Счётчик и его прогресс будут удалены",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            store.context.delete(counter)
            store.save()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension HabitsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isBuildingSegment ? goodHabits.count : counters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isBuildingSegment {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: GoodHabitCell.reuseId, for: indexPath
            ) as! GoodHabitCell
            cell.configure(with: goodHabits[indexPath.row])
            cell.delegate = self
            return cell
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: HabitCounterCell.reuseId, for: indexPath
        ) as! HabitCounterCell
        cell.configure(with: counters[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HabitsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isBuildingSegment {
            presentGoodHabitForm(habitToEdit: goodHabits[indexPath.row])
        } else {
            presentForm(counterToEdit: counters[indexPath.row])
        }
    }

    // Свайп влево. «Бросаю» → сброс счётчика; «Внедряю» → удаление привычки.
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        if isBuildingSegment {
            let habit = goodHabits[indexPath.row]
            let delete = UIContextualAction(style: .destructive, title: "Удалить") {
                [weak self] _, _, completion in
                self?.confirmDeleteGoodHabit(habit)
                completion(true)
            }
            delete.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [delete])
        }

        let counter = counters[indexPath.row]
        let reset = UIContextualAction(style: .destructive, title: "Сбросить") {
            [weak self] _, _, completion in
            self?.confirmReset(counter)
            completion(true)
        }
        reset.image = UIImage(systemName: "arrow.counterclockwise")
        reset.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [reset])
    }

    // Лонг-тап-меню. Для полезной привычки — короткое (изменить/удалить),
    // для счётчика — полное с обещанием.
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        if isBuildingSegment {
            let habit = goodHabits[indexPath.row]
            return UIContextMenuConfiguration(actionProvider: { _ in
                let edit = UIAction(title: "Изменить",
                                    image: UIImage(systemName: "pencil")) { [weak self] _ in
                    self?.presentGoodHabitForm(habitToEdit: habit)
                }
                let delete = UIAction(title: "Удалить",
                                      image: UIImage(systemName: "trash"),
                                      attributes: .destructive) { [weak self] _ in
                    self?.confirmDeleteGoodHabit(habit)
                }
                return UIMenu(children: [edit, delete])
            })
        }

        let counter = counters[indexPath.row]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let promise = UIAction(
                title: counter.isPromiseActive ? "Обновить обещание" : "Дать обещание",
                image: UIImage(systemName: "hand.raised.fill")
            ) { [weak self] _ in
                self?.presentPromise(for: counter)
            }
            let reset = UIAction(
                title: "Сбросить счётчик",
                image: UIImage(systemName: "arrow.counterclockwise")
            ) { [weak self] _ in
                self?.confirmReset(counter)
            }
            let edit = UIAction(
                title: "Изменить",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.presentForm(counterToEdit: counter)
            }
            let delete = UIAction(
                title: "Удалить",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete(counter)
            }
            return UIMenu(children: [promise, reset, edit, delete])
        })
    }
}

// MARK: - GoodHabitCellDelegate

extension HabitsViewController: GoodHabitCellDelegate {

    func goodHabitCell(_ cell: GoodHabitCell, didToggleToday habit: GoodHabit) {
        habit.toggleToday()
        Haptics.light()
        store.save()
        // Перерисовываем ячейку: обновятся стрик, кнопка и полоска недели.
        if let indexPath = tableView.indexPath(for: cell) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}

// MARK: - HabitCounterCell

final class HabitCounterCell: UITableViewCell {

    static let reuseId = "HabitCounterCell"

    private var counter: HabitCounter?

    private let card: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        // monospacedDigit — чтобы «таймер» не дёргался каждую секунду
        // Скруглённый шрифт с моноширинными цифрами: дружелюбный тон,
        // но «таймер» не дёргается посекундно.
        label.font = DQFont.roundedMono(24, weight: .bold)
        return label
    }()

    private let savingsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    // «🤝 Обещание: ещё 5 дней · „хочу быть здоровым“»
    private let promiseLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let stack = UIStackView(arrangedSubviews: [nameLabel, timeLabel, savingsLabel, promiseLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        // Без жмяка: тап по карточке открывает редактирование
        // (didSelectRowAt), а жест-жмяк перехватывал бы касание.
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // «Жмяк» на прикосновение через подсветку ячейки: не глушит
    // выбор строки (didSelectRowAt открывает редактирование),
    // в отличие от тап-жеста на карточке.
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            UIView.animate(withDuration: 0.12,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = CGAffineTransform(scaleX: 0.965, y: 0.965)
            }
        } else {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.4,
                           initialSpringVelocity: 6,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = .identity
            }
        }
    }

    func configure(with counter: HabitCounter) {
        self.counter = counter
        let color = CategoryColor.named(counter.colorName)
        card.backgroundColor = color.background
        timeLabel.textColor = color.main
        nameLabel.text = counter.name
        refreshTime()
    }

    /// Обновление живых значений — дёргается контроллером раз в секунду
    func refreshTime() {
        guard let counter else { return }

        timeLabel.text = counter.format.string(from: counter.startDate)

        // Экономия
        if counter.spendAmount > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = counter.currencyCode
            formatter.maximumFractionDigits = 0
            let saved = formatter.string(from: counter.savedMoney() as NSNumber) ?? ""
            savingsLabel.attributedText = .withIcon(
                "banknote", text: "Сэкономлено ≈ \(saved)",
                font: .systemFont(ofSize: 13), color: .secondaryLabel,
                iconColor: .systemGreen
            )
            savingsLabel.isHidden = false
        } else {
            savingsLabel.isHidden = true
        }

        // Обещание
        if let until = counter.promiseUntil {
            promiseLabel.isHidden = false
            if until > Date() {
                let remaining = until.timeIntervalSinceNow
                let time: String
                if remaining >= 86_400 {
                    time = "ещё " + Int(ceil(remaining / 86_400)).daysString
                } else {
                    time = "ещё \(max(1, Int(remaining / 3600))) ч"
                }
                promiseLabel.attributedText = .withIcon(
                    "hand.raised.fill", text: "Обещание: \(time) · «\(counter.promiseText)»",
                    font: .systemFont(ofSize: 13), color: .secondaryLabel,
                    iconColor: DQColor.accentAdaptive
                )
            } else {
                // Срок вышел, счётчик не сброшен — обещание сдержано!
                promiseLabel.attributedText = .withIcon(
                    "checkmark.seal.fill", text: "Обещание сдержано! Можешь дать новое",
                    font: .systemFont(ofSize: 13), color: .systemGreen
                )
            }
        } else {
            promiseLabel.isHidden = true
        }
    }
}

// MARK: - HabitPromiseViewController
//
// Мини-экран обещания: «Почему я это делаю?» + срок.

final class HabitPromiseViewController: UIViewController {

    private let counter: HabitCounter

    // Пресеты срока обещания (в днях)
    private static let durations: [(title: String, days: Int)] = [
        ("1 день", 1), ("3 дня", 3), ("Неделя", 7),
        ("2 недели", 14), ("Месяц", 30), ("3 месяца", 90)
    ]

    private var selectedDays = 7

    // MARK: - UI

    private let questionLabel: UILabel = {
        let label = UILabel()
        label.text = "Почему я это делаю?"
        label.font = DQFont.rounded(20, weight: .bold)
        return label
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "Честный ответ себе — лучшая защита от срыва. Он будет виден на карточке счётчика."
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .secondarySystemGroupedBackground
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let durationTitle: UILabel = {
        let label = UILabel()
        label.text = "На какой срок обещаешь не сорваться?"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let durationButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.indicator = .popup
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        return button
    }()

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Обещаю 🤝"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = DQColor.accent
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    init(counter: HabitCounter) {
        self.counter = counter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Обещание"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel

        textView.delegate = self
        textView.text = counter.promiseText
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        durationButton.menu = UIMenu(children: Self.durations.map { duration in
            UIAction(title: duration.title,
                     state: duration.days == selectedDays ? .on : .off) { [weak self] _ in
                self?.selectedDays = duration.days
            }
        })

        setupLayout()
        updateSaveButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    // MARK: - Layout

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [
            questionLabel, hintLabel, textView, durationTitle, durationButton
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(16, after: textView)
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            textView.heightAnchor.constraint(equalToConstant: 100),
            textView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hintLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func updateSaveButton() {
        let isValid = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveButton.isEnabled = isValid
        saveButton.alpha = isValid ? 1.0 : 0.5
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        counter.promiseText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        counter.promiseUntil = Date().addingTimeInterval(Double(selectedDays) * 86_400)
        DataStore.shared.save()
        Haptics.success()
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITextViewDelegate

extension HabitPromiseViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        updateSaveButton()
    }
}

