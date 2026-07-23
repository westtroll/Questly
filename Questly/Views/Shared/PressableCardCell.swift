//
//  PressableCardCell.swift
//  Questly
//
//  Created by Даниил Алексеев on 23.07.2026.
//


//
//  PressableCardCell.swift
//  Questly
//
//  База для табличных ячеек-карточек: «жмяк» при нажатии.
//  Анимация была скопирована в нескольких ячейках — теперь
//  наследники получают её бесплатно, задав pressScale.
//

import UIKit

class PressableCardCell: UITableViewCell {

    /// Насколько прожимается карточка. Переопредели в наследнике.
    var pressScale: CGFloat { 0.965 }

    /// Вью, которую жмякаем. Наследник обязан её назначить.
    var pressableCard: UIView?

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        guard let card = pressableCard else { return }

        if highlighted {
            UIView.animate(withDuration: 0.12,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                card.transform = CGAffineTransform(scaleX: self.pressScale, y: self.pressScale)
            }
        } else {
            UIView.animate(withDuration: 0.4,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                card.transform = .identity
            }
        }
    }
}