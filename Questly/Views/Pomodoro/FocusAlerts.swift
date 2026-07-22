//
//  FocusAlerts.swift
//  Questly
//
//  Алерты экрана Помодоро как фабрика: контроллер только
//  презентует. Тексты и структура — в одном месте.
//

import UIKit

enum FocusAlerts {

    /// Пикер фокуса: поле ввода + до трёх недавних.
    /// onApply получает выбранное название (nil — без названия).
    static func picker(currentLabel: String?,
                       recents: [String],
                       thenStart: Bool,
                       onApply: @escaping (String?) -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Над чем работаешь?",
            message: "Выбери недавний фокус или впиши новый",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Например: работа над проектом"
            field.text = currentLabel
            field.autocapitalizationType = .sentences
        }

        for recent in recents.prefix(3) {
            alert.addAction(UIAlertAction(title: "↻ \(recent)", style: .default) { _ in
                onApply(recent)
            })
        }

        alert.addAction(UIAlertAction(
            title: thenStart ? "Начать фокус" : "Готово",
            style: .default
        ) { [weak alert] _ in
            let text = alert?.textFields?.first?.text?
                .trimmingCharacters(in: .whitespaces) ?? ""
            onApply(text.isEmpty ? nil : text)
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        return alert
    }

    /// Добавление нового фокуса
    static func addFocus(onAdd: @escaping (String) -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Новый фокус",
            message: "Над чем будешь работать?",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Например: чтение"
            field.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default) { [weak alert] _ in
            let text = alert?.textFields?.first?.text?
                .trimmingCharacters(in: .whitespaces) ?? ""
            guard !text.isEmpty else { return }
            onAdd(text)
        })
        return alert
    }

    /// Подтверждение удаления фокуса из списка
    static func confirmDelete(label: String,
                              onConfirm: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Удалить фокус «\(label)»?",
            message: "История сессий сохранится в статистике",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            onConfirm()
        })
        return alert
    }

    /// Нет доступа к Экранному времени
    static func blockDenied() -> UIAlertController {
        let alert = UIAlertController(
            title: "Нет доступа к Экранному времени",
            message: "Разреши доступ в Настройках iOS → Экранное время, и попробуй снова",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Понятно", style: .default))
        return alert
    }
}

