//
//  Challenges.swift
//  Questly
//
//  Недельные челленджи: описание (каталог) и прогресс пользователя.
//  Прогресс хранится в UserDefaults как Codable-структура —
//  челленджи самодостаточны и не пересекаются с основной базой.
//

import Foundation

// MARK: - Описание челленджа (каталог, статика)

struct ChallengeTask {
    let emoji: String
    let title: String
    let subtitle: String
}

struct Challenge {
    let id: String
    let emoji: String
    let title: String
    let details: String
    /// Ровно 7 дней, Пн–Вс. Задачи каждого дня.
    let days: [[ChallengeTask]]

    /// Награда за полное прохождение
    static let rewardXP = 300
}

enum ChallengeCatalog {

    static let all: [Challenge] = [goodMorning, goodNight, pushups100, pullups30, runningWeek]

    static func challenge(id: String) -> Challenge? {
        all.first { $0.id == id }
    }

    // «Доброе утро»: задачи накапливаются — каждый день повторяются
    // прежние и добавляется одна новая. Воскресенье — только награда.
    static let goodMorning: Challenge = {
        let curtains = ChallengeTask(
            emoji: "🌅", title: "Открой шторы и посмотри в окно",
            subtitle: "Постарайся получить солнечный свет"
        )
        let water = ChallengeTask(
            emoji: "💧", title: "Стакан воды после сна",
            subtitle: "Взбодрись и начни день правильно!"
        )
        let breakfast = ChallengeTask(
            emoji: "🍏", title: "Приготовь полезный завтрак",
            subtitle: "Зарядись энергией на весь день"
        )
        let exercise = ChallengeTask(
            emoji: "🤸", title: "Сделай зарядку",
            subtitle: "Разбуди тело — хватит и 10 минут"
        )
        let noPhone = ChallengeTask(
            emoji: "📵", title: "Час утра без телефона",
            subtitle: "Первый час дня принадлежит тебе"
        )
        let walk = ChallengeTask(
            emoji: "🚶", title: "15-минутная прогулка",
            subtitle: "Свежий воздух творит чудеса"
        )
        let breathing = ChallengeTask(
            emoji: "🌬️", title: "Дыхательная гимнастика",
            subtitle: "Пара минут спокойствия перед делами"
        )
        let treat = ChallengeTask(
            emoji: "🍰", title: "Побалуй себя",
            subtitle: "Съешь что-нибудь вкусное — ты заслужил"
        )

        // Наращиваем: Пн — 2 задачи, дальше +1 новая в день.
        let growing = [curtains, water, breakfast, exercise, noPhone, walk, breathing]
        var days: [[ChallengeTask]] = []
        for day in 0..<6 {
            days.append(Array(growing.prefix(2 + day)))
        }
        days.append([treat])   // воскресенье

        return Challenge(
            id: "good_morning",
            emoji: "☀️",
            title: "Доброе утро",
            details: "Неделя правильных утренних привычек. Каждый день — одна новая задача.",
            days: days
        )
    }()

    // «Спокойной ночи»: неделя вечерних ритуалов для здорового сна.
    // Накопительно, как «Доброе утро»: каждый день новая задача,
    // прежние повторяются. Седьмой день — награда.
    static let goodNight: Challenge = {
        let shower = ChallengeTask(
            emoji: "🚿", title: "Тёплый душ за час до сна",
            subtitle: "Помогает телу расслабиться и настроиться на сон"
        )
        let noScreens = ChallengeTask(
            emoji: "📵", title: "Убери экраны за час до сна",
            subtitle: "Синий свет мешает выработке мелатонина"
        )
        let reading = ChallengeTask(
            emoji: "📖", title: "Почитай книгу",
            subtitle: "Несколько страниц вместо ленты — и мысли замедляются"
        )
        let breathing = ChallengeTask(
            emoji: "🌬️", title: "Дыхательная практика",
            subtitle: "Медленное дыхание успокаивает нервную систему"
        )
        let sound = ChallengeTask(
            emoji: "🌧️", title: "Включи спокойный звук",
            subtitle: "Дождь, белый шум — что помогает уснуть именно тебе"
        )
        let journal = ChallengeTask(
            emoji: "📝", title: "Выпиши мысли и план на завтра",
            subtitle: "Освободи голову — и заснёшь спокойнее"
        )
        let reward = ChallengeTask(
            emoji: "🍽️", title: "Награди себя",
            subtitle: "Неделя позади — сходи в ресторан или порадуй себя иначе"
        )

        // Накопление: день 1 — 1 задача, день 6 — все шесть.
        let growing = [shower, noScreens, reading, breathing, sound, journal]
        var days: [[ChallengeTask]] = []
        for day in 0..<6 {
            days.append(Array(growing.prefix(1 + day)))
        }
        days.append([reward])   // седьмой день — награда

        return Challenge(
            id: "good_night",
            emoji: "🌙",
            title: "Спокойной ночи",
            details: "Неделя вечерних ритуалов для крепкого сна. Каждый день — новая привычка.",
            days: days
        )
    }()

    // «100 отжиманий»: шесть дней подряд по 100 отжиманий,
    // седьмой день — заслуженный отдых.
    static let pushups100: Challenge = {
        let pushups = ChallengeTask(
            emoji: "💪", title: "100 отжиманий",
            subtitle: "Можно разбить на подходы — главное набрать сотню"
        )
        let rest = ChallengeTask(
            emoji: "🛌", title: "Награди себя отдыхом",
            subtitle: "Мышцы растут во время восстановления — ты заслужил паузу"
        )

        var days = Array(repeating: [pushups], count: 6)
        days.append([rest])   // воскресенье — отдых

        return Challenge(
            id: "pushups_100",
            emoji: "💪",
            title: "100 отжиманий",
            details: "Шесть дней по 100 отжиманий, седьмой — отдых. Сила куётся повторением.",
            days: days
        )
    }()

    // «30 подтягиваний»: шесть дней подряд по 30 подтягиваний,
    // седьмой день — отдых. Механика как у «100 отжиманий».
    static let pullups30: Challenge = {
        let pullups = ChallengeTask(
            emoji: "🏋️", title: "30 подтягиваний",
            subtitle: "Можно разбить на подходы — главное набрать тридцать"
        )
        let rest = ChallengeTask(
            emoji: "🛌", title: "Награди себя отдыхом",
            subtitle: "Спина и руки растут во время восстановления — отдохни"
        )

        var days = Array(repeating: [pullups], count: 6)
        days.append([rest])   // воскресенье — отдых

        return Challenge(
            id: "pullups_30",
            emoji: "🏋️",
            title: "30 подтягиваний",
            details: "Шесть дней по 30 подтягиваний, седьмой — отдых. Сила куётся повторением.",
            days: days
        )
    }()

    // «Неделя бега»: нагрузка растёт через день, между пробежками —
    // восстановление. Каждый день своя задача (не накопительно).
    static let runningWeek: Challenge = {
        let days: [[ChallengeTask]] = [
            [ChallengeTask(emoji: "🏃", title: "Пробежка 20 минут",
                           subtitle: "Лёгкий темп — просто разбегаемся")],
            [ChallengeTask(emoji: "🏃", title: "Пробежка 3 км",
                           subtitle: "Дистанция вместо времени — держи комфортный темп")],
            [ChallengeTask(emoji: "😌", title: "Выходной",
                           subtitle: "Отдыхай и набирайся сил — мышцы растут в покое")],
            [ChallengeTask(emoji: "🏃", title: "Пробежка 5 км",
                           subtitle: "Чуть дальше, чем позавчера. Ты можешь")],
            [ChallengeTask(emoji: "🧘", title: "Выходной",
                           subtitle: "Подготовка к главному дню: сон, вода, растяжка")],
            [ChallengeTask(emoji: "🏃", title: "Пробежка 15 км",
                           subtitle: "Главный вызов недели. Темп не важен — важно добежать")],
            [ChallengeTask(emoji: "🍰", title: "Порадуй себя чем-нибудь вкусным",
                           subtitle: "Неделя бега позади — ты это заслужил")]
        ]

        return Challenge(
            id: "running_week",
            emoji: "🏃",
            title: "Неделя бега",
            details: "Три пробежки с ростом дистанции, между ними — восстановление. Финал — 15 км и заслуженная награда.",
            days: days
        )
    }()
}

// MARK: - Прогресс пользователя

struct ChallengeRun: Codable {
    var challengeID: String
    var weekStart: Date              // понедельник недели старта
    var completedMarks: Set<String>  // отметки вида "день_задача"
    var rewarded: Bool = false       // XP-награда выдана

    func isCompleted(day: Int, task: Int) -> Bool {
        completedMarks.contains("\(day)_\(task)")
    }

    mutating func toggle(day: Int, task: Int) {
        let mark = "\(day)_\(task)"
        if completedMarks.contains(mark) {
            completedMarks.remove(mark)
        } else {
            completedMarks.insert(mark)
        }
    }
}

@MainActor
enum ChallengeStore {

    private static func key(for id: String) -> String { "dq_challenge_run_\(id)" }

    static func run(for id: String) -> ChallengeRun? {
        guard let data = UserDefaults.standard.data(forKey: key(for: id)),
              let run = try? JSONDecoder().decode(ChallengeRun.self, from: data)
        else { return nil }
        return run
    }

    static func save(_ run: ChallengeRun) {
        if let data = try? JSONEncoder().encode(run) {
            UserDefaults.standard.set(data, forKey: key(for: run.challengeID))
        }
    }

    /// Стереть прогресс всех челленджей — для «Выйти из профиля».
    static func resetAll() {
        for challenge in ChallengeCatalog.all {
            UserDefaults.standard.removeObject(forKey: key(for: challenge.id))
        }
    }

    /// Старт: челлендж привязывается к ТЕКУЩЕЙ неделе (Пн–Вс).
    static func start(_ challenge: Challenge) -> ChallengeRun {
        var calendar = Calendar.current
        calendar.firstWeekday = 2   // неделя с понедельника
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())

        let run = ChallengeRun(challengeID: challenge.id,
                               weekStart: weekStart,
                               completedMarks: [])
        save(run)
        return run
    }

    // MARK: - Помощники по времени

    /// Индекс сегодняшнего дня внутри недели челленджа: 0 = Пн ... 6 = Вс.
    /// Больше 6 — неделя закончилась, меньше 0 не бывает.
    static func todayIndex(for run: ChallengeRun) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: run.weekStart),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        return max(0, days)
    }

    static func isExpired(_ run: ChallengeRun) -> Bool {
        todayIndex(for: run) > 6
    }

    static func isFullyCompleted(_ challenge: Challenge, run: ChallengeRun) -> Bool {
        for (dayIndex, tasks) in challenge.days.enumerated() {
            for taskIndex in tasks.indices where !run.isCompleted(day: dayIndex, task: taskIndex) {
                return false
            }
        }
        return true
    }

    /// Короткий статус для списка челленджей
    static func statusLine(for challenge: Challenge) -> String {
        guard let run = run(for: challenge.id) else { return "Не начат" }
        if isFullyCompleted(challenge, run: run) { return "🏅 Пройден" }
        if isExpired(run) { return "Неделя прошла — можно начать заново" }
        let day = min(todayIndex(for: run), 6) + 1
        return "Идёт · день \(day) из 7"
    }
}
