//
//  PokemonListView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// 所持ポケモンの一覧表示。
// ソートキー: 図鑑番号 / レベル / 名前 / タイプ / 性格 / 持ち物。
// 行タップで個体詳細へ。
struct PokemonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPokemon: [OwnedPokemon]
    @State private var sortKey: SortKey = .dex
    @State private var releaseTarget: OwnedPokemon?

    enum SortKey: String, CaseIterable, Identifiable {
        case dex, level, name, type, nature, heldItem
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dex: return "図鑑番号"
            case .level: return "レベル"
            case .name: return "名前"
            case .type: return "タイプ"
            case .nature: return "性格"
            case .heldItem: return "持ち物"
            }
        }
    }

    private var sortedPokemon: [OwnedPokemon] {
        allPokemon.sorted { a, b in
            switch sortKey {
            case .dex:
                if a.speciesDex != b.speciesDex { return a.speciesDex < b.speciesDex }
                return a.createdAt < b.createdAt
            case .level:
                if a.level != b.level { return a.level > b.level }
                return a.speciesDex < b.speciesDex
            case .name:
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            case .type:
                let at = a.typeIDs.first ?? ""
                let bt = b.typeIDs.first ?? ""
                if at != bt { return at < bt }
                return a.speciesDex < b.speciesDex
            case .nature:
                if a.nature.nameJa != b.nature.nameJa {
                    return a.nature.nameJa.localizedStandardCompare(b.nature.nameJa) == .orderedAscending
                }
                return a.speciesDex < b.speciesDex
            case .heldItem:
                if a.heldItem != b.heldItem {
                    return a.heldItem.localizedStandardCompare(b.heldItem) == .orderedAscending
                }
                return a.speciesDex < b.speciesDex
            }
        }
    }

    var body: some View {
        Group {
            if allPokemon.isEmpty {
                ContentUnavailableView(
                    "ポケモンがいません",
                    systemImage: "tray",
                    description: Text("右上の + から登録できます。")
                )
            } else {
                List {
                    ForEach(sortedPokemon) { p in
                        NavigationLink {
                            PokemonDetailView(pokemon: p)
                        } label: {
                            PokemonRow(pokemon: p)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                releaseTarget = p
                            } label: {
                                Label("にがす", systemImage: "tray.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
        .alert(
            "\(releaseTarget?.displayName ?? "") を にがしますか？",
            isPresented: Binding(
                get: { releaseTarget != nil },
                set: { if !$0 { releaseTarget = nil } }
            ),
            presenting: releaseTarget
        ) { p in
            Button("にがす", role: .destructive) { release(p) }
            Button("キャンセル", role: .cancel) {}
        } message: { _ in
            Text("元に戻せません。")
        }
        .toolbar {
            if !allPokemon.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("並び替え", selection: $sortKey) {
                            ForEach(SortKey.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label("並び替え", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private func release(_ p: OwnedPokemon) {
        modelContext.delete(p)
        try? modelContext.save()
        releaseTarget = nil
    }
}

// MARK: - 1行

private struct PokemonRow: View {
    let pokemon: OwnedPokemon

    var body: some View {
        HStack(spacing: 12) {
            SpriteImage(dex: pokemon.speciesDex, typeIDs: pokemon.typeIDs)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pokemon.displayName)
                        .font(.body)
                    Text("Lv.\(pokemon.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    ForEach(pokemon.typeIDs, id: \.self) { TypeBadge(typeID: $0) }
                    if !pokemon.heldItem.isEmpty {
                        Text("・\(pokemon.heldItem)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(pokemon.nature.nameJa)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
