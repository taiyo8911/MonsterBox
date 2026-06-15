//
//  PokemonDetailView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// 個体詳細 (強さを見る)
// 種族・タイプ・レベル・能力値6・性格・持ち物・覚えている技 を表示し、
// 編集フォームへの導線を提供する。
struct PokemonDetailView: View {
    @Bindable var pokemon: OwnedPokemon
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showReleaseAlert = false

    private var species: Species? { pokemon.species }
    private var master: MasterData { .shared }

    var body: some View {
        Form {
            headerSection
            statusSection
            profileSection
            movesSection
            releaseSection
        }
        .navigationTitle(pokemon.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集する") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                PokemonEditorView(mode: .edit(pokemon))
            }
        }
        .alert("\(pokemon.displayName) を にがしますか？", isPresented: $showReleaseAlert) {
            Button("にがす", role: .destructive) { release() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("元に戻せません。")
        }
    }

    private func release() {
        modelContext.delete(pokemon)
        try? modelContext.save()
        dismiss()
    }

    // MARK: 種族・スプライト

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                SpriteImage(dex: pokemon.speciesDex, typeIDs: pokemon.typeIDs)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(species?.nameJa ?? "?")
                        .font(.headline)
                    Text("No.\(pokemon.speciesDex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(pokemon.typeIDs, id: \.self) { id in
                            TypeBadge(typeID: id)
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: 能力値

    private var statusSection: some View {
        Section("能力") {
            LabeledContent("レベル", value: "\(pokemon.level)")
            LabeledContent("HP", value: "\(pokemon.hp)")
            LabeledContent("こうげき", value: "\(pokemon.attack)")
            LabeledContent("ぼうぎょ", value: "\(pokemon.defense)")
            LabeledContent("とくこう", value: "\(pokemon.spAttack)")
            LabeledContent("とくぼう", value: "\(pokemon.spDefense)")
            LabeledContent("すばやさ", value: "\(pokemon.speed)")
        }
    }

    // MARK: プロフィール

    private var profileSection: some View {
        Section("プロフィール") {
            LabeledContent("ニックネーム", value: pokemon.nickname.isEmpty ? "—" : pokemon.nickname)
            LabeledContent("性別", value: pokemon.gender.nameJa)
            LabeledContent("性格", value: pokemon.nature.nameJa)
            LabeledContent("持ち物", value: pokemon.heldItem.isEmpty ? "—" : pokemon.heldItem)
            LabeledContent("ボックス", value: "\(pokemon.boxNumber) / スロット \(pokemon.slot + 1)")
            if !pokemon.memo.isEmpty {
                LabeledContent("メモ", value: pokemon.memo)
            }
        }
    }

    // MARK: にがす

    private var releaseSection: some View {
        Section {
            Button(role: .destructive) {
                showReleaseAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("にがす")
                    Spacer()
                }
            }
        }
    }

    // MARK: 覚えている技

    private var movesSection: some View {
        Section("覚えている技") {
            if pokemon.moveIDs.isEmpty {
                Text("—").foregroundStyle(.secondary)
            } else {
                ForEach(pokemon.moveIDs, id: \.self) { id in
                    if let move = master.move(id: id) {
                        MoveRow(move: move)
                    } else {
                        Text(id).foregroundStyle(.secondary)
                    }
                }
            }
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
            Spacer()
            TypeBadge(typeID: move.type)
        }
    }
}
