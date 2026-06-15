//
//  PokemonSprite.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import UIKit
import Combine

// MARK: - スプライト方式
//
// 初回起動時に全件(252体)を PokeAPI から取得してキャッシュし、以降はオフラインで表示する。
// 保存先は Application Support(OSに消されにくい・バックアップ対象外)。
// 取得元: カントー(1-151)＋デオキシス(386)=FRLG、ジョウト(152-251)=エメラルド の第3世代ドット絵。
// 取得元の画像は権利物。取得・利用の判断と責任は利用者にある。

nonisolated enum SpriteProvider {
    private static let base =
        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-iii/"

    /// 取得を試すURLの優先順(先頭が本命、後続はフォールバック)
    static func urls(forDex dex: Int) -> [URL] {
        let frlg = base + "firered-leafgreen/\(dex).png"
        let emerald = base + "emerald/\(dex).png"
        let ordered = (dex <= 151 || dex == 386) ? [frlg, emerald] : [emerald, frlg]
        return ordered.compactMap { URL(string: $0) }
    }

    /// 同梱マスタの対象種族(1-251 ＋ 386)
    static var allDexes: [Int] { Array(1...251) + [386] }
}

// MARK: - ディスクキャッシュ (Application Support)

actor SpriteStore {
    static let shared = SpriteStore()
    private let dir: URL

    init() {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var d = appSup.appendingPathComponent("sprites", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? d.setResourceValues(values)
        dir = d
    }

    private func file(_ dex: Int) -> URL { dir.appendingPathComponent("\(dex).png") }

    /// キャッシュ優先。無ければ取得して保存。取得失敗時は nil。
    func data(forDex dex: Int) async -> Data? {
        if let cached = try? Data(contentsOf: file(dex)) { return cached }
        for url in SpriteProvider.urls(forDex: dex) {
            guard let (data, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
            try? data.write(to: file(dex))
            return data
        }
        return nil
    }
}

// MARK: - 初回起動時の全件先読み

@MainActor
final class SpritePrefetcher: ObservableObject {
    @Published var completed = 0
    @Published var total = 0
    @Published var success = 0
    @Published var isFinished = false

    private let doneKey = "didPrefetchSprites_v1"
    private var alreadyDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// 初回(または前回未完了)のみ全件取得。完了済みなら即終了。
    func prefetchAllIfNeeded() async {
        guard !alreadyDone else {
            let n = SpriteProvider.allDexes.count
            total = n; completed = n; success = n
            isFinished = true
            return
        }
        await runPrefetch()
    }

    /// ユーザー操作による再取得。alreadyDone でも実行する (既キャッシュは即返る)。
    func retry() async {
        await runPrefetch()
    }

    private func runPrefetch() async {
        isFinished = false
        let dexes = SpriteProvider.allDexes
        total = dexes.count
        completed = 0
        success = 0
        for dex in dexes {
            if await SpriteStore.shared.data(forDex: dex) != nil { success += 1 }
            completed += 1
        }
        if success == total {                         // 全部そろったら以降スキップ
            UserDefaults.standard.set(true, forKey: doneKey)
        }
        isFinished = true                             // 一部失敗でもアプリは進める(不足はタイプ色表示)
    }
}

// MARK: - 表示ビュー (キャッシュから・失敗時はタイプ色タイル)

struct SpriteImage: View {
    let dex: Int
    let typeIDs: [String]
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
            } else {
                TypeTile(typeIDs: typeIDs)
            }
        }
        .task(id: dex) { image = await SpriteLoader.image(forDex: dex) }
    }
}

/// デコード済みUIImageのメモリキャッシュ
enum SpriteLoader {
    private static let mem = NSCache<NSNumber, UIImage>()
    static func image(forDex dex: Int) async -> UIImage? {
        let key = NSNumber(value: dex)
        if let cached = mem.object(forKey: key) { return cached }
        guard let data = await SpriteStore.shared.data(forDex: dex),
              let img = UIImage(data: data) else { return nil }
        mem.setObject(img, forKey: key)
        return img
    }
}

// MARK: - タイプ色タイル (画像が無いときのフォールバック兼アクセント)

struct TypeTile: View {
    let typeIDs: [String]
    var body: some View {
        let colors = typeIDs.compactMap { TypeColor.color(for: $0) }
        RoundedRectangle(cornerRadius: 8).fill(gradient(colors))
    }
    private func gradient(_ colors: [Color]) -> LinearGradient {
        let cs = colors.isEmpty ? [Color.gray.opacity(0.4)] : colors
        return LinearGradient(colors: cs.count == 1 ? [cs[0], cs[0]] : cs,
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - タイプ色 (17タイプ・第3世代)

enum TypeColor {
    static func color(for id: String) -> Color? {
        guard let hex = table[id] else { return nil }
        return Color(hex: hex)
    }
    private static let table: [String: UInt] = [
        "normal": 0xA8A878, "fire": 0xF08030, "water": 0x6890F0, "electric": 0xF8D030,
        "grass": 0x78C850, "ice": 0x98D8D8, "fighting": 0xC03028, "poison": 0xA040A0,
        "ground": 0xE0C068, "flying": 0xA890F0, "psychic": 0xF85888, "bug": 0xA8B820,
        "rock": 0xB8A038, "ghost": 0x705898, "dragon": 0x7038F8, "dark": 0x705848,
        "steel": 0xB8B8D0,
    ]
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
