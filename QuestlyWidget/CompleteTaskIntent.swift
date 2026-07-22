//
//  CompleteTaskIntent.swift
//  QuestlyWidgetExtension
//
//  Тап по задаче на домашнем виджете. Выполняется в процессе
//  ВИДЖЕТА: оптимистично правит снапшот (мгновенная галочка)
//  и ставит команду в очередь — приложение применит её к
//  настоящим данным при следующем открытии.
//
//  Файл кладётся ТОЛЬКО в виджет-таргет.
//

import AppIntents
import WidgetKit

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Выполнить задачу"

    @Parameter(title: "ID задачи")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.completeTaskOptimistically(taskID: taskID)
        return .result()
    }
}

