//
//  MainTabBarController.swift
//  Questly
//
//  Корневой таб-бар: Сегодня / История / Настройки.
//  Каждая вкладка обёрнута в свой UINavigationController —
//  так у каждой свой независимый стек навигации.
//  Четвёртую вкладку (Помодоро) добавим в будущих обновлениях.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let today = makeTab(
            root: TodayViewController(),
            title: "Сегодня",
            icon: "checklist",
            largeTitles: true
        )

        let pomodoro = makeTab(
            root: PomodoroViewController(),
            title: "Помодоро",
            icon: "timer"
        )

        let history = makeTab(
            root: HistoryViewController(),
            title: "История",
            icon: "calendar"
        )

        let habits = makeTab(
            root: HabitsViewController(),
            title: "Привычки",
            icon: "leaf.fill"
        )

        let profile = makeTab(
            root: ProfileViewController(),
            title: "Профиль",
            icon: "person.fill"
        )

        viewControllers = [today, pomodoro, history, habits, profile]
    }

    private func makeTab(root: UIViewController, title: String,
                         icon: String, largeTitles: Bool = false) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = largeTitles
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            selectedImage: nil
        )
        return nav
    }
}
