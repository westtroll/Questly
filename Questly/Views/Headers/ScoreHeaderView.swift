//
//  ScoreHeaderView.swift
//  Questly
//
//  Карточка прогресса дня. Теперь это UICollectionReusableView —
//  заголовок секции UICollectionView (аналог tableHeaderView,
//  но collection view умеет считать его высоту сам через .estimated).
//

import UIKit

final class ScoreHeaderView: UICollectionReusableView {

    static let reuseId = "ScoreHeaderView"

    // MARK: - UI элементы

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        // Не влезает — ужимаемся шрифтом, а не троеточием
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Бейдж стрика. Раньше жил в navigation bar, но iOS 26 оборачивает
    // элементы навбара в свою стеклянную капсулу — получалась капсула
    // в капсуле, а текст обрезался. В шапке мы полностью управляем видом.
    private let streakBadge: PaddedLabel = {
        let label = PaddedLabel()
        label.font = DQFont.rounded(13, weight: .medium)
        label.textColor = .systemOrange
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.16)
        label.layer.cornerRadius = 13
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true   // тап — объяснение стрика
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Тап по пилюле стрика — контроллер покажет объяснение правил.
    var onStreakTap: (() -> Void)?

    /// Тап по плашке статуса дня — мотивационный алерт.
    var onStatusTap: (() -> Void)?

    /// Тап по пилюле джокеров — объяснение механики.
    var onJokerTap: (() -> Void)?

    // Пилюля баланса джокеров: «🎟 2». Видна всегда, даже при нуле —
    // приглашает тапнуть и узнать, как их заработать.
    private let jokerBadge: PaddedLabel = {
        let label = PaddedLabel()
        label.font = DQFont.rounded(13, weight: .medium)
        label.textColor = DQColor.accentDark
        label.backgroundColor = DQColor.accentSoftAdaptive
        label.layer.cornerRadius = 13
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Пилюля уровня — рядом со стриком. Тап ведёт в профиль.
    private let levelBadge: PaddedLabel = {
        let label = PaddedLabel()
        label.font = DQFont.rounded(13, weight: .medium)
        label.textColor = DQColor.accentDark
        label.backgroundColor = DQColor.accentSoftAdaptive
        label.layer.cornerRadius = 13
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// TodayViewController подставляет сюда переход на вкладку профиля.
    var onLevelTap: (() -> Void)?

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Большая цифра «65 / 100» — собираем через NSAttributedString,
    // чтобы «/ 100» было меньше и бледнее.
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusPill: PaddedLabel = {
        let label = PaddedLabel()
        label.font = DQFont.rounded(13, weight: .medium)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        // Плашка «жмякается» при тапе — UILabel по умолчанию
        // не принимает касания, включаем явно.
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Прогресс-бар из двух UIView: дорожка + заполнение.
    // Гибче, чем UIProgressView: любая высота, скругления и цвет без хаков.
    private let progressTrack: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressFill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Ширину заполнения задаём constraint-ом с multiplier.
    // Multiplier нельзя поменять у живого constraint-а,
    // поэтому при обновлении пересоздаём его.
    private var fillWidth: NSLayoutConstraint?

    // Прокат числа счёта: от показанного к новому за ~0.5с.
    private var displayedPoints = -1          // -1 = ещё не показывали
    private var countAnimator: CADisplayLink?
    private var countFrom = 0
    private var countTo = 0
    private var countStart: CFTimeInterval = 0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Конфигурация

    func configure(score: DayScore, streak: Int, level: UserLevel,
                   plannedPoints: Int, hasCategories: Bool) {
        // Дата: «Суббота, 4 июля»
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        // «EE» — короткий день недели («вс»): полное «воскресенье» с
        // тремя бейджами справа не помещается даже на больших экранах.
        formatter.dateFormat = "EE, d MMMM"
        dateLabel.text = formatter.string(from: Date()).capitalizedFirst

        streakBadge.text = "🔥 \(streak.daysString)"
        jokerBadge.text = "🎟 \(DataStore.shared.jokers)"
        levelBadge.text = "🏆 \(level.level) ур."

        // «65 / 100» — число «прокатывается» к новому значению.
        animateScore(to: score.rawPoints)

        statusPill.text = "\(score.emoji) \(score.label)"
        statusPill.textColor = score.color
        statusPill.backgroundColor = score.color.withAlphaComponent(0.15)

        progressFill.backgroundColor = score.color
        progressFill.isHidden = score.value == 0

        // Подсказка: три ситуации.
        if !hasCategories {
            hintLabel.text = "Добавь первую категорию — с неё начнётся твой день"
        } else if plannedPoints < 100 {
            // Задач меньше чем на 100 очков — идеальный день недостижим,
            // честно говорим об этом.
            hintLabel.text = "Задач пока на \(plannedPoints) баллов — добавь ещё, чтобы день мог стать идеальным"
        } else {
            hintLabel.text = score.hint
        }

        // Обновляем ширину заполнения с анимацией.
        fillWidth?.isActive = false
        let fraction = max(0.001, CGFloat(score.value) / 100)
        fillWidth = progressFill.widthAnchor.constraint(
            equalTo: progressTrack.widthAnchor, multiplier: fraction
        )
        fillWidth?.isActive = true
        UIView.animate(withDuration: 0.6, delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5) {
            self.layoutIfNeeded()
        }
    }

    // MARK: - Прокат числа счёта

    private func animateScore(to points: Int) {
        // Первый показ и повторные конфигурации без изменения — мгновенно.
        guard displayedPoints != -1, points != displayedPoints else {
            displayedPoints = points
            setScoreText(points)
            return
        }
        countAnimator?.invalidate()
        countFrom = displayedPoints
        countTo = points
        countStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(countTick))
        link.add(to: .main, forMode: .common)
        countAnimator = link
    }

    @objc private func countTick() {
        let progress = min(1, (CACurrentMediaTime() - countStart) / 0.5)
        // ease-out: быстро стартует, мягко доезжает
        let eased = 1 - pow(1 - progress, 3)
        let value = countFrom + Int(Double(countTo - countFrom) * eased)
        setScoreText(value)
        if progress >= 1 {
            displayedPoints = countTo
            countAnimator?.invalidate()
            countAnimator = nil
        }
    }

    private func setScoreText(_ points: Int) {
        let text = NSMutableAttributedString(
            string: "\(points)",
            attributes: [
                .font: DQFont.rounded(34, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        )
        text.append(NSAttributedString(
            string: " / 100",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.secondaryLabel
            ]
        ))
        scoreLabel.attributedText = text
    }

    // MARK: - Квест дня

    /// Колбэк «выполнить/снять» квест дня.
    var onQuestToggle: (() -> Void)?

    private let questCard: UIView = {
        let v = UIView()
        v.backgroundColor = DQColor.accentSoftAdaptive
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let questEmoji: UILabel = {
        let l = UILabel(); l.font = .systemFont(ofSize: 26)
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let questBadge: UILabel = {
        let l = UILabel(); l.text = "КВЕСТ ДНЯ"
        l.font = DQFont.rounded(11, weight: .bold); l.textColor = DQColor.accentDark
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }()

    // Серия квестов подряд — огонёк рядом с заголовком карточки.
    private let questStreakLabel: UILabel = {
        let l = UILabel()
        l.font = DQFont.rounded(11, weight: .bold)
        l.textColor = .systemOrange
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }()
    // «истекает через 5:23:41» — обратный отсчёт до полуночи.
    private let questTimer: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let questTitle: UILabel = {
        let l = UILabel(); l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let questSubtitle: UILabel = {
        let l = UILabel(); l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let questCheck: UIButton = {
        let b = UIButton(type: .system)
        b.setPreferredSymbolConfiguration(.init(pointSize: 30), forImageIn: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Setup

    private func setupViews() {
        addSubview(dateLabel)
        addSubview(levelBadge)
        addSubview(streakBadge)
        addSubview(jokerBadge)
        addSubview(card)

        let tap = UITapGestureRecognizer(target: self, action: #selector(levelTapped))
        levelBadge.addGestureRecognizer(tap)

        let streakTap = UITapGestureRecognizer(target: self, action: #selector(streakTapped))
        streakBadge.addGestureRecognizer(streakTap)

        let statusTap = UITapGestureRecognizer(target: self, action: #selector(statusTapped))
        statusPill.addGestureRecognizer(statusTap)

        // Карточка квеста тоже жмякается (галочка-кнопка не мешает:
        // она перехватывает свои касания раньше жеста).
        questCard.dqMakeSquishy()

        let jokerTap = UITapGestureRecognizer(target: self, action: #selector(jokerTapped))
        jokerBadge.addGestureRecognizer(jokerTap)

        // «Жмяк» всей карточки дня по тапу.
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        card.addGestureRecognizer(cardTap)
        card.addSubview(scoreLabel)
        card.addSubview(statusPill)
        card.addSubview(progressTrack)
        progressTrack.addSubview(progressFill)
        card.addSubview(hintLabel)

        // Карточка квеста дня — под основной картой.
        addSubview(questCard)
        questCard.addSubview(questEmoji)
        questCard.addSubview(questBadge)
        questCard.addSubview(questStreakLabel)
        questCard.addSubview(questTimer)
        questCard.addSubview(questTitle)
        questCard.addSubview(questSubtitle)
        questCard.addSubview(questCheck)
        questCheck.addTarget(self, action: #selector(questTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Верхний ряд: дата слева, уровень и стрик справа.
            streakBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            streakBadge.trailingAnchor.constraint(equalTo: trailingAnchor),

            levelBadge.centerYAnchor.constraint(equalTo: streakBadge.centerYAnchor),
            levelBadge.trailingAnchor.constraint(equalTo: streakBadge.leadingAnchor, constant: -8),

            jokerBadge.centerYAnchor.constraint(equalTo: streakBadge.centerYAnchor),
            jokerBadge.trailingAnchor.constraint(equalTo: levelBadge.leadingAnchor, constant: -8),

            dateLabel.centerYAnchor.constraint(equalTo: streakBadge.centerYAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: jokerBadge.leadingAnchor, constant: -8),

            card.topAnchor.constraint(equalTo: streakBadge.bottomAnchor, constant: 10),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),


            scoreLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            scoreLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            statusPill.centerYAnchor.constraint(equalTo: scoreLabel.centerYAnchor),
            statusPill.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statusPill.leadingAnchor.constraint(greaterThanOrEqualTo: scoreLabel.trailingAnchor, constant: 8),

            progressTrack.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 14),
            progressTrack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            progressTrack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            progressTrack.heightAnchor.constraint(equalToConstant: 10),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),

            hintLabel.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            hintLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
,

            // Квест дня под основной картой; его низ замыкает высоту заголовка.
            questCard.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 10),
            questCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            questCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            questCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),

            questEmoji.leadingAnchor.constraint(equalTo: questCard.leadingAnchor, constant: 16),
            questEmoji.centerYAnchor.constraint(equalTo: questCard.centerYAnchor),

            questBadge.topAnchor.constraint(equalTo: questCard.topAnchor, constant: 12),
            questBadge.leadingAnchor.constraint(equalTo: questEmoji.trailingAnchor, constant: 12),

            // Отсчёт справа от бейджа.
            questStreakLabel.centerYAnchor.constraint(equalTo: questBadge.centerYAnchor),
            questStreakLabel.leadingAnchor.constraint(equalTo: questBadge.trailingAnchor, constant: 6),

            questTimer.centerYAnchor.constraint(equalTo: questBadge.centerYAnchor),
            questTimer.leadingAnchor.constraint(equalTo: questStreakLabel.trailingAnchor, constant: 8),
            questTimer.trailingAnchor.constraint(lessThanOrEqualTo: questCheck.leadingAnchor, constant: -8),

            questTitle.topAnchor.constraint(equalTo: questBadge.bottomAnchor, constant: 3),
            questTitle.leadingAnchor.constraint(equalTo: questEmoji.trailingAnchor, constant: 12),
            questTitle.trailingAnchor.constraint(equalTo: questCheck.leadingAnchor, constant: -10),

            questSubtitle.topAnchor.constraint(equalTo: questTitle.bottomAnchor, constant: 2),
            questSubtitle.leadingAnchor.constraint(equalTo: questEmoji.trailingAnchor, constant: 12),
            questSubtitle.trailingAnchor.constraint(equalTo: questCheck.leadingAnchor, constant: -10),
            questSubtitle.bottomAnchor.constraint(equalTo: questCard.bottomAnchor, constant: -12),

            questCheck.trailingAnchor.constraint(equalTo: questCard.trailingAnchor, constant: -14),
            questCheck.centerYAnchor.constraint(equalTo: questCard.centerYAnchor),
            questCheck.widthAnchor.constraint(equalToConstant: 40),
            questCheck.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Пилюли держат размер, при нехватке места ужимается дата.
        streakBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        levelBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        jokerBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Нижняя граница хедера — по низу карточки квеста. Приоритет
        // .defaultHigh (не required): при само-измерении в collection view
        // это позволяет layout-у корректно вычислить высоту без конфликта
        // с временным сжатием, но карточку не схлопывает (у неё min-height).
        let bottomLink = questCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        bottomLink.priority = .defaultHigh
        bottomLink.isActive = true
    }

    @objc private func questTapped() {
        Haptics.light()
        onQuestToggle?()
    }

    /// Заполнить карточку квеста дня и его состояние.
    func configureQuest() {
        let questStreak = DailyQuestCatalog.streak
        questStreakLabel.text = questStreak > 1 ? "🔥 \(questStreak)" : ""
        let quest = DailyQuestCatalog.today
        let done = DailyQuestCatalog.isDoneToday
        questEmoji.text = quest.emoji
        questTitle.text = quest.title
        questSubtitle.text = done ? "Выполнено сегодня ✅ +\(DailyQuest.rewardXP) XP" : quest.subtitle
        questCheck.tintColor = DQColor.accentAdaptive
        questCheck.setImage(UIImage(systemName: done ? "checkmark.circle.fill" : "circle"), for: .normal)
        questCard.alpha = done ? 0.7 : 1.0
        // Таймер виден всегда: до выполнения — «истекает через»,
        // после — «до нового квеста» (ротация в полночь).
        questTimer.isHidden = false
        refreshQuestTimer()
    }

    /// Обновляет обратный отсчёт до полуночи. Дёргается раз в секунду
    /// из TodayViewController, пока карточка на экране.
    func refreshQuestTimer() {
        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let remaining = Int(midnight.timeIntervalSinceNow)
        let h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60
        let prefix = DailyQuestCatalog.isDoneToday ? "до нового квеста" : "истекает через"
        questTimer.text = String(format: "%@ %d:%02d:%02d", prefix, h, m, s)
    }

    @objc private func jokerTapped() {
        Haptics.light()
        jokerBadge.dqSquish(scale: 0.85)
        onJokerTap?()
    }

    @objc private func statusTapped() {
        Haptics.light()
        statusPill.dqSquish(scale: 0.85)
        onStatusTap?()
    }

    // «Жмяк»: карточка дня сжимается и упруго возвращается.
    // Масштаб мягче, чем у мелких элементов — большая поверхность
    // при сильном сжатии выглядела бы дёшево.
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        // Тап по плашке статуса — не жмяк, у неё своя роль (алерт).
        let location = gesture.location(in: card)
        guard !statusPill.frame.contains(location) else { return }

        Haptics.light()
        card.dqSquish()
    }

    @objc private func streakTapped() {
        Haptics.light()
        streakBadge.dqSquish(scale: 0.85)
        onStreakTap?()
    }

    @objc private func levelTapped() {
        Haptics.light()
        levelBadge.dqSquish(scale: 0.85)
        onLevelTap?()
    }
}

