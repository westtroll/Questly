//
//  CategoryDetailViewController.swift
//  Questly
//
//  Экран одной категории: список её задач с чекбоксами,
//  строка «Добавить задачу» и меню удаления категории.
//  Открывается пушем при тапе на плитку с главного экрана.
//

import UIKit
import Combine

final class CategoryDetailViewController: UIViewController {

    // MARK: - Данные

    private var category: Category
    private let viewModel: TodayViewModel
    private var cancellables = Set<AnyCancellable>()

    // Флаг «категория удаляется». Нужен, потому что после удаления
    // модели из SwiftData обращаться к её свойствам уже нельзя,
    // а подписка на изменения всё равно попытается перерисовать таблицу.
    private var isDeletingCategory = false

    // MARK: - UI

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorInset = UIEdgeInsets(top: 0, left: 46, bottom: 0, right: 0)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Init

    init(category: Category, viewModel: TodayViewModel) {
        self.category = category
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        updateTitle()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setupSwipes()
        setupMenu()
        setupTableView()
        setupBindings()
    }

    // MARK: - Setup

    // MARK: - Листание между категориями

    private func updateTitle() {
        let all = DataStore.shared.fetchCategories()
        if let index = all.firstIndex(where: { $0 === category }), all.count > 1 {
            title = "\(category.name) · \(index + 1)/\(all.count)"
        } else {
            title = category.name
        }
    }

    private func setupSwipes() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
        left.direction = .left
        left.delegate = self
        view.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
        right.direction = .right
        right.delegate = self
        view.addGestureRecognizer(right)
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        // Влево = следующая категория, вправо = предыдущая.
        let step = gesture.direction == .left ? 1 : -1
        let all = DataStore.shared.fetchCategories()
        guard all.count > 1,
              let index = all.firstIndex(where: { $0 === category }),
              all.indices.contains(index + step)
        else { return }   // у края списка — тихо ничего не делаем

        category = all[index + step]
        Haptics.light()
        updateTitle()

        // Слайд-переход таблицы в сторону свайпа.
        let transition = CATransition()
        transition.type = .push
        transition.subtype = step == 1 ? .fromRight : .fromLeft
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tableView.layer.add(transition, forKey: "categorySwipe")
        tableView.reloadData()
    }

    private func setupMenu() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: makeMenu()
        )
    }

    // Меню пересоздаётся после каждого переключения:
    // UIMenu неизменяем, галочку (state) нельзя обновить «на месте».
    private func makeMenu() -> UIMenu {
        let dailyAction = UIAction(
            title: "Повторять каждый день",
            image: UIImage(systemName: "repeat"),
            state: category.isDaily ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.toggleDaily(category)
            Haptics.light()
            navigationItem.rightBarButtonItem?.menu = makeMenu()
        }

        let deleteAction = UIAction(
            title: "Удалить категорию",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.confirmDeleteCategory()
        }

        return UIMenu(children: [dailyAction, deleteAction])
    }

    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.dataSource = self
        tableView.delegate = self
        // Self-sizing: высота ячейки берётся из её констрейнтов
        // (минимум + внутренние отступы), а не из дефолтных 44pt.
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.register(TaskCell.self, forCellReuseIdentifier: TaskCell.reuseId)
    }

    private func setupBindings() {
        viewModel.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !isDeletingCategory else { return }
                tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    private func confirmDeleteCategory() {
        let alert = UIAlertController(
            title: "Удалить «\(category.name)»?",
            message: "Все задачи категории тоже будут удалены",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            isDeletingCategory = true
            viewModel.deleteCategory(category)
            navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showTaskSheet(taskToEdit: TaskItem? = nil) {
        let vc = AddTaskViewController(category: category, viewModel: viewModel, taskToEdit: taskToEdit)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(nav, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension CategoryDetailViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Задачи + строка «Добавить задачу»
        category.sortedTasks.count + 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "+\(category.earnedPoints) / \(category.totalPoints) баллов"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tasks = category.sortedTasks
        let color = CategoryColor.named(category.colorName)

        // Последняя строка — «добавить задачу»
        if indexPath.row == tasks.count {
            let cell = UITableViewCell()
            cell.backgroundColor = .clear
            var config = cell.defaultContentConfiguration()
            config.text = "Добавить задачу"
            config.textProperties.color = color.main
            config.image = UIImage(systemName: "plus.circle.fill")
            config.imageProperties.tintColor = color.main
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: TaskCell.reuseId, for: indexPath
        ) as! TaskCell
        cell.configure(with: tasks[indexPath.row], color: color)
        cell.delegate = self
        return cell
    }
}

// MARK: - UITableViewDelegate

extension CategoryDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tasks = category.sortedTasks
        if indexPath.row == tasks.count {
            // Строка «Добавить задачу»
            showTaskSheet()
        } else {
            // Тап по задаче (мимо чекбокса — он отдельная кнопка) — редактируем
            showTaskSheet(taskToEdit: tasks[indexPath.row])
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let tasks = category.sortedTasks
        guard indexPath.row < tasks.count else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") {
            [weak self] _, _, completion in
            self?.viewModel.deleteTask(tasks[indexPath.row])
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - TaskCellDelegate

extension CategoryDetailViewController: TaskCellDelegate {

    func taskCell(_ cell: TaskCell, didToggle task: TaskItem) {
        Haptics.light()  // лёгкий тактильный отклик на отметку
        viewModel.toggleTask(task)
    }
}

// MARK: - Развод жестов со свайп-действиями строк

extension CategoryDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let swipe = gestureRecognizer as? UISwipeGestureRecognizer else { return true }
        // Свайп ВЛЕВО прямо над строкой задачи — это её действия
        // (Удалить/Изменить), а не листание. Уступаем строке.
        // Вправо у строк действий нет — листаем откуда угодно.
        if swipe.direction == .left {
            let point = swipe.location(in: tableView)
            if tableView.indexPathForRow(at: point) != nil { return false }
        }
        return true
    }
}

