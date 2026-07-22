//
//  PomodoroIntents.swift
//  Questly
//
//  Кнопки на плашке Live Activity. LiveActivityIntent выполняется
//  в процессе ПРИЛОЖЕНИЯ (не виджета), поэтому напрямую дёргает
//  общий PomodoroViewModel.shared — тот же таймер, что и на экране.
//
//  ВАЖНО: файл должен входить в ОБА таргета (как и Attributes):
//  виджету нужны сами типы для Button(intent:), приложению —
//  реализация. В виджет-таргете тело perform() вырезается флагом
//  WIDGET_EXTENSION — он должен быть добавлен в Build Settings
//  виджета: Active Compilation Conditions → WIDGET_EXTENSION.
//

import AppIntents

/// «Завершить» — остановить сессию досрочно и убрать плашку
struct EndPomodoroIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Завершить сессию"

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run { PomodoroViewModel.shared.endFromLiveActivity() }
        #endif
        return .result()
    }
}

/// «Старт» — фаза дотикала, пока телефон лежал: засчитать её
/// и запустить следующую (перерыв после фокуса или фокус после перерыва)
struct StartNextPhaseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Начать следующую фазу"

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run { PomodoroViewModel.shared.startNextFromLiveActivity() }
        #endif
        return .result()
    }
}

