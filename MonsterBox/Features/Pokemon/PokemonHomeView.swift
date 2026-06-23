//
//  PokemonHomeView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// ホーム: 上段=選択中ポケモンの詳細パネル / 下段=ボックス。
// 下段でタップ→上段に表示、長押し→アクションメニュー。
// ツールバー「+」で新規登録 (PokemonEditorView .create) を開く。
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

#Preview {
    PokemonHomeView()
}
