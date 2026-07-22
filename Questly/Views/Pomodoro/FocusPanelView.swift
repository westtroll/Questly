//
//  FocusPanelView.swift
//  Questly
//
//  Панель фокусов под таймером: карточка текущего фокуса,
//  компактные плашки остальных и кнопка «Добавить фокус».
//  Чистый UI: данные приходят через refresh(with:), намерения
//  пользователя уходят колбэками — алерты показывает контроллер.
//

import UIKit

final class FocusPanelView: UIView {

    // MARK: - Данные

    struct Data {
        let current: String?
        /// Статистика текущего фокуса за сегодня (минуты — с идущей фазой)
        let currentStats: (sessions: Int, minutes: Int)
        /// Остальные фокусы со статистикой за сегодня
        let others: [(label: String, sessions: Int, minutes: Int)]
    }

    // MARK: - Колбэки

    var onEditCurrent: (() -> Void)?
    var onAdd: (() -> Void)?
    var onSelect: ((String) -> Void)?
    /// Долгое нажатие по плашке: контроллер покажет подтверждение
    var onDeleteRequest: ((String) -> Void)?

    // MARK: - Сабвью

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardTitle: UILabel = {
        let l = UILabel()
        l.text = "ТЕКУЩИЙ ФОКУС"
        l.font = DQFont.rounded(13, weight: .bold)
        l.textColor = DQColor.accentDark
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cardValue: UILabel = {
        let l = UILabel()
        l.font = DQFont.rounded(20, weight: .bold)
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cardTime: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Карандаш — подсказка, что карточка тапабельна
    private let cardEdit: UIImageView = {
        let v = UIImageView(image: UIImage(systemName: "pencil.circle.fill"))
        v.tintColor = .tertiaryLabel
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 24).isActive = true
        v.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return v
    }()

    private let listStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var addButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Добавить фокус"
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 6
        config.baseForegroundColor = DQColor.accentDark
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var rowLabels: [String] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        [card, listStack, addButton].forEach { addSubview($0) }
        [cardTitle, cardValue, cardTime, cardEdit].forEach { card.addSubview($0) }

        // НЕ dqMakeSquishy: его внутренний tap-жест конфликтует с нашим.
        // DQPressSquish жмякает при касании и дружит с другими жестами.
        card.addGestureRecognizer(DQPressSquish())
        card.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(editTapped)))

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),

            cardTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            cardTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            cardValue.topAnchor.constraint(equalTo: cardTitle.bottomAnchor, constant: 4),
            cardValue.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardValue.trailingAnchor.constraint(equalTo: cardEdit.leadingAnchor, constant: -10),

            cardTime.topAnchor.constraint(equalTo: cardValue.bottomAnchor, constant: 2),
            cardTime.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardTime.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

            cardEdit.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            cardEdit.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            listStack.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            listStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: trailingAnchor),

            addButton.topAnchor.constraint(equalTo: listStack.bottomAnchor, constant: 4),
            addButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Обновление

    func refresh(with data: Data) {
        // Карточка текущего фокуса
        if let label = data.current, !label.isEmpty {
            let stats = data.currentStats
            let time = PomodoroFormat.timeString(stats.minutes)
            cardValue.text = "🎯 \(label)"
            cardValue.textColor = .label
            cardTime.text = stats.sessions > 0
                ? "Сегодня: \(time) · \(stats.sessions) \(PomodoroFormat.sessionsWord(stats.sessions))"
                : "Сегодня: \(time)"
        } else {
            cardValue.text = "Задать фокус"
            cardValue.textColor = .tertiaryLabel
            cardTime.text = "Назови, над чем работаешь"
        }

        // Плашки остальных
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowLabels = data.others.map(\.label)
        for (index, item) in data.others.enumerated() {
            listStack.addArrangedSubview(makeRow(item: item, tag: index))
        }
    }

    // MARK: - Ряды

    private func makeRow(item: (label: String, sessions: Int, minutes: Int),
                         tag: Int) -> UIView {
        let row = UIView()
        row.backgroundColor = .secondarySystemGroupedBackground
        row.layer.cornerRadius = 12
        row.tag = tag
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let name = UILabel()
        name.text = item.label
        name.font = DQFont.rounded(15, weight: .semibold)
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.75
        name.translatesAutoresizingMaskIntoConstraints = false

        let stats = UILabel()
        stats.text = item.sessions > 0 || item.minutes > 0
            ? "\(PomodoroFormat.timeString(item.minutes)) · \(item.sessions)"
            : "—"
        stats.font = .systemFont(ofSize: 13, weight: .medium)
        stats.textColor = .secondaryLabel
        stats.setContentCompressionResistancePriority(.required, for: .horizontal)
        stats.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(name)
        row.addSubview(stats)
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: stats.leadingAnchor, constant: -10),
            stats.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            stats.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        row.addGestureRecognizer(DQPressSquish())
        row.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:))))
        row.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(rowLongPressed(_:))))
        return row
    }

    // MARK: - Actions

    @objc private func editTapped() {
        Haptics.light()
        onEditCurrent?()
    }

    @objc private func addTapped() {
        Haptics.light()
        onAdd?()
    }

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, rowLabels.indices.contains(tag) else { return }
        Haptics.light()
        onSelect?(rowLabels[tag])
    }

    @objc private func rowLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let tag = gesture.view?.tag,
              rowLabels.indices.contains(tag) else { return }
        onDeleteRequest?(rowLabels[tag])
    }
}

