//
//  SoundService.swift
//  Questly
//
//  Звуковое сопровождение геймификации: короткие «награждающие»
//  звуки на ключевые моменты. Дофаминовая петля: действие → звук.
//
//  Файлы кладутся в бандл с именами из enum ниже (расширение —
//  любое из поддерживаемых, сервис переберёт сам).
//

import AVFoundation

@MainActor
enum SoundService {

    /// Звуковые события и имена файлов в бандле
    enum Sound: String, CaseIterable {
        case taskDone    = "Level Up 01"            // задача выполнена
        case questDone   = "Positive Blip Effect"   // квест дня выполнен
        case levelUp     = "Congrats! 2"            // новый уровень
        case achievement = "success"                // открыта ачивка
    }

    private static let enabledKey = "dq_sounds_enabled"

    /// Тумблер в настройках. По умолчанию включено.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // Плееры кэшируются: создание AVAudioPlayer при каждом
    // проигрывании давало бы задержку и заикание.
    private static var players: [Sound: AVAudioPlayer] = [:]
    private static var sessionConfigured = false

    static func play(_ sound: Sound) {
        guard isEnabled else { return }
        configureSessionIfNeeded()

        if players[sound] == nil {
            players[sound] = loadPlayer(for: sound)
        }
        guard let player = players[sound] else { return }

        // С начала — даже если предыдущее воспроизведение не докончилось
        // (быстрые отметки задач подряд).
        player.currentTime = 0
        player.play()
    }

    // MARK: - Внутреннее

    private static func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        // .ambient: уважает беззвучный переключатель и НЕ прерывает
        // музыку пользователя — обязательные манеры для игровых кликов.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func loadPlayer(for sound: Sound) -> AVAudioPlayer? {
        // Перебираем популярные расширения — не важно, в каком
        // формате добавлены файлы.
        for ext in ["wav", "mp3", "m4a", "caf", "aiff"] {
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: ext),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                return player
            }
        }
        // Файла нет — молчим, не падаем. Приложение работает и без звука.
        return nil
    }
}

