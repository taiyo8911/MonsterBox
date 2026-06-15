//
//  FRLGMasterData.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import Foundation

// MARK: - マスタデータ (frlg_master.json / 読み取り専用)
//
// 同梱JSONの3ブロック (types / species / moves) に対応する Codable 構造体と、
// 起動時に読み込んで参照用の辞書・ヘルパーを提供するローダ。
// JSONはsnake_case (name_ja など) なので .convertFromSnakeCase で取り込む。

struct TypeEntry: Codable, Identifiable, Hashable {
    let id: String          // 英語スラッグ (例: "fire")
    let nameJa: String
    let nameEn: String
}

struct LearnEntry: Codable, Hashable {
    let move: String        // Move.id を参照
    let methods: [String]   // "level-up" / "machine" / "tutor" / "egg"
    let level: Int?         // レベルアップ最小Lv (無ければ nil)
}

struct Species: Codable, Identifiable, Hashable {
    var id: Int { dex }
    let dex: Int            // 全国図鑑番号
    let nameJa: String
    let nameEn: String
    let types: [String]     // TypeEntry.id の配列 (1〜2個)
    let learnset: [LearnEntry]
}

struct Move: Codable, Identifiable, Hashable {
    let id: String          // 英語スラッグ (例: "ember")
    let nameJa: String
    let nameEn: String
    let type: String        // TypeEntry.id
    let category: String    // "physical" / "special" / "status"
    let power: Int?
    let accuracy: Int?
    let pp: Int?
}

private struct MasterFile: Codable {
    let types: [TypeEntry]
    let species: [Species]
    let moves: [Move]
}

/// 同梱 frlg_master.json を読み込み、参照APIを提供するシングルトン。
final class MasterData {
    static let shared = MasterData()

    let types: [TypeEntry]
    let species: [Species]       // dex昇順
    let moves: [Move]

    let typeByID: [String: TypeEntry]
    let speciesByDex: [Int: Species]
    let moveByID: [String: Move]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "frlg_master", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("frlg_master.json が見つかりません。アプリの Bundle に追加してください。")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let file = try? decoder.decode(MasterFile.self, from: data) else {
            fatalError("frlg_master.json のデコードに失敗しました。")
        }
        self.types = file.types
        self.species = file.species.sorted { $0.dex < $1.dex }
        self.moves = file.moves
        self.typeByID = Dictionary(uniqueKeysWithValues: file.types.map { ($0.id, $0) })
        self.speciesByDex = Dictionary(uniqueKeysWithValues: file.species.map { ($0.dex, $0) })
        self.moveByID = Dictionary(uniqueKeysWithValues: file.moves.map { ($0.id, $0) })
    }

    // MARK: 参照ヘルパー

    func species(dex: Int) -> Species? { speciesByDex[dex] }
    func move(id: String) -> Move? { moveByID[id] }
    func type(id: String) -> TypeEntry? { typeByID[id] }

    /// 技ID → 日本語名 (見つからなければIDを返す)
    func moveNameJa(_ id: String) -> String { moveByID[id]?.nameJa ?? id }

    /// タイプID → 日本語名
    func typeNameJa(_ id: String) -> String { typeByID[id]?.nameJa ?? id }

    /// その種族が覚えられる技 (重複なし・日本語名順)。登録フォームの技候補に使う。
    func learnableMoves(forDex dex: Int) -> [Move] {
        guard let sp = speciesByDex[dex] else { return [] }
        let ids = Set(sp.learnset.map { $0.move })
        return ids.compactMap { moveByID[$0] }
            .sorted { $0.nameJa.localizedStandardCompare($1.nameJa) == .orderedAscending }
    }
}
