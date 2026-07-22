//
//  TodayViewModel.swift
//  Questly
//
//  ViewModel главного экрана. Схема осталась прежней (MVVM + Combine),
//  но вместо самостоятельного хранения данных ViewModel теперь читает
//  их из DataStore и подписывается на его шину изменений.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class TodayViewModel {

    // MARK: - Published свойства

    @Published private(set) var categories: [Category] = []
    @Published private(set) var streak: Int = 0

    // MARK: - Зависимости

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Любое сохранение в DataStore (в том числе из настроек) —
        // и мы перечитываем данные. UI обновится сам через @Published.
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        store.performDayRolloverIfNeeded()
        reload()
    }

    // MARK: - Вычисляемые свойства

    var dayScore: DayScore {
        // Баллы буквальные: сумма очков выполненных задач, максимум 100.
        DayScore(earnedPoints: categories.reduce(0) { $0 + $1.earnedPoints })
    }

    /// Сколько очков всего запланировано на день —
    /// нужно шапке для подсказки «задач меньше чем на 100».
    var totalPlanned: Int {
        categories.reduce(0) { $0 + $1.totalPoints }
    }

    // MARK: - Публичные методы

    func reload() {
        categories = store.fetchCategories()
        streak = store.currentStreak(todayScore: dayScore.value)
    }

    /// Проверка переката дня — дёргаем при возврате приложения из фона
    func checkRollover() {
        store.performDayRolloverIfNeeded()
    }

    func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted { SoundService.play(.taskDone) }
        store.save()
    }

    func addTask(name: String, points: Int, note: String = "",
                 dueDate: Date?, endDate: Date?, to category: Category) {
        let task = TaskItem(name: name, points: points, dueDate: dueDate, endDate: endDate)
        task.note = note
        store.context.insert(task)
        task.category = category   // SwiftData сам обновит обратную сторону связи
        store.save()
    }

    func deleteTask(_ task: TaskItem) {
        store.context.delete(task)
        store.save()
    }

    func updateTask(_ task: TaskItem, name: String, points: Int, note: String = "",
                    dueDate: Date?, endDate: Date?) {
        // SwiftData отслеживает изменения свойств @Model-объектов сам —
        // достаточно присвоить новые значения и сохранить.
        task.name = name
        task.points = points
        task.note = note
        task.dueDate = dueDate
        task.endDate = endDate
        store.save()
    }

    func addCategory(name: String, icon: String, colorName: String, isDaily: Bool) {
        let category = Category(name: name, icon: icon, colorName: colorName, isDaily: isDaily)
        store.context.insert(category)
        store.save()
    }

    func toggleDaily(_ category: Category) {
        category.isDaily.toggle()
        store.save()
    }

    func togglePinned(_ category: Category) {
        category.isPinned.toggle()
        store.save()   // save() шлёт changes → сетка перечитает и пересортирует
    }

    func deleteCategory(_ category: Category) {
        // .cascade в модели удалит и все задачи категории.
        store.context.delete(category)
        store.save()
    }
}
