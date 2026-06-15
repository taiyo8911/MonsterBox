//
//  PokemonHomeView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// ホーム: 一覧⇄ボックス の切替ビュー。
// ツールバーに「+」で新規登録 (PokemonEditorView .create) を開く。
struct PokemonHomeView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case list, box
        var id: String { rawValue }
        var label: String {
            switch self {
            case .list: return "一覧"
            case .box: return "ボックス"
            }
        }
    }

    @State private var tab: Tab = .list
    @State private var showEditor = false
    @State private var showFullAlert = false
    @Query private var allPokemon: [OwnedPokemon]

    private var isFull: Bool {
        allPokemon.count >= AppSeed.boxCount * AppSeed.boxCapacity
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .list: PokemonListView()
                case .box: BoxView()
                }
            }
            .navigationTitle("MonsterBox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
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
                Text("登録できる上限 (\(AppSeed.boxCount * AppSeed.boxCapacity) 体) に達しています。不要な個体を削除してから追加してください。")
            }
        }
    }
}
