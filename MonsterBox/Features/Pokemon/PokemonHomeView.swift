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
    @State private var showEditor = false
    @State private var showFullAlert = false
    @Query private var allPokemon: [OwnedPokemon]

    private var isFull: Bool {
        allPokemon.count >= AppSeed.boxCount * AppSeed.boxCapacity
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PokemonDetailPanel(pokemon: selected)
                    .padding(.horizontal)
                BoxView(selected: $selected)
            }
            .navigationTitle("MonsterBox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isFull {
                            showFullAlert = true
                        } else {
                            showEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                NavigationStack {
                    PokemonEditorView(mode: .create)
                }
            }
            .alert("ボックスが満杯です", isPresented: $showFullAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("登録できる上限 (\(AppSeed.boxCount * AppSeed.boxCapacity) 体) に達しています。不要な個体を削除してから追加してください")
            }
            .onChange(of: allPokemon) { _, newValue in
                if let s = selected,
                   !newValue.contains(where: { $0.persistentModelID == s.persistentModelID }) {
                    selected = nil
                }
            }
        }
    }

}

#Preview {
    PokemonHomeView()
}
