//
//  BoxView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// 14箱・6×5・左右切替のボックス画面。
// タップ→メニュー (移動/強さを見る/編集する)。移動中は持ち替え式。
struct BoxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPokemon: [OwnedPokemon]
    @Query(sort: \BoxInfo.boxNumber) private var boxes: [BoxInfo]

    @State private var currentBox: Int = 1
    @State private var selected: OwnedPokemon?
    @State private var showActionMenu = false
    @State private var detailTarget: OwnedPokemon?
    @State private var editTarget: OwnedPokemon?
    @State private var renameText: String = ""
    @State private var showRename = false

    @State private var move = BoxMoveModel()

    private var pokemonInCurrentBox: [OwnedPokemon] {
        allPokemon.filter { $0.boxNumber == currentBox }
    }

    private var currentBoxInfo: BoxInfo? {
        boxes.first { $0.boxNumber == currentBox }
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
                VStack(spacing: 8) {
                    header
                    grid
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if move.isMoving {
                movingFooter
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: move.isMoving)
        .confirmationDialog(
            selected?.displayName ?? "",
            isPresented: $showActionMenu,
            titleVisibility: .visible
        ) {
            Button("移動") { startMoveSelected() }
            Button("強さを見る") { detailTarget = selected }
            Button("編集する") { editTarget = selected }
            Button("キャンセル", role: .cancel) { selected = nil }
        }
        .sheet(item: $detailTarget) { p in
            NavigationStack { PokemonDetailView(pokemon: p) }
        }
        .sheet(item: $editTarget) { p in
            NavigationStack { PokemonEditorView(mode: .edit(p)) }
        }
        .alert("ボックス名を変更", isPresented: $showRename) {
            TextField("名前", text: $renameText)
            Button("保存") { saveRename() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: ヘッダ (名前 + 左右ボタン)

    private var header: some View {
        HStack {
            Button { gotoPrev() } label: {
                Image(systemName: "chevron.left").font(.title2)
            }
            Spacer()
            Button {
                renameText = currentBoxInfo?.name ?? "ボックス\(currentBox)"
                showRename = true
            } label: {
                VStack(spacing: 2) {
                    Text(currentBoxInfo?.name ?? "ボックス\(currentBox)")
                        .font(.headline)
                    Text("\(currentBox) / \(AppSeed.boxCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { gotoNext() } label: {
                Image(systemName: "chevron.right").font(.title2)
            }
        }
        .padding(.top, 8)
    }

    // MARK: 6×5 グリッド

    private var grid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(0..<AppSeed.boxCapacity, id: \.self) { slot in
                cell(at: slot)
            }
        }
    }

    private func cell(at slot: Int) -> some View {
        let occupant = pokemonInCurrentBox.first { $0.slot == slot }
        let isSelected = (selected?.persistentModelID == occupant?.persistentModelID) && occupant != nil
        return BoxCell(
            pokemon: occupant,
            isSelected: isSelected,
            isMoveTarget: move.isMoving
        )
        .contentShape(Rectangle())
        .onTapGesture { handleTap(slot: slot, occupant: occupant) }
    }

    // MARK: 移動中フッタ (safeAreaInset でグリッドの上に重ねない位置に表示)

    @ViewBuilder
    private var movingFooter: some View {
        if let held = move.held {
            HStack(spacing: 12) {
                SpriteImage(dex: held.speciesDex, typeIDs: held.typeIDs)
                    .frame(width: 36, height: 36)
                Text("\(held.displayName) を持っています")
                    .font(.footnote)
                Spacer()
                Button("キャンセル") { move.cancel() }
            }
            .padding(8)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: タップ処理

    private func handleTap(slot: Int, occupant: OwnedPokemon?) {
        if move.isMoving {
            move.place(box: currentBox, slot: slot, occupant: occupant)
            try? modelContext.save()
            return
        }
        guard let occupant else { return }
        selected = occupant
        showActionMenu = true
    }

    private func startMoveSelected() {
        guard let p = selected else { return }
        move.beginMove(p)
        try? modelContext.save()
        selected = nil
    }

    // MARK: ボックス切替 (循環)

    private func gotoPrev() {
        currentBox = currentBox == 1 ? AppSeed.boxCount : currentBox - 1
    }

    private func gotoNext() {
        currentBox = currentBox == AppSeed.boxCount ? 1 : currentBox + 1
    }

    // MARK: ボックス名変更

    private func saveRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let info = currentBoxInfo else { return }
        info.name = name
        try? modelContext.save()
    }
}
