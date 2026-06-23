//
//  PokemonDetailPanel.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/21.
//

import SwiftUI

// 上段に表示する個体詳細パネル。左右2カラム構成。
// 左: Lv/名前/性別 → スプライト → タイプ → おぼえている技 (最大4)
// 右: 能力6種 → せいかく → とくせい
// 未選択時 (pokemon == nil) は枠だけ残して中身を空にする (C案: プレースホルダ)。
struct PokemonDetailPanel: View {
    let pokemon: OwnedPokemon?

    private var master: MasterData { .shared }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let pokemon {
                leftColumn(pokemon)
                Divider()
                rightColumn(pokemon)
            } else {
                Color.clear
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 左カラム

    private func leftColumn(_ pokemon: OwnedPokemon) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Lv.\(pokemon.level)")
                    .font(.subheadline.bold())
                Text(pokemon.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                GenderMark(gender: pokemon.gender)
            }

            SpriteImage(dex: pokemon.speciesDex, typeIDs: pokemon.typeIDs)
                .frame(width: 96, height: 96)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 4) {
                ForEach(pokemon.typeIDs, id: \.self) { TypeBadge(typeID: $0) }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if pokemon.moveIDs.isEmpty {
                Text("技 —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pokemon.moveIDs, id: \.self) { id in
                    if let move = master.move(id: id) {
                        MoveRow(move: move)
                    } else {
                        Text(id).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeled(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
        }
    }

    // MARK: 右カラム

    private func rightColumn(_ pokemon: OwnedPokemon) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            statRow("HP", pokemon.hp)
            statRow("こうげき", pokemon.attack)
            statRow("ぼうぎょ", pokemon.defense)
            statRow("とくこう", pokemon.spAttack)
            statRow("とくぼう", pokemon.spDefense)
            statRow("すばやさ", pokemon.speed)

            Divider().padding(.vertical, 2)

            labeled("せいかく", value: pokemon.nature.nameJa)
            labeled("とくせい", value: pokemon.ability?.nameJa ?? "—")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.footnote.monospacedDigit())
        }
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

// MARK: - 技1行

struct MoveRow: View {
    let move: Move
    var body: some View {
        HStack {
            Text(move.nameJa)
                .font(.footnote)
            Spacer()
            TypeBadge(typeID: move.type)
        }
    }
}
