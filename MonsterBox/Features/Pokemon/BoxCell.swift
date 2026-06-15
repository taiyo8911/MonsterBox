//
//  BoxCell.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI

// ボックスの1マス。
// 個体がいれば SpriteImage、空きマスなら薄い枠、選択中ならハイライト。
struct BoxCell: View {
    let pokemon: OwnedPokemon?
    let isSelected: Bool
    let isMoveTarget: Bool

    var body: some View {
        ZStack {
            background
            if let p = pokemon {
                SpriteImage(dex: p.speciesDex, typeIDs: p.typeIDs)
                    .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(border)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.25))
        } else if isMoveTarget {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.12))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isSelected ? Color.accentColor :
                    (isMoveTarget ? Color.green.opacity(0.5) : Color.secondary.opacity(0.2)),
                lineWidth: isSelected ? 2 : 1
            )
    }
}
