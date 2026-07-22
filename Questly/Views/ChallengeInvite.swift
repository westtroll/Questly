//
//  ChallengeInvite.swift
//  Questly
//
//  «Бросить вызов другу»: карточка-приглашение на челлендж +
//  текст со ссылкой. Социальность без сервера — вызов живёт
//  в переписке, а карточка ведёт в App Store.
//

import UIKit

enum ChallengeInvite {

    /// Картинка-вызов + текст для share sheet.
    @MainActor
    static func shareContent(for challenge: Challenge) -> (image: UIImage, text: String) {
        let text = """
        Бросаю тебе вызов: челлендж «\(challenge.title)» в Questly 🏁
        7 дней испытания и +\(Challenge.rewardXP) XP за прохождение. Слабо вместе со мной?
        \(AppConfig.appStoreURL)
        """
        return (render(challenge: challenge), text)
    }

    // MARK: - Рендер карточки

    @MainActor
    private static func render(challenge: Challenge) -> UIImage {
        let size = CGSize(width: 600, height: 640)
        let card = UIView(frame: CGRect(origin: .zero, size: size))
        card.backgroundColor = UIColor(red: 0.992, green: 0.976, blue: 0.965, alpha: 1)

        // Шапка-марка
        let mark = UIImageView(image: UIImage(systemName: "checkmark.seal.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)))
        mark.tintColor = DQColor.accent
        mark.frame = CGRect(x: 48, y: 44, width: 40, height: 38)
        card.addSubview(mark)

        let name = UILabel(frame: CGRect(x: 98, y: 46, width: 300, height: 32))
        name.text = "Questly"
        name.font = DQFont.rounded(24, weight: .bold)
        name.textColor = DQColor.accentDark
        card.addSubview(name)

        // Плашка «ВЫЗОВ» — фиолетовая, цвет челленджей
        let badge = UILabel(frame: CGRect(x: size.width - 168, y: 48, width: 120, height: 32))
        badge.text = "ВЫЗОВ 🏁"
        badge.font = DQFont.rounded(15, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = DQColor.challenge
        badge.layer.cornerRadius = 16
        badge.layer.masksToBounds = true
        card.addSubview(badge)

        // Эмодзи челленджа в большом фиолетовом кружке
        let circle = UIView(frame: CGRect(x: (size.width - 150) / 2, y: 130,
                                          width: 150, height: 150))
        circle.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.99, alpha: 1)
        circle.layer.cornerRadius = 75
        card.addSubview(circle)

        let emoji = UILabel(frame: circle.frame)
        emoji.text = challenge.emoji
        emoji.font = .systemFont(ofSize: 76)
        emoji.textAlignment = .center
        card.addSubview(emoji)

        // Заголовок вызова
        let callTitle = UILabel(frame: CGRect(x: 40, y: 306, width: size.width - 80, height: 40))
        callTitle.text = "Пройди «\(challenge.title)» со мной!"
        callTitle.font = DQFont.rounded(27, weight: .bold)
        callTitle.textColor = UIColor(red: 0.16, green: 0.20, blue: 0.29, alpha: 1)
        callTitle.textAlignment = .center
        callTitle.adjustsFontSizeToFitWidth = true
        callTitle.minimumScaleFactor = 0.6
        card.addSubview(callTitle)

        // Описание челленджа
        let details = UILabel(frame: CGRect(x: 60, y: 352, width: size.width - 120, height: 60))
        details.text = challenge.details
        details.font = .systemFont(ofSize: 16)
        details.textColor = .darkGray
        details.textAlignment = .center
        details.numberOfLines = 2
        card.addSubview(details)

        // Факты: 7 дней · +XP
        let facts = UILabel(frame: CGRect(x: 0, y: 430, width: size.width, height: 30))
        facts.text = "7 дней · награда +\(Challenge.rewardXP) XP"
        facts.font = DQFont.rounded(20, weight: .bold)
        facts.textColor = DQColor.challengeDark
        facts.textAlignment = .center
        card.addSubview(facts)

        // Футер: призыв + ссылка (впечены в картинку)
        let slogan = UILabel(frame: CGRect(x: 0, y: 508, width: size.width, height: 22))
        slogan.text = "Принимаешь вызов? Скачивай:"
        slogan.font = .systemFont(ofSize: 16)
        slogan.textColor = UIColor(red: 0.180, green: 0.227, blue: 0.314, alpha: 0.75)
        slogan.textAlignment = .center
        card.addSubview(slogan)

        let link = UILabel(frame: CGRect(x: 0, y: 536, width: size.width, height: 24))
        link.text = AppConfig.appStoreURL.replacingOccurrences(of: "https://", with: "")
        link.font = DQFont.rounded(17, weight: .semibold)
        link.textColor = DQColor.accent
        link.textAlignment = .center
        card.addSubview(link)

        let brand = UILabel(frame: CGRect(x: 0, y: 584, width: size.width, height: 18))
        brand.text = "Каждый день — квест"
        brand.font = .systemFont(ofSize: 12)
        brand.textColor = .gray
        brand.textAlignment = .center
        card.addSubview(brand)

        card.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            card.layer.render(in: context.cgContext)
        }
    }
}

