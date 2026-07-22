//
//  AvatarView.swift
//  Questly
//
//  Аватар пользователя: три вида контента на выбор + рамка-кольцо,
//  которая эволюционирует с уровнем.
//
//  Контент (выбирается в редакторе профиля):
//  - эмодзи на цветном фоне (как раньше);
//  - инициалы из имени на градиенте выбранного цвета;
//  - фото из галереи (кроп в круг).
//
//  Рамка живёт отдельно от контента и растёт с прокачкой:
//  ур. 1 — без рамки, 2–4 — серая, 5–9 — бронза, 10–14 — серебро,
//  15–19 — золото, 20+ — переливающийся градиент. Пороги — в ringSpec.
//

import UIKit

// MARK: - Вид аватара

enum AvatarKind: Int {
    case emoji = 0
    case initials
    case photo
}

// MARK: - Хранение (расширяем UserProfile, не трогая Models.swift)

extension UserProfile {

    private static let avatarKindKey = "dq_user_avatar_kind"

    static var avatarKind: AvatarKind {
        get { AvatarKind(rawValue: UserDefaults.standard.integer(forKey: avatarKindKey)) ?? .emoji }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: avatarKindKey) }
    }

    /// Инициалы из имени: «Даниил Алексеев» → «ДА», «Даниил» → «Д»
    static var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    // Фото храним файлом в Documents — UserDefaults не для картинок.
    private static var avatarPhotoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dq_avatar.jpg")
    }

    /// Сохранить фото аватара (ужимается до 512pt по большей стороне)
    static func saveAvatarPhoto(_ image: UIImage) {
        let maxSide: CGFloat = 512
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale,
                          height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? resized.jpegData(compressionQuality: 0.85)?
            .write(to: avatarPhotoURL, options: .atomic)
    }

    static func loadAvatarPhoto() -> UIImage? {
        UIImage(contentsOfFile: avatarPhotoURL.path)
    }

    /// Дочистить аватарные данные при выходе (UserProfile.reset()
    /// про новые ключи не знает — зовём это рядом с ним).
    static func resetAvatarExtras() {
        UserDefaults.standard.removeObject(forKey: avatarKindKey)
        try? FileManager.default.removeItem(at: avatarPhotoURL)
    }
}

// MARK: - Вью аватара

final class AvatarView: UIView {

    // Контент
    private let contentContainer = UIView()
    private let label = UILabel()
    private let imageView = UIImageView()
    private let contentGradient = CAGradientLayer()

    // Рамка-кольцо
    private let ringGradient = CAGradientLayer()
    private let ringMask = CAShapeLayer()

    private var ringWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false   // тапы обрабатывает родитель

        // Кольцо: конический градиент, обрезанный маской до окружности
        ringGradient.type = .conic
        ringGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        ringGradient.endPoint = CGPoint(x: 0.5, y: 0)
        ringMask.fillColor = UIColor.clear.cgColor
        ringMask.strokeColor = UIColor.black.cgColor
        ringGradient.mask = ringMask
        layer.addSublayer(ringGradient)

        contentContainer.clipsToBounds = true
        addSubview(contentContainer)

        contentGradient.startPoint = CGPoint(x: 0, y: 0)
        contentGradient.endPoint = CGPoint(x: 1, y: 1)
        contentContainer.layer.addSublayer(contentGradient)

        label.textAlignment = .center
        contentContainer.addSubview(label)

        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true
        contentContainer.addSubview(imageView)

        // Перекраска динамических цветов при смене светлой/тёмной темы
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: Self, _) in self.applyPending()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Конфигурация

    private var pendingKind: AvatarKind = .emoji
    private var pendingEmoji = "🙂"
    private var pendingColor = "blue"
    private var pendingPhoto: UIImage?
    private var pendingLevel = 1

    /// Собрать аватар из сохранённого профиля
    func configureFromProfile(level: Int) {
        configure(kind: UserProfile.avatarKind,
                  emoji: UserProfile.avatarEmoji,
                  colorName: UserProfile.avatarColorName,
                  photo: UserProfile.avatarKind == .photo ? UserProfile.loadAvatarPhoto() : nil,
                  level: level)
    }

    /// Собрать аватар из произвольных значений (живой предпросмотр
    /// в редакторе — ещё не сохранённый выбор).
    func configure(kind: AvatarKind, emoji: String, colorName: String,
                   photo: UIImage?, level: Int) {
        pendingKind = kind
        pendingEmoji = emoji
        pendingColor = colorName
        pendingPhoto = photo
        pendingLevel = level
        applyPending()
    }

    private func applyPending() {
        let color = CategoryColor.named(pendingColor)

        // Фото без картинки деградирует в инициалы, пустые инициалы —
        // в эмодзи: аватар никогда не бывает пустым.
        var kind = pendingKind
        if kind == .photo && pendingPhoto == nil { kind = .initials }
        if kind == .initials && UserProfile.initials.isEmpty { kind = .emoji }

        switch kind {
        case .emoji:
            imageView.isHidden = true
            label.isHidden = false
            label.text = pendingEmoji
            contentGradient.colors = nil
            contentContainer.backgroundColor = color.background
        case .initials:
            imageView.isHidden = true
            label.isHidden = false
            label.text = UserProfile.initials
            contentContainer.backgroundColor = .clear
            let main = color.main.resolvedColor(with: traitCollection)
            contentGradient.colors = [main.withAlphaComponent(0.65).cgColor,
                                      main.cgColor]
        case .photo:
            label.isHidden = true
            imageView.isHidden = false
            imageView.image = pendingPhoto
            contentGradient.colors = nil
            contentContainer.backgroundColor = .tertiarySystemFill
        }

        // Рамка по уровню
        if let spec = ringSpec(for: pendingLevel) {
            ringWidth = spec.width
            ringGradient.isHidden = false
            ringGradient.colors = spec.colors
                .map { $0.resolvedColor(with: traitCollection).cgColor }
        } else {
            ringWidth = 0
            ringGradient.isHidden = true
        }

        setNeedsLayout()
    }

    // MARK: Рамки по уровням
    //
    // Хочешь поменять пороги или цвета эволюции — правь только здесь.

    private func ringSpec(for level: Int) -> (colors: [UIColor], width: CGFloat)? {
        switch level {
        case ..<2:
            return nil
        case 2...4:   // новичок — скромное серое кольцо
            return ([.systemGray3, .systemGray2, .systemGray3], 2)
        case 5...9:   // бронза
            let bronze = UIColor(red: 0.80, green: 0.50, blue: 0.25, alpha: 1)
            let light  = UIColor(red: 0.95, green: 0.72, blue: 0.45, alpha: 1)
            return ([bronze, light, bronze], 2.5)
        case 10...14: // серебро
            let silver = UIColor(red: 0.65, green: 0.68, blue: 0.73, alpha: 1)
            let light  = UIColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1)
            return ([silver, light, silver], 2.5)
        case 15...19: // золото
            let gold  = UIColor(red: 0.85, green: 0.65, blue: 0.15, alpha: 1)
            let light = UIColor(red: 1.00, green: 0.85, blue: 0.40, alpha: 1)
            return ([gold, light, gold], 3)
        default:      // 20+ — переливающийся градиент, высшая лига
            return ([.systemTeal, .systemIndigo, .systemPink,
                     .systemOrange, .systemTeal], 3.5)
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        ringGradient.frame = bounds
        let ringPath = UIBezierPath(
            ovalIn: bounds.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
        ringMask.frame = bounds
        ringMask.path = ringPath.cgPath
        ringMask.lineWidth = ringWidth

        // Контент — внутри кольца с воздушным зазором
        let inset = ringWidth > 0 ? ringWidth + 2.5 : 0
        contentContainer.frame = bounds.insetBy(dx: inset, dy: inset)
        contentContainer.layer.cornerRadius = contentContainer.bounds.width / 2
        contentGradient.frame = contentContainer.bounds
        label.frame = contentContainer.bounds
        imageView.frame = contentContainer.bounds

        // Размер шрифта — от фактического диаметра
        let side = contentContainer.bounds.width
        label.font = pendingKind == .emoji
            ? .systemFont(ofSize: side * 0.55)
            : .systemFont(ofSize: side * 0.40, weight: .bold)
        label.textColor = .white
    }
}

