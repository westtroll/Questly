//
//  SceneDelegate.swift
//  Questly
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Задачи, отмеченные на виджете, пока приложение не работало, —
        // применяем ДО построения UI, чтобы экраны сразу были честными.
        DataStore.shared.applyPendingWidgetCompletions()

        window = UIWindow(windowScene: windowScene)
        // Глобальный бирюзовый акцент — красит кнопки, ссылки,
        // свитчи, курсоры во всём приложении одним махом.
        window?.tintColor = DQColor.accentAdaptive

        // Первый запуск — показываем онбординг,
        // дальше корнем всегда стоит таб-бар.
        if UserProfile.hasCompletedOnboarding {
            window?.rootViewController = MainTabBarController()
        } else {
            let onboarding = OnboardingViewController()
            onboarding.onFinish = { [weak self] in
                UserProfile.hasCompletedOnboarding = true
                guard let window = self?.window else { return }
                window.rootViewController = MainTabBarController()
                // Плавная смена корневого контроллера
                UIView.transition(with: window, duration: 0.4,
                                  options: .transitionCrossDissolve, animations: nil)
            }
            window?.rootViewController = onboarding
        }

        window?.makeKeyAndVisible()

        // Живой сплэш поверх приложения: продолжает статичный
        // лаунч-скрин (та же картинка и фон), даёт лого «вдохнуть»
        // с хаптиком и растворяется. Приложение под ним уже готово.
        if let window {
            SplashOverlay.show(in: window)
        }

        // Применяем сохранённую тему сразу при запуске.
        ThemeManager.apply()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Тема «Авто» зависит от часа — пересчитываем при каждом
        // возвращении приложения на передний план.
        ThemeManager.apply()
    }

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Задачи, отмеченные на виджете, пока мы были в фоне.
        DataStore.shared.applyPendingWidgetCompletions()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // На всякий случай сохраняемся при уходе в фон.
        DataStore.shared.save()
    }
}

