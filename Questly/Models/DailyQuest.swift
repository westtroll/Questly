//
//  DailyQuest.swift
//  Questly
//
//  «Квест дня»: маленькое задание на каждый день для роста над собой.
//  Пул заданий с ротацией по дате (как статья дня). Выполнение
//  отмечается на конкретный день и даёт небольшой XP-бонус.
//

import Foundation

struct DailyQuest {
    let emoji: String
    let title: String
    let subtitle: String

    /// Бонус за выполнение квеста дня
    static let rewardXP = 25
}

@MainActor
enum DailyQuestCatalog {

    /// Квест на сегодня — детерминированная ротация по номеру дня.
    static var today: DailyQuest {
        quest(for: Date())
    }

    /// Квест на произвольную дату (для уведомления о завтрашнем).
    /// Порядок внутри каждого «круга» по каталогу перетасовывается
    /// сидом от номера круга: повторы редкие (раз в ~3 месяца при
    /// 90 квестах) и каждый раз в новой последовательности. Расчёт
    /// детерминирован — уведомление о завтрашнем квесте не ошибётся.
    static func quest(for date: Date) -> DailyQuest {
        let day = Int(date.timeIntervalSinceReferenceDate / 86_400)
        let cycle = day / all.count
        let index = day % all.count

        var generator = SeededGenerator(seed: UInt64(cycle))
        let order = Array(all.indices).shuffled(using: &generator)
        return all[order[index]]
    }

    // MARK: - Отметка выполнения

    private static let doneDayKey = "dq_quest_done_day"   // startOfDay выполненного
    private static let rewardedDayKey = "dq_quest_rewarded_day"
    private static let doneDaysKey = "dq_quest_done_days"  // история дней — для стрика

    /// Серия дней подряд с выполненным квестом. Как у привычек:
    /// если сегодня ещё не выполнен — серия «жива» со вчера.
    static var streak: Int {
        let calendar = Calendar.current
        let days = Set((UserDefaults.standard.array(forKey: doneDaysKey) as? [Date] ?? [])
            .map { calendar.startOfDay(for: $0) })

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    private static func recordDone(_ done: Bool, on day: Date) {
        var days = (UserDefaults.standard.array(forKey: doneDaysKey) as? [Date]) ?? []
        let target = Calendar.current.startOfDay(for: day)
        days.removeAll { Calendar.current.isDate($0, inSameDayAs: target) }
        if done { days.append(target) }
        // Историю старше года не храним.
        if let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: Date()) {
            days.removeAll { $0 < cutoff }
        }
        UserDefaults.standard.set(days, forKey: doneDaysKey)
    }

    /// Выполнен ли квест сегодня
    static var isDoneToday: Bool {
        guard let done = UserDefaults.standard.object(forKey: doneDayKey) as? Date else { return false }
        return Calendar.current.isDateInToday(done)
    }

    /// Отметить/снять выполнение сегодня. Возвращает дельту XP,
    /// которую нужно применить: +rewardXP при выполнении,
    /// −rewardXP при снятии отметки, 0 если награда не менялась.
    /// Симметрия исключает фарм: отметил-снял-отметил в сумме даёт +25.
    @discardableResult
    static func toggleToday() -> Int {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let rewardedToday = (defaults.object(forKey: rewardedDayKey) as? Date)
            .map { calendar.isDateInToday($0) } ?? false

        if isDoneToday {
            // Снимаем отметку — забираем и награду, если она была выдана.
            defaults.removeObject(forKey: doneDayKey)
            recordDone(false, on: Date())
            if rewardedToday {
                defaults.removeObject(forKey: rewardedDayKey)
                return -DailyQuest.rewardXP
            }
            return 0
        }

        // Ставим отметку — начисляем награду, если сегодня ещё не выдавали.
        defaults.set(calendar.startOfDay(for: Date()), forKey: doneDayKey)
        recordDone(true, on: Date())
        if !rewardedToday {
            defaults.set(calendar.startOfDay(for: Date()), forKey: rewardedDayKey)
            return DailyQuest.rewardXP
        }
        return 0
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: doneDayKey)
        UserDefaults.standard.removeObject(forKey: rewardedDayKey)
        UserDefaults.standard.removeObject(forKey: doneDaysKey)
    }

    // MARK: - Пул заданий

    static let all: [DailyQuest] = [
        DailyQuest(emoji: "💧", title: "Выпей стакан воды прямо сейчас",
                   subtitle: "Мозг на 75% из воды — начни день с заботы о нём"),
        DailyQuest(emoji: "📵", title: "Проведи 30 минут без телефона",
                   subtitle: "Дай вниманию отдохнуть от бесконечной ленты"),
        DailyQuest(emoji: "🚶", title: "Пройди 15 минут пешком",
                   subtitle: "Движение разгоняет мысли и поднимает настроение"),
        DailyQuest(emoji: "🙏", title: "Запиши, за что ты благодарен",
                   subtitle: "Три пункта — и мир станет чуть светлее"),
        DailyQuest(emoji: "🧹", title: "Наведи порядок на одном столе",
                   subtitle: "Порядок снаружи — порядок в голове"),
        DailyQuest(emoji: "📚", title: "Прочитай 10 страниц книги",
                   subtitle: "Маленький шаг, который за год превратится в десятки книг"),
        DailyQuest(emoji: "🤙", title: "Напиши человеку, по которому скучаешь",
                   subtitle: "Одно сообщение может сделать чей-то день"),
        DailyQuest(emoji: "🧘", title: "Посиди 3 минуты в тишине",
                   subtitle: "Просто закрой глаза и подыши — без телефона и мыслей о делах"),
        DailyQuest(emoji: "🎯", title: "Сделай самое неприятное дело первым",
                   subtitle: "«Съешь лягушку» — и остаток дня будет легче"),
        DailyQuest(emoji: "💪", title: "Сделай 20 приседаний",
                   subtitle: "Быстрый заряд бодрости без спортзала"),
        DailyQuest(emoji: "🌙", title: "Ляг спать на 30 минут раньше",
                   subtitle: "Завтрашний ты скажет спасибо"),
        DailyQuest(emoji: "✍️", title: "Выпиши одну цель на неделю",
                   subtitle: "Ясная цель — половина её достижения"),
        DailyQuest(emoji: "🍎", title: "Замени один перекус на фрукт",
                   subtitle: "Маленький выбор в пользу себя"),
        DailyQuest(emoji: "😊", title: "Сделай кому-то искренний комплимент",
                   subtitle: "Доброта возвращается — проверено"),

        // Тело и здоровье
        DailyQuest(emoji: "🚿", title: "Закончи душ 30 секундами прохладной воды",
                   subtitle: "Бодрость, которую не даст ни один кофе"),
        DailyQuest(emoji: "🏋️", title: "Сделай 10 отжиманий",
                   subtitle: "Не для рекорда — для привычки двигаться"),
        DailyQuest(emoji: "⏱", title: "Постой в планке 1 минуту",
                   subtitle: "60 секунд, которые держат всё тело"),
        DailyQuest(emoji: "🤸", title: "Потянись 5 минут",
                   subtitle: "Спина и шея скажут спасибо за заботу"),
        DailyQuest(emoji: "🪜", title: "Поднимись по лестнице вместо лифта",
                   subtitle: "Бесплатное кардио прямо в твоём доме"),
        DailyQuest(emoji: "🥗", title: "Съешь сегодня порцию овощей",
                   subtitle: "Тело строится из того, что ты в него кладёшь"),
        DailyQuest(emoji: "🧃", title: "День без сахара в напитках",
                   subtitle: "Вода, чай, кофе — без сиропов и газировки"),
        DailyQuest(emoji: "🚰", title: "Выпей 6 стаканов воды за день",
                   subtitle: "Ставь галочку вечером, если справился"),
        DailyQuest(emoji: "🌅", title: "Сделай 5-минутную зарядку утром",
                   subtitle: "Разбуди тело до того, как сядешь за экран"),
        DailyQuest(emoji: "👀", title: "Каждые 2 часа смотри вдаль по минуте",
                   subtitle: "Глазам нужен горизонт, а не только экран"),
        DailyQuest(emoji: "🦶", title: "Выйди на одну остановку раньше и пройдись",
                   subtitle: "Крошечный крюк — большая польза"),
        DailyQuest(emoji: "🛌", title: "Ляг сегодня до 23:00",
                   subtitle: "Сон — главный источник энергии, не кофе"),
        DailyQuest(emoji: "🤾", title: "Сделай 20 прыжков на месте",
                   subtitle: "Пульс поднимется — настроение тоже"),
        DailyQuest(emoji: "🍽", title: "Съешь один приём пищи без телефона",
                   subtitle: "Еда вкуснее, когда её замечаешь"),
        DailyQuest(emoji: "🌤", title: "Подыши свежим воздухом 5 минут",
                   subtitle: "Балкон или улица — без телефона в руках"),

        // Ум и развитие
        DailyQuest(emoji: "🗣", title: "Выучи 5 слов на иностранном языке",
                   subtitle: "За год такими шагами — почти две тысячи слов"),
        DailyQuest(emoji: "🎧", title: "Послушай подкаст 15 минут",
                   subtitle: "Преврати дорогу или уборку в учёбу"),
        DailyQuest(emoji: "💡", title: "Запиши 3 идеи — любые",
                   subtitle: "Идеи приходят к тем, кто их записывает"),
        DailyQuest(emoji: "🧩", title: "Реши одну головоломку или судоку",
                   subtitle: "Разминка для мозга вместо ленты"),
        DailyQuest(emoji: "🎬", title: "Посмотри 20 минут документалки",
                   subtitle: "Вместо сериала — что-то, что расширяет"),
        DailyQuest(emoji: "📝", title: "Выпиши мысли на одну страницу",
                   subtitle: "Фрирайтинг: пиши всё подряд, не редактируя"),
        DailyQuest(emoji: "🔁", title: "Повтори то, что учил на этой неделе",
                   subtitle: "Повторение превращает знакомое в своё"),
        DailyQuest(emoji: "🎨", title: "Порисуй 5 минут — что угодно",
                   subtitle: "Не для результата, а для удовольствия"),
        DailyQuest(emoji: "🌠", title: "Напиши список из 10 желаний",
                   subtitle: "Без цензуры — просто дай себе помечтать"),
        DailyQuest(emoji: "📰", title: "Прочитай одну статью по своему делу",
                   subtitle: "Полчаса в неделю — и ты впереди большинства"),

        // Цифровая гигиена
        DailyQuest(emoji: "📧", title: "Разбери 10 писем в почте",
                   subtitle: "Ответь, заархивируй или удали — но реши"),
        DailyQuest(emoji: "🔕", title: "Отключи уведомления у 3 приложений",
                   subtitle: "Каждое лишнее уведомление ворует фокус"),
        DailyQuest(emoji: "🗑", title: "Удали 5 приложений, которыми не пользуешься",
                   subtitle: "Чистый экран — чистая голова"),
        DailyQuest(emoji: "🖼", title: "Удали 30 лишних фото из галереи",
                   subtitle: "Скриншоты и дубли — под нож"),
        DailyQuest(emoji: "🌃", title: "Вечер без соцсетей после 21:00",
                   subtitle: "Дай мозгу остыть перед сном"),
        DailyQuest(emoji: "🛏", title: "Оставь телефон на ночь вне спальни",
                   subtitle: "Лучший будильник — обычный будильник"),
        DailyQuest(emoji: "📴", title: "Отпишись от 3 ненужных каналов",
                   subtitle: "Информационная диета начинается с отписки"),
        DailyQuest(emoji: "💻", title: "Наведи порядок на рабочем столе компьютера",
                   subtitle: "Файлы по папкам, лишнее — в корзину"),

        // Порядок и дом
        DailyQuest(emoji: "🗄", title: "Разбери одну полку или ящик",
                   subtitle: "Не всю квартиру — только одну полку"),
        DailyQuest(emoji: "📦", title: "Выброси или отдай 5 ненужных вещей",
                   subtitle: "Место дома — место в голове"),
        DailyQuest(emoji: "🍴", title: "Помой посуду сразу после еды",
                   subtitle: "Две минуты сейчас против горы вечером"),
        DailyQuest(emoji: "🛏️", title: "Заправь кровать идеально",
                   subtitle: "Первая победа дня — самая простая"),
        DailyQuest(emoji: "⌨️", title: "Протри экран и клавиатуру",
                   subtitle: "Ты удивишься, сколько там всего"),
        DailyQuest(emoji: "🎒", title: "Разбери сумку или рюкзак",
                   subtitle: "Чеки, фантики и загадочные предметы — прощайте"),
        DailyQuest(emoji: "🧺", title: "Постирай то, что давно откладывал",
                   subtitle: "Та самая куча ждёт своего часа"),
        DailyQuest(emoji: "🪴", title: "Позаботься о растении",
                   subtitle: "Полей, протри листья — оно живое"),

        // Люди и доброта
        DailyQuest(emoji: "📞", title: "Позвони родителям или родным",
                   subtitle: "Не по делу — просто услышать голос"),
        DailyQuest(emoji: "🤝", title: "Поблагодари того, кто тебе помог",
                   subtitle: "Благодарность вслух — редкость и ценность"),
        DailyQuest(emoji: "👋", title: "Узнай, как дела у старого друга",
                   subtitle: "Дружба живёт, пока её поддерживают"),
        DailyQuest(emoji: "🎁", title: "Сделай маленький подарок без повода",
                   subtitle: "Шоколадка коллеге меняет день"),
        DailyQuest(emoji: "⭐️", title: "Оставь хороший отзыв заведению или мастеру",
                   subtitle: "Две минуты — а человеку приятно на неделю"),
        DailyQuest(emoji: "🫶", title: "Помоги кому-то, не дожидаясь просьбы",
                   subtitle: "Заметить, что нужна помощь — уже талант"),
        DailyQuest(emoji: "🙌", title: "Скажи «спасибо» трём людям за день",
                   subtitle: "Искренне и глядя в глаза"),

        // Деньги
        DailyQuest(emoji: "🧾", title: "Запиши все траты за сегодня",
                   subtitle: "Деньги любят счёт — буквально"),
        DailyQuest(emoji: "🐷", title: "Отложи небольшую сумму в копилку",
                   subtitle: "Не размер важен, а привычка"),
        DailyQuest(emoji: "💳", title: "Проверь подписки и отмени одну ненужную",
                   subtitle: "Они тихо едят твой бюджет каждый месяц"),
        DailyQuest(emoji: "🛒", title: "Составь список перед походом в магазин",
                   subtitle: "И купи только то, что в списке"),

        // Забота о себе
        DailyQuest(emoji: "🙅", title: "Скажи «нет» одному лишнему обязательству",
                   subtitle: "Каждое «да» чему-то — это «нет» себе"),
        DailyQuest(emoji: "🏅", title: "Запиши одно достижение сегодняшнего дня",
                   subtitle: "Даже маленькое. Особенно маленькое"),
        DailyQuest(emoji: "🗓", title: "Спланируй завтрашний день с вечера",
                   subtitle: "Утро без раздумий — лучшее утро"),
        DailyQuest(emoji: "⏳", title: "Правило 5 минут: начни то, что откладывал",
                   subtitle: "Договорись с собой всего на 5 минут"),
        DailyQuest(emoji: "🦁", title: "Сделай одну вещь из зоны дискомфорта",
                   subtitle: "Рост живёт ровно там"),
        DailyQuest(emoji: "💿", title: "Послушай любимый альбом целиком",
                   subtitle: "Не фоном — по-настоящему"),
        DailyQuest(emoji: "👨‍🍳", title: "Приготовь что-то, что не готовил раньше",
                   subtitle: "Новый рецепт — маленькое приключение"),
        DailyQuest(emoji: "🗺", title: "Пройди привычный маршрут по-новому",
                   subtitle: "Другая дорога — другие мысли"),
        DailyQuest(emoji: "🤐", title: "День без жалоб до самого вечера",
                   subtitle: "Заметь, как часто хочется — уже открытие"),
        DailyQuest(emoji: "🧠", title: "10 минут перерыва без единого экрана",
                   subtitle: "Смотреть в окно — это тоже дело"),
        DailyQuest(emoji: "📸", title: "Сфотографируй 3 красивых момента дня",
                   subtitle: "Красота вокруг — вопрос внимания"),
        DailyQuest(emoji: "📓", title: "Напиши пару абзацев о прожитом дне",
                   subtitle: "Дневник — разговор с собой честным"),
        DailyQuest(emoji: "🎶", title: "Потанцуй под один трек",
                   subtitle: "Никто не видит — отрывайся"),
        DailyQuest(emoji: "🫖", title: "Выпей чай или кофе не спеша, без дел",
                   subtitle: "15 минут только для вкуса и тишины"),
        DailyQuest(emoji: "🌳", title: "Проведи 20 минут на природе",
                   subtitle: "Парк, сквер, двор — зелёное лечит"),
        DailyQuest(emoji: "✂️", title: "Упрости одно повторяющееся дело",
                   subtitle: "Шаблон, ярлык, автоплатёж — автоматизируй"),
        DailyQuest(emoji: "🕯", title: "Устрой вечер при тёплом свете",
                   subtitle: "Приглуши лампы за час до сна"),
        DailyQuest(emoji: "🤗", title: "Обними того, кто рядом",
                   subtitle: "20 секунд объятий снижают стресс — наука"),
        DailyQuest(emoji: "🧊", title: "Умойся холодной водой с утра",
                   subtitle: "Секундный дискомфорт — час бодрости"),
        DailyQuest(emoji: "🔖", title: "Вернись к сохранённому «на потом»",
                   subtitle: "Прочитай одну из отложенных статей"),
        DailyQuest(emoji: "🥇", title: "Сделай сегодня на одну задачу больше плана",
                   subtitle: "Перевыполнить хоть на шаг — особое чувство"),
        DailyQuest(emoji: "🌍", title: "Узнай один факт о месте, где живёшь",
                   subtitle: "Родной город умеет удивлять"),
        DailyQuest(emoji: "🖊", title: "Напиши от руки хотя бы полстраницы",
                   subtitle: "Рука пишет — голова думает иначе")
    ]
}


// MARK: - Детерминированный генератор случайности
//
// SplitMix64: одинаковый сид → одинаковая последовательность на любом
// устройстве и запуске. Нужен для перетасовки квестов по кругам.

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

