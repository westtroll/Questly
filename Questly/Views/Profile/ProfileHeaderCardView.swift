//
//  ProfileHeaderCardView.swift
//  Questly
//
//  Шапка профиля: аватар с рамкой уровня, приветствие, детали
//  (пол · возраст), «в Questly с…» и карандаш-подсказка.
//  Тап по всей карточке — редактирование (колбэк onTap).
//

import UIKit

final class ProfileHeaderCardView: UIView {

    var onTap: (() -> Void)?

    private let avatarView: AvatarView = {
        let view = AvatarView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let greetingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let memberLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let editIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "pencil.circle.fill"))
        iv.tintColor = .tertiaryLabel
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 20
        translatesAutoresizingMaskIntoConstraints = false

        [avatarView, greetingLabel, detailsLabel, memberLabel, editIcon]
            .forEach { addSubview($0) }

        dqMakePressable()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            // Высоту карточки задаёт колонка из трёх строк (нижний
            // constraint memberLabel); аватар лишь гарантирует минимум.
            avatarView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            avatarView.widthAnchor.constraint(equalToConstant: 60),
            avatarView.heightAnchor.constraint(equalToConstant: 60),

            greetingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            greetingLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            greetingLabel.trailingAnchor.constraint(lessThanOrEqualTo: editIcon.leadingAnchor, constant: -8),

            detailsLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 2),
            detailsLabel.leadingAnchor.constraint(equalTo: greetingLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(lessThanOrEqualTo: editIcon.leadingAnchor, constant: -8),

            memberLabel.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 2),
            memberLabel.leadingAnchor.constraint(equalTo: greetingLabel.leadingAnchor),
            memberLabel.trailingAnchor.constraint(lessThanOrEqualTo: editIcon.leadingAnchor, constant: -8),
            memberLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            editIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            editIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// level — для рамки аватара по уровню
    func refresh(level: Int) {
        greetingLabel.text = UserProfile.greeting
        detailsLabel.text = UserProfile.detailsLine
        memberLabel.text = UserProfile.memberSinceLine
        avatarView.configureFromProfile(level: level)
    }

    @objc private func tapped() {
        Haptics.light()
        onTap?()
    }
}

