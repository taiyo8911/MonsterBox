//
//  UserModels.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import Foundation
import SwiftData

// MARK: - 性別

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, genderless
    var id: String { rawValue }
    var nameJa: String {
        switch self {
        case .male: return "オス"
        case .female: return "メス"
        case .genderless: return "性別なし"
        }
    }
}

// MARK: - 性格 (25種)

enum Nature: String, Codable, CaseIterable, Identifiable {
    case hardy, lonely, brave, adamant, naughty
    case bold, docile, relaxed, impish, lax
    case timid, hasty, serious, jolly, naive
    case modest, mild, quiet, bashful, rash
    case calm, gentle, sassy, careful, quirky
    var id: String { rawValue }
    var nameJa: String {
        switch self {
        case .hardy: return "がんばりや"
        case .lonely: return "さみしがり"
        case .brave: return "ゆうかん"
        case .adamant: return "いじっぱり"
        case .naughty: return "やんちゃ"
        case .bold: return "ずぶとい"
        case .docile: return "すなお"
        case .relaxed: return "のんき"
        case .impish: return "わんぱく"
        case .lax: return "のうてんき"
        case .timid: return "おくびょう"
        case .hasty: return "せっかち"
        case .serious: return "まじめ"
        case .jolly: return "ようき"
        case .naive: return "むじゃき"
        case .modest: return "ひかえめ"
        case .mild: return "おっとり"
        case .quiet: return "れいせい"
        case .bashful: return "てれや"
        case .rash: return "うっかりや"
        case .calm: return "おだやか"
        case .gentle: return "おとなしい"
        case .sassy: return "なまいき"
        case .careful: return "しんちょう"
        case .quirky: return "きまぐれ"
        }
    }
}

// MARK: - 所持ポケモン (個体)

@Model
final class OwnedPokemon {
    var speciesDex: Int           // 種族 (図鑑番号)
    var nickname: String
    var genderRaw: String         // Gender.rawValue
    var level: Int

    // 能力値6種
    var hp: Int
    var attack: Int
    var defense: Int
    var spAttack: Int
    var spDefense: Int
    var speed: Int

    var natureRaw: String         // Nature.rawValue
    var heldItem: String          // 持ち物 (自由入力)
    var moveIDs: [String]         // Move.id を最大4つ

    var boxNumber: Int            // 1...14
    var slot: Int                 // 0...29
    var isShiny: Bool
    var memo: String
    var createdAt: Date

    init(
        speciesDex: Int,
        nickname: String = "",
        gender: Gender = .genderless,
        level: Int = 5,
        hp: Int = 0, attack: Int = 0, defense: Int = 0,
        spAttack: Int = 0, spDefense: Int = 0, speed: Int = 0,
        nature: Nature = .hardy,
        heldItem: String = "",
        moveIDs: [String] = [],
        boxNumber: Int = 1,
        slot: Int = 0,
        isShiny: Bool = false,
        memo: String = ""
    ) {
        self.speciesDex = speciesDex
        self.nickname = nickname
        self.genderRaw = gender.rawValue
        self.level = level
        self.hp = hp; self.attack = attack; self.defense = defense
        self.spAttack = spAttack; self.spDefense = spDefense; self.speed = speed
        self.natureRaw = nature.rawValue
        self.heldItem = heldItem
        self.moveIDs = moveIDs
        self.boxNumber = boxNumber
        self.slot = slot
        self.isShiny = isShiny
        self.memo = memo
        self.createdAt = .now
    }
}

extension OwnedPokemon {
    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .genderless }
        set { genderRaw = newValue.rawValue }
    }
    var nature: Nature {
        get { Nature(rawValue: natureRaw) ?? .hardy }
        set { natureRaw = newValue.rawValue }
    }
    /// マスタの種族情報
    var species: Species? { MasterData.shared.species(dex: speciesDex) }
    /// タイプID配列 (一覧の色分け・将来のグラフ集計に使用)
    var typeIDs: [String] { species?.types ?? [] }
    /// 表示名 (ニックネーム優先、無ければ種族名)
    var displayName: String {
        nickname.isEmpty ? (species?.nameJa ?? "?") : nickname
    }
}

// MARK: - ボックス情報

@Model
final class BoxInfo {
    @Attribute(.unique) var boxNumber: Int   // 1...14
    var name: String

    init(boxNumber: Int, name: String) {
        self.boxNumber = boxNumber
        self.name = name
    }
}

// MARK: - 初期データ投入

enum AppSeed {
    static let boxCount = 14
    static let boxCapacity = 30      // 6列 × 5行

    /// 初回起動時に14個のボックスを作成する。
    static func seedBoxesIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<BoxInfo>())) ?? 0
        guard count == 0 else { return }
        for n in 1...boxCount {
            context.insert(BoxInfo(boxNumber: n, name: "ボックス\(n)"))
        }
        try? context.save()
    }
}
