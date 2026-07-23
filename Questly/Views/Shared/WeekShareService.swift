//
//  WeekShareService.swift
//  Questly
//
//  Логика «поделиться неделей»: сборка share sheet и копирование
//  текста со ссылкой. Вынесено из HistoryViewController — это
//  чистая работа с системными API, экрану знать её незачем.
//

import UIKit

enum WeekShareService {

    /// Поделиться отчётом недели через системный share sheet.
    /// anchor — bar button на iPad (там поповеру нужен якорь).
    static func share(from presenter: UIViewController,
                      anchor: UIBarButtonItem?) {
        Haptics.light()
        let content = WeeklyReport.shareContent()
        ShareSheet.present(from: presenter,
                           image: content.image,
                           text: content.text,
                           fileName: "Questly — моя неделя.png",
                           anchor: anchor)
    }

    /// Скопировать подпись со ссылкой в буфер — гарантированный путь
    /// для текста (системный Copy в шторке берёт только картинку).
    static func copyText() {
        UIPasteboard.general.string = WeeklyReport.shareContent().text
        Haptics.success()
    }
}
