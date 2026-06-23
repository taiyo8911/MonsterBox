//
//  BoxMoveModel.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import Foundation
import SwiftData

// 持ち替え式の移動状態を保持する
// 1) ポケモンをタップして「移動」を選ぶと、その個体が手元 (held) に乗る (元マスは空く)
// 2) 空きマスをタップで置く → 移動完了
// 3) 占有マスをタップで「置く+元の子を持ち上げる (持ち替え)」
// 4) 空きマスに置くまで継続。キャンセルすると元の場所に戻す

@Observable
final class BoxMoveModel {
    /// 手元にいる個体 (移動モード中のみ非nil)
    var held: OwnedPokemon?
    /// 移動モード開始時の元の位置 (キャンセル時に戻すため)
    private var origin: (box: Int, slot: Int)?

    var isMoving: Bool { held != nil }

    /// 移動開始。元位置を覚え、個体は宙吊り (boxNumber/slot は触らない方針) ではなく、
    /// 仕様の「元マスは空く」を満たすため、便宜上 box=0 (非表示) に退避する
    func beginMove(_ p: OwnedPokemon) {
        guard held == nil else { return }
        origin = (p.boxNumber, p.slot)
        held = p
        p.boxNumber = 0   // 0 を「手元 (どのボックスにも属さない)」として扱う
    }

    /// 指定マスに置く。占有マスなら持ち替え (旧住人を手元へ)空きマスなら確定
    /// - Returns: 移動が完了 (held が空になった) なら true
    @discardableResult
    func place(box: Int, slot: Int, occupant: OwnedPokemon?) -> Bool {
        guard let p = held else { return false }
        if let other = occupant, other.persistentModelID != p.persistentModelID {
            // 占有マス: 旧住人を手元へ、自分はそのマスに収まる
            other.boxNumber = 0
            p.boxNumber = box
            p.slot = slot
            held = other
            // origin はそのまま (最初の元位置に戻す用)
            return false
        } else {
            // 空きマスまたは自分自身: 確定
            p.boxNumber = box
            p.slot = slot
            held = nil
            origin = nil
            return true
        }
    }

    /// キャンセル: 手元の個体を元位置に戻す。
    func cancel() {
        guard let p = held, let o = origin else { return }
        p.boxNumber = o.box
        p.slot = o.slot
        held = nil
        origin = nil
    }
}
