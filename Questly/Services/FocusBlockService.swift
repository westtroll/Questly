//
//  FocusBlockService.swift
//  Questly
//
//  Блокировка приложений на время фокуса через Screen Time API:
//  - FamilyControls — разрешение и системный пикер выбора приложений;
//  - ManagedSettings — «щит», который блокирует выбранное.
//
//  ТРЕБОВАНИЯ:
//  - capability «Family Controls» у таргета приложения;
//  - только реальное устройство (в симуляторе не работает);
//  - устройство залогинено в iCloud.
//

import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings

@MainActor
final class FocusBlockService {

    static let shared = FocusBlockService()

    // ManagedSettingsStore — тот самый «щит». Настройки в нём
    // живут на уровне системы: переживают сворачивание и даже
    // завершение приложения, поэтому снимать их нужно явно.
    private let store = ManagedSettingsStore()

    private let enabledKey = "dq_block_enabled"
    private let selectionKey = "dq_block_selection"

    private init() {
        // Загружаем сохранённый выбор приложений.
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
    }

    // MARK: - Состояние

    /// Тумблер «блокировать во время фокуса»
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Выбранные приложения/категории. FamilyActivitySelection — Codable,
    /// поэтому спокойно живёт в UserDefaults как JSON.
    var selection: FamilyActivitySelection {
        didSet {
            if let data = try? JSONEncoder().encode(selection) {
                UserDefaults.standard.set(data, forKey: selectionKey)
            }
        }
    }

    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Сколько всего выбрано (приложения + категории) — для подписи в UI
    var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    // MARK: - Разрешение

    /// Запрос доступа Screen Time. Системный экран, async.
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Щит

    /// Включить блокировку выбранного (вызывается на старте фокуса)
    func startBlocking() {
        guard isEnabled, isAuthorized, selectionCount > 0 else { return }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    /// Снять блокировку (пауза, перерыв, конец фазы, запуск приложения)
    func stopBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

// MARK: - SwiftUI-обёртка системного пикера
//
// FamilyActivityPicker существует ТОЛЬКО как SwiftUI-view —
// оборачиваем его для показа из UIKit через UIHostingController.

struct AppPickerView: View {

    @State var selection: FamilyActivitySelection
    var onDone: (FamilyActivitySelection) -> Void

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Что блокировать")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            onDone(selection)
                        }
                    }
                }
        }
    }
}

