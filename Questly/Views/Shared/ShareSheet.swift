//
//  ShareSheet.swift
//  Questly
//
//  Created by Даниил Алексеев on 23.07.2026.
//


//
//  ShareSheet.swift
//  Questly
//
//  Единый способ поделиться карточкой: картинка + подпись через
//  системный share sheet. Использовался в двух местах (недельный
//  отчёт и приглашение в челлендж) почти одинаковым кодом —
//  теперь один хелпер.
//

import UIKit

enum ShareSheet {

    /// - Parameters:
    ///   - image: карточка для шаринга
    ///   - text: подпись (дублируется в буфер обмена)
    ///   - fileName: имя временного файла — его видно в шторке
    ///   - anchor: bar button для поповера на iPad
    static func present(from presenter: UIViewController,
                        image: UIImage,
                        text: String,
                        fileName: String,
                        anchor: UIBarButtonItem?) {
        // Делимся ФАЙЛОМ, а не голым UIImage: файлу шторка гарантированно
        // рисует превью и имя, Copy/Сохранить работают предсказуемо.
        var items: [Any] = [text]
        if let data = image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try? data.write(to: url)
            items.insert(url, at: 0)
        }

        // Подпись — заранее в буфер: в приложениях, которые берут
        // только картинку, текст можно просто вставить.
        UIPasteboard.general.string = text

        let activity = UIActivityViewController(activityItems: items,
                                                applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = anchor
        presenter.present(activity, animated: true)
    }
}