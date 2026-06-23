//
//  PokemonHomeView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// ホーム: 上段=選択中ポケモンの詳細パネル / 下段=ボックス
// 下段でタップ→上段に表示、長押し→アクションメニュー
// ツールバー「+」で新規登録 (PokemonEditorView .create) を開く
struct PokemonHomeView: View {
    @State private var selected: OwnedPokemon?
    @State private var emptyTarget: EmptySlot?
    @State private var showEditor = false
    @Query private var allPokemon: [OwnedPokemon]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PokemonDetailPanel(pokemon: selected)
                    .padding(.horizontal)
                BoxView(selected: $selected, emptyTarget: $emptyTarget)
            }
            .navigationTitle("MonsterBox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(emptyTarget == nil)
                }
            }
            .sheet(isPresented: $showEditor) {
                NavigationStack {
                    PokemonEditorView(
                        mode: .create,
                        targetSlot: emptyTarget.map { (box: $0.box, slot: $0.slot) }
                    )
                }
            }
            .onChange(of: allPokemon) { _, newValue in
                if let s = selected,
                   !newValue.contains(where: { $0.persistentModelID == s.persistentModelID }) {
                    selected = nil
                }
                // 指定した空マスにポケモンが入ったら座標を解除
                if let t = emptyTarget,
                   newValue.contains(where: { $0.boxNumber == t.box && $0.slot == t.slot }) {
                    emptyTarget = nil
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ダミーデータ入り") {
    let container = try! ModelContainer(
        for: OwnedPokemon.self, BoxInfo.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext

    // 14個のボックスをシード
    for n in 1...AppSeed.boxCount {
        ctx.insert(BoxInfo(boxNumber: n, name: "ボックス\(n)"))
    }

    // Box1 に複数体のサンプルを配置
    ctx.insert(OwnedPokemon(
        speciesDex: 4, nickname: "", gender: .male, level: 16,
        hp: 22, attack: 14, defense: 12, spAttack: 16, spDefense: 13, speed: 18,
        nature: .modest, abilityID: "blaze",
        moveIDs: ["ember", "scratch", "growl", "smokescreen"],
        boxNumber: 1, slot: 0
    ))
    ctx.insert(OwnedPokemon(
        speciesDex: 1, nickname: "ふっしー", gender: .female, level: 12,
        hp: 19, attack: 11, defense: 12, spAttack: 14, spDefense: 14, speed: 10,
        nature: .calm, abilityID: "overgrow",
        moveIDs: ["tackle", "vine-whip", "growl"],
        boxNumber: 1, slot: 1
    ))
    ctx.insert(OwnedPokemon(
        speciesDex: 7, nickname: "", gender: .male, level: 14,
        hp: 21, attack: 12, defense: 16, spAttack: 12, spDefense: 14, speed: 11,
        nature: .bold, abilityID: "torrent",
        moveIDs: ["tackle", "tail-whip", "water-gun", "withdraw"],
        boxNumber: 1, slot: 2
    ))
    ctx.insert(OwnedPokemon(
        speciesDex: 25, nickname: "ピカ", gender: .male, level: 20,
        hp: 28, attack: 18, defense: 12, spAttack: 20, spDefense: 14, speed: 30,
        nature: .jolly, abilityID: "static",
        moveIDs: ["thunder-shock", "quick-attack", "tail-whip", "growl"],
        boxNumber: 1, slot: 5
    ))
    ctx.insert(OwnedPokemon(
        speciesDex: 133, nickname: "", gender: .female, level: 18,
        hp: 30, attack: 16, defense: 14, spAttack: 12, spDefense: 14, speed: 18,
        nature: .hardy, abilityID: "run-away",
        moveIDs: ["tackle", "tail-whip"],
        boxNumber: 1, slot: 8
    ))

    return PokemonHomeView()
        .modelContainer(container)
}

#Preview("空っぽ") {
    let container = try! ModelContainer(
        for: OwnedPokemon.self, BoxInfo.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for n in 1...AppSeed.boxCount {
        container.mainContext.insert(BoxInfo(boxNumber: n, name: "ボックス\(n)"))
    }
    return PokemonHomeView()
        .modelContainer(container)
}
