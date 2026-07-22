//
//  DataStore.swift
//  Questly
//
//  Единая точка доступа к SwiftData. ViewModel-и не работают
//  с ModelContext напрямую — только через этот класс.
//  Это тот самый «StorageService»: если однажды захотим сменить
//  хранилище (CloudKit, файлы), поменяем только этот файл.
//

import Foundation
import SwiftData
import Combine
import WidgetKit

@MainActor
final class DataStore {

    // Синглтон — база одна на всё приложение.
    static let shared = DataStore()

    // MARK: - SwiftData

    let container: ModelContainer

    // mainContext — контекст, привязанный к главному потоку.
    // Для UIKit-приложения с работой из UI это ровно то, что нужно.
    var context: ModelContext { container.mainContext }

    // MARK: - Combine

    // «Шина изменений»: после каждого сохранения шлём событие,
    // а ViewModel-и подписаны на него и перечитывают данные.
    let changes = PassthroughSubject<Void, Never>()

    // MARK: - Ключи UserDefaults
    // Сами данные теперь в SwiftData, но мелкие служебные флаги
    // (какой день был активен последним) удобно держать в UserDefaults.

    private let lastActiveDayKey = "dq_last_active_day"
    private let totalXPKey = "dq_total_xp"
    private let jokersKey = "dq_jokers"
    private let jokerWeekKey = "dq_joker_week"          // ISO-неделя последней недельной выдачи
    private let savableDayKey = "dq_savable_day"        // день, который можно спасти джокером
    private let savedDaysKey = "dq_saved_days"          // [Date] спасённых дней (для стрика)

    // MARK: - Общий XP
    //
    // XP теперь ХРАНИТСЯ, а не вычисляется из истории: штрафы
    // с «полом в ноль» зависят от порядка событий — из суммы
    // заработанного и суммы штрафов их не восстановить однозначно.

    /// Общий XP за всё время: заработанное минус штрафы, не ниже 0
    var totalXP: Int {
        seedXPIfNeeded()
        return UserDefaults.standard.integer(forKey: totalXPKey)
    }

    private func setTotalXP(_ value: Int) {
        // max(0, ...) — то самое правило «в минус уйти нельзя»
        UserDefaults.standard.set(max(0, value), forKey: totalXPKey)
    }

    /// Разовый бонус XP — награда за пройденный челлендж и т.п.
    func awardBonusXP(_ amount: Int) {
        setTotalXP(totalXP + amount)
        changes.send()   // профиль и пилюля уровня обновятся сами
    }

    // MARK: - Джокеры (спасение стрика)

    /// Сколько джокеров в запасе
    var jokers: Int {
        UserDefaults.standard.integer(forKey: jokersKey)
    }

    private func setJokers(_ value: Int) {
        // Не больше максимума и не меньше нуля.
        UserDefaults.standard.set(min(max(value, 0), AppConfig.maxJokers), forKey: jokersKey)
    }

    /// Начисляет джокеры: недельный (1 раз в новую неделю) и за
    /// идеальные дни. Безопасно вызывать при каждом старте.
    func grantJokersIfNeeded() {
        let defaults = UserDefaults.standard
        let before = jokers
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        // Недельный джокер — раз в календарную неделю.
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let weekTag = "\(year)-\(weekOfYear)"
        if defaults.string(forKey: jokerWeekKey) != weekTag {
            defaults.set(weekTag, forKey: jokerWeekKey)
            setJokers(jokers + 1)
        }

        // За идеальные дни: 1 джокер на каждые N идеальных, но выданное
        // за них считаем один раз через «сколько уже выдано».
        let perfectDays = fetchRecords().filter { $0.score >= 100 }.count
        let deserved = perfectDays / AppConfig.perfectDaysPerJoker
        let alreadyGranted = defaults.integer(forKey: "dq_joker_from_perfect")
        if deserved > alreadyGranted {
            defaults.set(deserved, forKey: "dq_joker_from_perfect")
            setJokers(jokers + (deserved - alreadyGranted))
        }

        // Если запас изменился — уведомляем подписчиков (профиль обновит счётчик).
        if jokers != before {
            changes.send()
        }
    }

    // MARK: Спасаемый день

    /// День (startOfDay), который сейчас можно спасти джокером, или nil
    var savableDay: Date? {
        UserDefaults.standard.object(forKey: savableDayKey) as? Date
    }

    /// Множество спасённых дней — они считаются успешными для стрика
    private func savedDays() -> Set<Date> {
        let arr = (UserDefaults.standard.array(forKey: savedDaysKey) as? [Date]) ?? []
        return Set(arr.map { Calendar.current.startOfDay(for: $0) })
    }

    func isDaySaved(_ day: Date) -> Bool {
        savedDays().contains(Calendar.current.startOfDay(for: day))
    }

    /// Потратить джокер и спасти отложенный день. true — получилось.
    @discardableResult
    func spendJokerToSave() -> Bool {
        guard jokers > 0, let day = savableDay else { return false }
        setJokers(jokers - 1)

        var saved = Array(savedDays())
        saved.append(Calendar.current.startOfDay(for: day))
        UserDefaults.standard.set(saved, forKey: savedDaysKey)
        UserDefaults.standard.removeObject(forKey: savableDayKey)

        changes.send()
        refreshWidgetAndNotifications()
        return true
    }

    /// Пользователь отказался спасать — просто снимаем предложение.
    func dismissSavableDay() {
        UserDefaults.standard.removeObject(forKey: savableDayKey)
    }

    // Первый запуск после обновления: у пользователя уже есть история,
    // но ещё нет сохранённого XP — засеваем суммой заработанного.
    private func seedXPIfNeeded() {
        guard UserDefaults.standard.object(forKey: totalXPKey) == nil else { return }
        let earned = fetchRecords().reduce(0) { $0 + $1.earnedPoints }
        UserDefaults.standard.set(earned, forKey: totalXPKey)
    }

    // MARK: - Init

    private init() {
        do {
            container = try ModelContainer(
                for: Category.self, TaskItem.self, DayRecord.self,
                HabitCounter.self, GoodHabit.self, PlannedItem.self, MoodEntry.self,
                MonthPlanItem.self, YearGoal.self, WeekPlanItem.self
            )
        } catch {
            // Если контейнер не создался — приложение неработоспособно,
            // падаем сразу с понятным сообщением.
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    // MARK: - Чтение

    func fetchHabitCounters() -> [HabitCounter] {
        let descriptor = FetchDescriptor<HabitCounter>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchGoodHabits() -> [GoodHabit] {
        let descriptor = FetchDescriptor<GoodHabit>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Запланированные пункты на конкретный день
    func fetchPlanned(on day: Date) -> [PlannedItem] {
        let start = Calendar.current.startOfDay(for: day)
        let all = (try? context.fetch(
            FetchDescriptor<PlannedItem>(sortBy: [SortDescriptor(\.timeText)])
        )) ?? []
        return all.filter { Calendar.current.isDate($0.date, inSameDayAs: start) }
    }

    /// Есть ли запланированное на сегодня (для баннера на главном)
    func hasPlannedToday() -> Bool {
        !fetchPlanned(on: Date()).isEmpty
    }

    // MARK: - План месяца

    /// Задачи месяца, к которому принадлежит дата
    func fetchMonthPlan(for month: Date) -> [MonthPlanItem] {
        let start = MonthPlanItem.startOfMonth(month)
        let all = (try? context.fetch(
            FetchDescriptor<MonthPlanItem>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { Calendar.current.isDate($0.month, equalTo: start, toGranularity: .month) }
    }

    /// Дела недели, к которой принадлежит дата
    func fetchWeekPlan(for week: Date) -> [WeekPlanItem] {
        let start = WeekPlanItem.startOfWeek(week)
        let all = (try? context.fetch(
            FetchDescriptor<WeekPlanItem>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { $0.weekStart == start }
    }

    /// Невыполненные дела прошлых недель — «хвосты»
    func fetchOverdueWeekPlan(before week: Date) -> [WeekPlanItem] {
        let start = WeekPlanItem.startOfWeek(week)
        let all = (try? context.fetch(
            FetchDescriptor<WeekPlanItem>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { $0.weekStart < start && !$0.isDone }
    }

    /// Цели указанного года
    func fetchYearGoals(year: Int) -> [YearGoal] {
        let all = (try? context.fetch(
            FetchDescriptor<YearGoal>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { $0.year == year }
    }

    /// Невыполненные задачи из месяцев ДО указанного — «хвосты»
    func fetchOverdueMonthPlan(before month: Date) -> [MonthPlanItem] {
        let start = MonthPlanItem.startOfMonth(month)
        let all = (try? context.fetch(
            FetchDescriptor<MonthPlanItem>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { $0.month < start && !$0.isDone }
    }

    // MARK: - Настроение

    func allMoodEntries() -> [MoodEntry] {
        (try? context.fetch(
            FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
    }

    func moodEntry(on day: Date) -> MoodEntry? {
        let start = Calendar.current.startOfDay(for: day)
        return allMoodEntries().first { Calendar.current.isDate($0.date, inSameDayAs: start) }
    }

    /// Отметить настроение сегодня (создать или обновить запись дня)
    func setMoodToday(value: Int, note: String) {
        if let existing = moodEntry(on: Date()) {
            existing.value = min(max(value, 1), 5)
            existing.note = note
        } else {
            context.insert(MoodEntry(date: Date(), value: value, note: note))
        }
        save()
    }

    /// Среднее настроение за последние N дней (nil — записей нет)
    func averageMood(lastDays: Int) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date())!
        let recent = allMoodEntries().filter { $0.date >= Calendar.current.startOfDay(for: cutoff) }
        guard !recent.isEmpty else { return nil }
        return Double(recent.reduce(0) { $0 + $1.value }) / Double(recent.count)
    }

    func fetchCategories() -> [Category] {
        // Сортируем по дате создания на уровне запроса, а закреплённые
        // поднимаем вперёд уже в памяти. Причина: SwiftData SortDescriptor
        // по Bool ведёт себя неочевидно, а стабильная ручная сортировка
        // предсказуема и надёжна.
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.createdAt)])
        let categories = (try? context.fetch(descriptor)) ?? []
        // stable partition: закреплённые сохраняют порядок по дате между собой.
        return categories.filter(\.isPinned) + categories.filter { !$0.isPinned }
    }

    func fetchRecords() -> [DayRecord] {
        let descriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Сохранение

    func save() {
        try? context.save()
        changes.send()  // сообщаем всем подписчикам: данные изменились
        publishWidgetSnapshot()
    }

    // MARK: - Виджет
    //
    // При каждом сохранении кладём в общий UserDefaults (App Group)
    // компактный снимок и просим систему перерисовать виджеты.

    private func publishWidgetSnapshot() {
        let categories = fetchCategories()
        let earned = categories.reduce(0) { $0 + $1.earnedPoints }
        let score = DayScore(earnedPoints: earned)
        let streak = currentStreak(todayScore: score.value)

        let pending = categories
            .flatMap(\.sortedTasks)
            .filter { !$0.isCompleted }
            .prefix(4)
            .map { WidgetSnapshot.PendingTask(name: $0.name, points: $0.points,
                                              id: Self.widgetTaskID(of: $0)) }

        let snapshot = WidgetSnapshot(
            score: score.value,
            rawPoints: score.rawPoints,
            statusLabel: score.label,
            statusEmoji: score.emoji,
            streak: streak,
            level: LevelSystem.userLevel(totalPoints: totalXP + earned).level,
            pendingTasks: Array(pending),
            yearGoals: fetchYearGoals(year: Calendar.current.component(.year, from: Date()))
                .filter { !$0.isDone }
                .prefix(4)
                .map(\.title)
        )
        snapshot.save()

        WidgetCenter.shared.reloadAllTimelines()

        // Умные уведомления живут по тому же принципу, что и виджет:
        // пересобираем расписание с актуальными цифрами.
        NotificationService.reschedule(score: score.value, streak: streak)
    }

    /// Публичная обёртка: пересобрать виджет и уведомления
    /// без изменения данных (например, после включения тумблера).
    func refreshWidgetAndNotifications() {
        publishWidgetSnapshot()
    }

    // MARK: - Команды с интерактивного виджета
    //
    // Тап по задаче на виджете кладёт её ID в очередь (App Group) —
    // виджет живёт в другом процессе и до стора не дотягивается.
    // Здесь применяем очередь к настоящим данным.

    /// Стабильный ID задачи для снапшота: закодированный
    /// persistentModelID. Виджет вернёт его как есть.
    /// sortedKeys обязателен: без него порядок ключей JSON меняется
    /// от запуска к запуску (рандомизация хэшей), и строки-ID
    /// перестают совпадать сами с собой.
    private static func widgetTaskID(of task: TaskItem) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(task.persistentModelID))?.base64EncodedString()
    }

    /// Применить накопленные на виджете «выполнено» к стору.
    /// Дёргается при запуске и выходе на передний план.
    /// Сравниваем ДЕКОДИРОВАННЫЕ PersistentIdentifier, а не строки:
    /// идентификаторам порядок ключей JSON безразличен.
    func applyPendingWidgetCompletions() {
        let ids = WidgetSnapshot.drainCompletions()
        guard !ids.isEmpty else { return }

        let queued: [PersistentIdentifier] = ids.compactMap {
            guard let data = Data(base64Encoded: $0) else { return nil }
            return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        }
        guard !queued.isEmpty else { return }

        let allTasks = fetchCategories().flatMap(\.sortedTasks)
        var changed = false
        for pid in queued {
            if let task = allTasks.first(where: { $0.persistentModelID == pid }),
               !task.isCompleted {
                task.isCompleted = true
                changed = true
            }
        }
        // save() пересоберёт снапшот из истинного состояния и разошлёт
        // changes — все экраны обновятся сами.
        if changed { save() }
    }

    // MARK: - Перекат дня
    //
    // Вызывается при запуске и при возврате приложения из фона.
    // Если наступил новый день: сохраняем снимок прошлого дня в DayRecord
    // и снимаем отметки со всех задач.

    func performDayRolloverIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaults = UserDefaults.standard

        // Первый запуск — просто запоминаем сегодняшний день.
        guard let lastActive = defaults.object(forKey: lastActiveDayKey) as? Date else {
            defaults.set(today, forKey: lastActiveDayKey)
            return
        }

        let lastDay = calendar.startOfDay(for: lastActive)
        guard lastDay < today else { return }  // всё ещё тот же день

        // Сколько календарных дней прошло. Больше одного —
        // значит, были полностью пропущенные дни.
        let daysGap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 1

        let categories = fetchCategories()
        let total  = categories.reduce(0) { $0 + $1.totalPoints }
        let earned = categories.reduce(0) { $0 + $1.earnedPoints }
        let score = DayScore(earnedPoints: earned).value
        let allTasks = categories.flatMap(\.tasks)

        // ШТРАФ 1: невыполненные задачи — их стоимость × множитель.
        let missedPenalty = allTasks
            .filter { !$0.isCompleted }
            .reduce(0) { $0 + $1.points }
            * AppConfig.missedTaskPenaltyMultiplier

        // ШТРАФ 2: обрыв длинного стрика.
        // Считаем, каким был стрик на момент обрыва: серия успешных
        // дней из истории до закрываемого дня (+ сам день, если удался).
        let closingSucceeded = score >= AppConfig.streakThreshold
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: lastDay)!
        let streakBefore = recordStreak(endingOn: dayBefore)
        let streakAtBreak = closingSucceeded ? streakBefore + 1 : streakBefore

        // Стрик оборвался, если закрываемый день провален
        // ИЛИ после него были полностью пропущенные дни.
        let streakBroke = !closingSucceeded || daysGap > 1

        // Если день провален, но стрик был значимым и есть джокеры —
        // откладываем день как «спасаемый»: НЕ штрафуем за обрыв сейчас,
        // а предложим спасти джокером при заходе. Штраф за невыполненные
        // задачи остаётся в любом случае.
        let canOfferSave = streakBroke && streakBefore >= 3 && jokers > 0 && daysGap == 1

        let streakPenalty: Int
        if canOfferSave {
            // Откладываем решение пользователю — штраф за стрик пока не берём.
            defaults.set(lastDay, forKey: savableDayKey)
            streakPenalty = 0
        } else {
            streakPenalty = (streakBroke && streakAtBreak >= AppConfig.streakPenaltyMinLength)
                ? AppConfig.streakBreakPenalty
                : 0
        }

        // Записываем день в историю, только если были запланированы задачи.
        if total > 0 {
            let existing = fetchRecords().first { calendar.isDate($0.date, inSameDayAs: lastDay) }
            if existing == nil {
                let record = DayRecord(
                    date: lastDay,
                    score: score,
                    earnedPoints: earned,
                    totalPoints: total,
                    completedTasks: allTasks.filter(\.isCompleted).count,
                    totalTasks: allTasks.count,
                    penaltyPoints: missedPenalty + streakPenalty
                )
                context.insert(record)
            }
        }

        // Обновляем общий XP: плюс заработанное за день, минус штрафы.
        // setTotalXP зажимает результат на нуле.
        setTotalXP(totalXP + earned - missedPenalty - streakPenalty)

        // Разовые категории прожили свой день: их результат уже попал
        // в снимок выше — удаляем вместе с задачами (cascade).
        categories.filter { !$0.isDaily }.forEach { context.delete($0) }

        // Новый день — задачи оставшихся категорий снова невыполнены.
        // Перечитываем категории: после удаления старый массив
        // содержит невалидные объекты.
        fetchCategories().flatMap(\.tasks).forEach { $0.isCompleted = false }

        defaults.set(today, forKey: lastActiveDayKey)
        grantJokersIfNeeded()
        save()
    }

    /// Длина серии успешных дней из истории, заканчивающейся заданным днём.
    /// Спасённые джокером дни считаются успешными.
    private func recordStreak(endingOn endDay: Date) -> Int {
        let calendar = Calendar.current
        let recordsByDate = Dictionary(
            fetchRecords().map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let saved = savedDays()
        var streak = 0
        var day = calendar.startOfDay(for: endDay)
        while true {
            let passedByScore = (recordsByDate[day]?.score ?? 0) >= AppConfig.streakThreshold
            let passedByJoker = saved.contains(day)
            guard passedByScore || passedByJoker else { break }
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // MARK: - Стрик
    //
    // Стрик считаем «на лету» из истории, а не храним отдельным числом:
    // так он всегда честный и не может рассинхронизироваться с данными.
    // День входит в стрик, если его балл >= AppConfig.streakThreshold.

    func currentStreak(todayScore: Int) -> Int {
        let calendar = Calendar.current
        let recordsByDate = Dictionary(
            fetchRecords().map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Сегодня в стрике, если порог уже взят.
        var streak = todayScore >= AppConfig.streakThreshold ? 1 : 0

        // Идём назад от вчерашнего дня, пока дни «успешные»
        // (по баллам ИЛИ спасённые джокером).
        let saved = savedDays()
        var day = calendar.date(byAdding: .day, value: -1,
                                to: calendar.startOfDay(for: Date()))!
        while true {
            let passedByScore = (recordsByDate[day]?.score ?? 0) >= AppConfig.streakThreshold
            guard passedByScore || saved.contains(day) else { break }
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // MARK: - Сервисные операции (для экрана настроек)

    /// Снять все отметки за сегодня
    func resetToday() {
        fetchCategories().flatMap(\.tasks).forEach { $0.isCompleted = false }
        save()
    }

    /// Полностью стереть все данные приложения
    /// Удалить все объекты одного типа — через выборку, по одному.
    /// НЕ через context.delete(model:): батч-удаление SwiftData чистит
    /// базу в обход контекста, закэшированные объекты остаются в памяти,
    /// и экраны продолжают показывать «удалённые» данные до перезапуска.
    private func wipe<T: PersistentModel>(_ type: T.Type) {
        do {
            let items = try context.fetch(FetchDescriptor<T>())
            print("🧨 wipe \(type): найдено \(items.count)")
            for item in items { context.delete(item) }
        } catch {
            print("🧨 wipe \(type): ОШИБКА выборки — \(error)")
        }
    }

    func deleteAllData() {
        print("🧨 deleteAllData: СТАРТ")
        // Все SwiftData-модели. Порядок: сначала «дети» (задачи),
        // потом «родители» (категории) — меньше сюрпризов со связями.
        wipe(TaskItem.self)
        wipe(Category.self)
        wipe(DayRecord.self)
        wipe(HabitCounter.self)
        wipe(GoodHabit.self)
        wipe(PlannedItem.self)
        wipe(MoodEntry.self)
        wipe(MonthPlanItem.self)
        wipe(YearGoal.self)
        wipe(WeekPlanItem.self)

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastActiveDayKey)
        defaults.removeObject(forKey: totalXPKey)
        // Джокеры и их служебные ключи.
        defaults.removeObject(forKey: jokersKey)
        defaults.removeObject(forKey: jokerWeekKey)
        defaults.removeObject(forKey: savableDayKey)
        defaults.removeObject(forKey: savedDaysKey)
        defaults.removeObject(forKey: "dq_joker_from_perfect")

        // Прогресс челленджей и открытые ачивки живут в UserDefaults.
        // Чистим через их же хранилища — формат ключей остаётся
        // в одном месте, без хрупких дублей строк здесь.
        ChallengeStore.resetAll()
        AchievementStore.resetAll()
        DailyQuestCatalog.reset()
        PomodoroStats.reset()

        do {
            try context.save()
            print("🧨 deleteAllData: сохранение ОК")
        } catch {
            print("🧨 deleteAllData: сохранение УПАЛО — \(error)")
        }
        save()   // штатный путь: снапшот виджета + рассылка changes
        print("🧨 deleteAllData: ФИНИШ")
    }

    // MARK: - Статистика для профиля

    func profileStats() -> ProfileStats {
        let calendar = Calendar.current
        let records = fetchRecords()
        let categories = fetchCategories()

        // Сегодняшний день считаем «вживую» — записи за него ещё нет.
        let todayEarned = categories.reduce(0) { $0 + $1.earnedPoints }
        let todayScore = DayScore(earnedPoints: todayEarned).value
        let todayCompleted = categories.reduce(0) { $0 + $1.completedCount }

        // Множество «успешных» дней (порог стрика взят).
        var successDays = Set(
            records.filter { $0.score >= AppConfig.streakThreshold }
                .map { calendar.startOfDay(for: $0.date) }
        )
        if todayScore >= AppConfig.streakThreshold {
            successDays.insert(calendar.startOfDay(for: Date()))
        }

        // Лучший стрик: для каждого дня-НАЧАЛА серии (перед ним нет
        // успешного дня) идём вперёд и меряем длину серии.
        var bestStreak = 0
        for day in successDays {
            let previous = calendar.date(byAdding: .day, value: -1, to: day)!
            guard !successDays.contains(previous) else { continue }

            var length = 1
            var next = calendar.date(byAdding: .day, value: 1, to: day)!
            while successDays.contains(next) {
                length += 1
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            bestStreak = max(bestStreak, length)
        }

        let perfectDays = records.filter { $0.score >= 100 }.count
            + (todayScore >= 100 ? 1 : 0)

        return ProfileStats(
            currentStreak: currentStreak(todayScore: todayScore),
            bestStreak: bestStreak,
            perfectDays: perfectDays,
            totalTasksCompleted: records.reduce(0) { $0 + $1.completedTasks } + todayCompleted,
            // XP = сохранённое значение (уже с учётом штрафов)
            // + сегодняшние очки «вживую».
            totalPointsEarned: totalXP + todayEarned
        )
    }
}

// MARK: - ProfileStats
// Снимок статистики для экрана профиля.

struct ProfileStats {
    let currentStreak: Int
    let bestStreak: Int
    let perfectDays: Int
    let totalTasksCompleted: Int
    let totalPointsEarned: Int
}
