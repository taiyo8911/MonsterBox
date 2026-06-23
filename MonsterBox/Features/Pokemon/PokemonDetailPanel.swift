//
//  PokemonDetailPanel.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/21.
//

import SwiftUI
import SwiftData

// 上下2段構成の個体詳細パネル
// 上段: 左=スプライト/Lv/名前/性別/タイプ、右=能力6種(1列) + せいかく/とくせい
// 下段: おぼえている技 (最大4、全幅で タイプ/威力/命中/PP を表示)
// pokemonの有無に関わらず常に同じViewを描画し、空の場合は各セルがプレースホルダで高さを保つ
struct PokemonDetailPanel: View {
    let pokemon: OwnedPokemon?

    private var master: MasterData { .shared }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                leftColumn(pokemon)
                Divider()
                rightColumn(pokemon)
            }
            Divider()
            movesSection(pokemon)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 上段-左 (スプライト/プロフィール)

    private func leftColumn(_ pokemon: OwnedPokemon?) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if let pokemon {
                    SpriteImage(dex: pokemon.speciesDex, typeIDs: pokemon.typeIDs)
                } else {
                    Color.clear
                }
            }
            .frame(width: 96, height: 96)

            HStack(spacing: 6) {
                if let pokemon {
                    Text("Lv.\(pokemon.level)")
                        .font(.subheadline.bold())
                    Text(pokemon.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                    GenderMark(gender: pokemon.gender)
                } else {
                    Text(" ").font(.subheadline.bold())   // 行高さ確保
                }
            }

            HStack(spacing: 4) {
                if let pokemon {
                    ForEach(pokemon.typeIDs, id: \.self) { TypeBadge(typeID: $0) }
                } else {
                    TypeBadge(typeID: "normal").hidden() // 行高さ確保
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: 上段-右 (能力値 + せいかく/とくせい)

    private func rightColumn(_ pokemon: OwnedPokemon?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            statRow("HP", pokemon?.hp)
            statRow("こうげき", pokemon?.attack)
            statRow("ぼうぎょ", pokemon?.defense)
            statRow("とくこう", pokemon?.spAttack)
            statRow("とくぼう", pokemon?.spDefense)
            statRow("すばやさ", pokemon?.speed)

            Divider().padding(.vertical, 2)

            labeled("せいかく", value: pokemon?.nature.nameJa)
            labeled("とくせい", value: pokemon?.ability?.nameJa)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(_ title: String, _ value: Int?) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.map(String.init) ?? "—")
                .font(.footnote.monospacedDigit())
        }
    }

    private func labeled(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .font(.footnote)
                .lineLimit(1)
        }
    }

    // MARK: 下段 (覚えている技、Gridで列揃え)

    private func movesSection(_ pokemon: OwnedPokemon?) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                moveGridRow(at: i, in: pokemon)
            }
        }
    }

    @ViewBuilder
    private func moveGridRow(at i: Int, in pokemon: OwnedPokemon?) -> some View {
        if let pokemon, i < pokemon.moveIDs.count, let move = master.move(id: pokemon.moveIDs[i]) {
            GridRow {
                Text(move.nameJa)
                    .font(.footnote)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TypeBadge(typeID: move.type)
                statCell("威", move.power)
                statCell("命", move.accuracy)
                statCell("PP", move.pp)
            }
        } else {
            GridRow {
                Text("—")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TypeBadge(typeID: "normal").hidden()
                statCell("威", nil).hidden()
                statCell("命", nil).hidden()
                statCell("PP", nil).hidden()
            }
        }
    }

    private func statCell(_ label: String, _ value: Int?) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value.map(String.init) ?? "—")
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(width: 22, alignment: .trailing)
        }
        .font(.caption2)
    }
}

// MARK: - 性別マーク

private struct GenderMark: View {
    let gender: Gender
    var body: some View {
        switch gender {
        case .male:
            Text("♂").foregroundStyle(.blue).font(.subheadline.bold())
        case .female:
            Text("♀").foregroundStyle(.pink).font(.subheadline.bold())
        case .genderless:
            EmptyView()
        }
    }
}

// MARK: - タイプバッジ

struct TypeBadge: View {
    let typeID: String
    var body: some View {
        let color = TypeColor.color(for: typeID) ?? .gray
        Text(MasterData.shared.typeNameJa(typeID))
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

// MARK: - Preview

#Preview("選択あり") {
    let container = try! ModelContainer(
        for: OwnedPokemon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let sample = OwnedPokemon(
        speciesDex: 4,          // ヒトカゲ
        nickname: "",
        gender: .male,
        level: 16,
        hp: 22, attack: 14, defense: 12,
        spAttack: 16, spDefense: 13, speed: 18,
        nature: .modest,
        abilityID: "blaze",
        moveIDs: ["ember", "scratch", "growl", "smokescreen"],
    )
    container.mainContext.insert(sample)
    return VStack {
        PokemonDetailPanel(pokemon: sample)
        Spacer()
    }
    .padding()
    .modelContainer(container)
}

#Preview("未選択") {
    VStack {
        PokemonDetailPanel(pokemon: nil)
        Spacer()
    }
    .padding()
}
