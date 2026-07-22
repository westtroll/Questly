//
//  Achievements.swift
//  Questly
//
//  Ачивки: каталог условий, хранилище открытых и экран-сетка.
//  Главное правило: открытая ачивка НЕ закрывается, даже если
//  показатель упал (стрик оборвался, уровень откатился штрафом) —
//  поэтому открытые ID хранятся, а проверка их только пополняет.
//

import UIKit

// MARK: - Каталог

struct Achievement {
    let id: String
    let emoji: String
    let title: String
    /// Пояснение: за что выдаётся ачивка (для алерта по тапу)
    let detail: String
    /// Условие открытия по статистике профиля
    let isUnlocked: (ProfileStats) -> Bool
    /// Прогресс к цели: (текущее, цель). nil — прогресс не измеряется
    /// числом (например, «пройти челлендж» — да/нет).
    let progress: ((ProfileStats) -> (current: Int, goal: Int))?
}

enum AchievementCatalog {

    static let all: [Achievement] = [
        // Стрики — по лучшему стрику: заработанное не отнимается.
        Achievement(id: "streak_3", emoji: "🔥", title: "3 дня подряд",
                    detail: "Набирай 60+ баллов три дня подряд.",
                    isUnlocked: { $0.bestStreak >= 3 },
                    progress: { ($0.bestStreak, 3) }),
        Achievement(id: "streak_7", emoji: "⚡️", title: "7 дней подряд",
                    detail: "Держи стрик целую неделю без пропусков.",
                    isUnlocked: { $0.bestStreak >= 7 },
                    progress: { ($0.bestStreak, 7) }),
        Achievement(id: "streak_14", emoji: "🚀", title: "14 дней подряд",
                    detail: "Две недели подряд с результатом 60+ баллов.",
                    isUnlocked: { $0.bestStreak >= 14 },
                    progress: { ($0.bestStreak, 14) }),
        Achievement(id: "streak_30", emoji: "🏆", title: "30 дней подряд",
                    detail: "Целый месяц дисциплины без единого пропуска.",
                    isUnlocked: { $0.bestStreak >= 30 },
                    progress: { ($0.bestStreak, 30) }),
        Achievement(id: "streak_100", emoji: "👑", title: "100 дней подряд",
                    detail: "Сотня дней подряд. Уровень легенды.",
                    isUnlocked: { $0.bestStreak >= 100 },
                    progress: { ($0.bestStreak, 100) }),

        // Идеальные дни
        Achievement(id: "perfect_1", emoji: "⭐️", title: "Первый идеальный день",
                    detail: "Набери 100 баллов за один день.",
                    isUnlocked: { $0.perfectDays >= 1 },
                    progress: { ($0.perfectDays, 1) }),
        Achievement(id: "perfect_10", emoji: "🌟", title: "10 идеальных дней",
                    detail: "Набери 100 баллов в 10 разных дней за всё время.",
                    isUnlocked: { $0.perfectDays >= 10 },
                    progress: { ($0.perfectDays, 10) }),
        Achievement(id: "perfect_30", emoji: "💫", title: "30 идеальных дней",
                    detail: "Тридцать идеальных дней за всё время.",
                    isUnlocked: { $0.perfectDays >= 30 },
                    progress: { ($0.perfectDays, 30) }),

        // Задачи
        Achievement(id: "tasks_10", emoji: "✅", title: "10 задач выполнено",
                    detail: "Выполни 10 задач за всё время.",
                    isUnlocked: { $0.totalTasksCompleted >= 10 },
                    progress: { ($0.totalTasksCompleted, 10) }),
        Achievement(id: "tasks_100", emoji: "💪", title: "100 задач выполнено",
                    detail: "Выполни 100 задач за всё время.",
                    isUnlocked: { $0.totalTasksCompleted >= 100 },
                    progress: { ($0.totalTasksCompleted, 100) }),
        Achievement(id: "tasks_500", emoji: "🦾", title: "500 задач выполнено",
                    detail: "Выполни 500 задач. Настоящая машина продуктивности.",
                    isUnlocked: { $0.totalTasksCompleted >= 500 },
                    progress: { ($0.totalTasksCompleted, 500) }),

        // Статьи — счётчик берём напрямую из ArticleReadStore, а не из
        // ProfileStats: правило «открытое не закрывается» обеспечивает
        // хранилище открытых ID, так что снятие отметок ачивку не отнимет.
        Achievement(id: "articles_1", emoji: "📖", title: "Первая статья",
                    detail: "Прочитай любую статью и отметь её прочитанной.",
                    isUnlocked: { _ in ArticleReadStore.readCount >= 1 },
                    progress: { _ in (ArticleReadStore.readCount, 1) }),
        Achievement(id: "articles_10", emoji: "📚", title: "Начитанный",
                    detail: "Прочитай 10 статей о саморазвитии.",
                    isUnlocked: { _ in ArticleReadStore.readCount >= 10 },
                    progress: { _ in (ArticleReadStore.readCount, 10) }),
        Achievement(id: "articles_all", emoji: "🎓", title: "Вся библиотека",
                    detail: "Прочитай все статьи в приложении.",
                    isUnlocked: { _ in ArticleReadStore.readCount >= ArticleCatalog.all.count },
                    progress: { _ in (ArticleReadStore.readCount, ArticleCatalog.all.count) }),

        // Уровень
        Achievement(id: "level_5", emoji: "🎓", title: "Уровень 5 — Гуру",
                    detail: "Достигни 5-го уровня, накопив 5000 очков.",
                    isUnlocked: { LevelSystem.userLevel(totalPoints: $0.totalPointsEarned).level >= 5 },
                    progress: { (min($0.totalPointsEarned, 5000), 5000) }),

        // Фокус (помодоро) — читают PomodoroStats, а не ProfileStats
        Achievement(id: "focus_first", emoji: "🍅", title: "Первый фокус",
                    detail: "Доведи до конца одну фокус-сессию таймера.",
                    isUnlocked: { _ in PomodoroStats.totalSessions >= 1 },
                    progress: { _ in (min(PomodoroStats.totalSessions, 1), 1) }),
        Achievement(id: "focus_50", emoji: "🎯", title: "50 сессий фокуса",
                    detail: "Доведи до конца 50 фокус-сессий за всё время.",
                    isUnlocked: { _ in PomodoroStats.totalSessions >= 50 },
                    progress: { _ in (min(PomodoroStats.totalSessions, 50), 50) }),
        Achievement(id: "focus_25h", emoji: "🧠", title: "25 часов фокуса",
                    detail: "Накопи 25 часов глубокой работы с таймером.",
                    isUnlocked: { _ in PomodoroStats.totalMinutes >= 1500 },
                    progress: { _ in (min(PomodoroStats.totalMinutes / 60, 25), 25) }),

        // Квесты дня — серия подряд
        Achievement(id: "quest_streak_7", emoji: "🎯", title: "Неделя квестов",
                    detail: "Выполняй квест дня 7 дней подряд.",
                    isUnlocked: { _ in DailyQuestCatalog.streak >= 7 },
                    progress: { _ in (min(DailyQuestCatalog.streak, 7), 7) }),
        Achievement(id: "quest_streak_30", emoji: "🌟", title: "Месяц квестов",
                    detail: "Выполняй квест дня 30 дней подряд — без единого пропуска.",
                    isUnlocked: { _ in DailyQuestCatalog.streak >= 30 },
                    progress: { _ in (min(DailyQuestCatalog.streak, 30), 30) }),

        // Челленджи (прогресс числом не измеряется — да/нет)
        Achievement(id: "challenge_first", emoji: "☀️", title: "Челлендж пройден",
                    detail: "Пройди любой недельный челлендж до конца.",
                    isUnlocked: { _ in
            ChallengeCatalog.all.contains { challenge in
                guard let run = ChallengeStore.run(for: challenge.id) else { return false }
                return ChallengeStore.isFullyCompleted(challenge, run: run)
            }
        }, progress: nil)
    ]
}

// MARK: - Хранилище открытых

@MainActor
enum AchievementStore {

    private static let key = "dq_achievements_unlocked"

    /// Проверяет условия, пополняет сохранённый набор и возвращает
    /// итоговое множество открытых ID. Убрать ID отсюда нельзя —
    /// заработанное остаётся навсегда.
    static func unlockedIDs(stats: ProfileStats) -> Set<String> {
        var unlocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])

        for achievement in AchievementCatalog.all where achievement.isUnlocked(stats) {
            unlocked.insert(achievement.id)
        }

        UserDefaults.standard.set(Array(unlocked), forKey: key)
        return unlocked
    }

    /// Пересчитывает открытия и возвращает ТОЛЬКО новые с прошлого
    /// раза — для поздравительного алерта в момент открытия.
    static func checkForNewUnlocks(stats: ProfileStats) -> [Achievement] {
        let before = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let after = unlockedIDs(stats: stats)   // заодно сохраняет
        let newIDs = after.subtracting(before)
        return AchievementCatalog.all.filter { newIDs.contains($0.id) }
    }

    /// Стереть открытые ачивки — для «Выйти из профиля».
    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Экран ачивок

final class AchievementsViewController: UIViewController {

    private let achievements = AchievementCatalog.all
    private var unlockedIDs: Set<String> = []
    private var stats: ProfileStats?

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        // Мгновенная подсветка — иначе «жмяк» бейджа не виден при тапе.
        cv.delaysContentTouches = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(AchievementCell.self, forCellWithReuseIdentifier: AchievementCell.reuseId)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ачивки"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(countLabel)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            collectionView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Пересчитываем открытые под актуальную статистику.
        let currentStats = DataStore.shared.profileStats()
        stats = currentStats
        unlockedIDs = AchievementStore.unlockedIDs(stats: currentStats)
        countLabel.text = "Открыто \(unlockedIDs.count) из \(achievements.count)"
        collectionView.reloadData()
    }
}

extension AchievementsViewController: UICollectionViewDataSource,
                                      UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        achievements.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AchievementCell.reuseId, for: indexPath
        ) as! AchievementCell
        let achievement = achievements[indexPath.item]
        cell.configure(with: achievement,
                       isUnlocked: unlockedIDs.contains(achievement.id))
        return cell
    }

    // 3 колонки: ширина считается от реальной ширины коллекции.
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 20) / 3   // 2 промежутка по 10
        return CGSize(width: width, height: 112)
    }

    // Тап по бейджу — подробности: за что даётся, статус и прогресс.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let achievement = achievements[indexPath.item]
        let isUnlocked = unlockedIDs.contains(achievement.id)

        var message = achievement.detail + "\n\n"
        let icon: String
        let tint: UIColor
        if isUnlocked {
            message += "Открыто"
            icon = "checkmark.seal.fill"
            tint = .systemYellow
        } else if let progress = achievement.progress, let stats {
            let p = progress(stats)
            let current = min(p.current, p.goal)
            message += "Прогресс: \(current) из \(p.goal)"
            icon = "lock.fill"
            tint = .systemGray
        } else {
            message += "Ещё не открыто"
            icon = "lock.fill"
            tint = .systemGray
        }

        DQAlert.present(
            from: self,
            icon: icon,
            iconTint: tint,
            title: "\(achievement.emoji) \(achievement.title)",
            message: message,
            actions: [.init("Понятно", style: .primary)]
        )
    }
}

// MARK: - Ячейка-бейдж

final class AchievementCell: UICollectionViewCell {

    static let reuseId = "AchievementCell"

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26)
        label.textAlignment = .center
        return label
    }()

    // Кружок-подложка под эмодзи — превращает значок в «трофей».
    private let emojiCircle: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 24
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(11, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    // Замочек в углу для закрытых
    private let lockIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "lock.fill"))
        iv.tintColor = .tertiaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Внутренний tile — вся отрисовка на нём, contentView не трогаем
    // (его геометрией владеет layout коллекции; трансформация на нём
    // «уезжала» бы, урок плиток категорий).
    private let tile: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        emojiCircle.addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [emojiCircle, titleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(tile)
        tile.addSubview(stack)
        tile.addSubview(lockIcon)
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor),
            tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -6),

            emojiCircle.widthAnchor.constraint(equalToConstant: 48),
            emojiCircle.heightAnchor.constraint(equalToConstant: 48),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiCircle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiCircle.centerYAnchor),

            lockIcon.topAnchor.constraint(equalTo: tile.topAnchor, constant: 8),
            lockIcon.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -8),
            lockIcon.widthAnchor.constraint(equalToConstant: 12),
            lockIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // «Жмяк» бейджа при нажатии.
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1,
                               delay: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                }
            } else {
                UIView.animate(withDuration: 0.35,
                               delay: 0,
                               usingSpringWithDamping: 0.5,
                               initialSpringVelocity: 5,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.tile.transform = .identity
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tile.transform = .identity
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with achievement: Achievement, isUnlocked: Bool) {
        emojiLabel.text = achievement.emoji
        titleLabel.text = achievement.title

        if isUnlocked {
            // Открытая — карточка нейтральная, кружок золотой, эмодзи яркий.
            tile.backgroundColor = DQColor.card
            emojiCircle.backgroundColor = UIColor(hex: 0xFAEEDA)
            emojiLabel.alpha = 1
            titleLabel.textColor = .label
            lockIcon.isHidden = true
        } else {
            // Закрытая — всё приглушено, кружок серый.
            tile.backgroundColor = DQColor.card
            emojiCircle.backgroundColor = UIColor.systemGray5
            emojiLabel.alpha = 0.35
            titleLabel.textColor = .tertiaryLabel
            lockIcon.isHidden = false
        }
    }
}

