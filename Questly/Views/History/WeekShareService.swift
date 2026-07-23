//
//  WeekShareService.swift
//  Questly
//
//  Created by Даниил Алексеев on 23.07.2026.
//


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

        // Делимся ФАЙЛОМ, а не голым UIImage: файлу шторка гарантированно
        // рисует превью и имя, Copy/Сохранить работают предсказуемо.
        var items: [Any] = [content.text]
        if let data = content.image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Questly — моя неделя.png")
            try? data.write(to: url)
            items.insert(url, at: 0)
        }

        let activity = UIActivityViewController(activityItems: items,
                                                applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = anchor
        // Подпись дублируем в буфер заранее: в приложениях, которые
        // берут только картинку, текст можно просто вставить.
        UIPasteboard.general.string = content.text
        presenter.present(activity, animated: true)
    }

    /// Скопировать подпись со ссылкой в буфер — гарантированный путь
    /// для текста (системный Copy в шторке берёт только картинку).
    static func copyText() {
        UIPasteboard.general.string = WeeklyReport.shareContent().text
        Haptics.success()
    }
}