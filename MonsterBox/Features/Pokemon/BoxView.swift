//
//  BoxView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// 空マスの座標 (box, slot) を扱う値型。
// Binding と .sheet(item:) で使えるよう Identifiable に準拠。
struct EmptySlot: Identifiable, Equatable {
    let box: Int
    let slot: Int
    var id: Int { box * 100 + slot }
}

// 14箱・6×5・左右切替のボックス画面。
// タップ→上段にデータを表示 (Binding で親へ通知)。
// 同一個体を再タップ→アクションメニュー。長押しでもメニュー。
// 空マスタップ→選択解除 + 空マス座標を親に通知 (+ボタン押下時の保存先)。
struct BoxView: View {
    @Binding var selected: OwnedPokemon?
    // 空マスをタップしたときの座標 (新規追加時の保存先)。
    // 空マス以外を選択した・選択解除した場合は nil。
    @Binding var emptyTarget: EmptySlot?

    @Environment(\.modelContext) private var modelContext
    @Query private var allPokemon: [OwnedPokemon]
    @Query(sort: \BoxInfo.boxNumber) private var boxes: [BoxInfo]

    @State private var currentBox: Int = 1
    @State private var actionTarget: OwnedPokemon?
    @State private var editTarget: OwnedPokemon?
    @State private var renameText: String = ""
    @State private var showRename = false
    @State private var releaseTarget: OwnedPokemon?
    @State private var hapticTrigger: Int = 0

    @State private var move = BoxMoveModel()

    private var pokemonInCurrentBox: [OwnedPokemon] {
        allPokemon.filter { $0.boxNumber == currentBox }
    }

    private var currentBoxInfo: BoxInfo? {
        boxes.first { $0.boxNumber == currentBox }
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            grid
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .safeAreaInset(edge: .bottom) {
            if move.isMoving {
                movingFooter
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: move.isMoving)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: hapticTrigger)
        .confirmationDialog(
            actionTarget?.displayName ?? "",
            isPresented: Binding(
                get: { actionTarget != nil },
                set: { if !$0 { actionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("つかむ") { startMoveActionTarget() }
            Button("つよさをかえる") { editTarget = actionTarget }
            Button("にがす", role: .destructive) { releaseTarget = actionTarget }
            Button("キャンセル", role: .cancel) { actionTarget = nil }
        }
        .sheet(item: $editTarget) { p in
            NavigationStack { PokemonEditorView(mode: .edit(p)) }
        }
        .alert("ボックス名を変更", isPresented: $showRename) {
            TextField("名前", text: $renameText)
            Button("保存") { saveRename() }
            Button("キャンセル", role: .cancel) {}
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
    }

    private func release(_ p: OwnedPokemon) {
        modelContext.delete(p)
        try? modelContext.save()
        releaseTarget = nil
        if selected?.persistentModelID == p.persistentModelID {
            selected = nil
        }
        emptyTarget = nil
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
        .contentShape(Rectangle())
        .gesture(swipeBoxGesture)
    }

    // 水平スワイプでボックス切替。移動中・しきい値未満は無視。
    private var swipeBoxGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard !move.isMoving else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if dx < 0 { gotoNext() } else { gotoPrev() }
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
        .onLongPressGesture(minimumDuration: 0.5) { handleLongPress(occupant: occupant) }
    }

    // MARK: 移動中フッタ

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

    // MARK: タップ / 長押し処理

    private func handleTap(slot: Int, occupant: OwnedPokemon?) {
        if move.isMoving {
            move.place(box: currentBox, slot: slot, occupant: occupant)
            try? modelContext.save()
            return
        }
        guard let p = occupant else {
            // 空マス: 上段クリア + 追加保存先として座標を親に通知
            selected = nil
            emptyTarget = EmptySlot(box: currentBox, slot: slot)
            return
        }
        // 同一個体を再タップ: アクションメニュー / 別個体: 選択切替
        if selected?.persistentModelID == p.persistentModelID {
            actionTarget = p
        } else {
            selected = p
        }
        emptyTarget = nil
    }

    private func handleLongPress(occupant: OwnedPokemon?) {
        guard !move.isMoving, let p = occupant else { return }
        hapticTrigger &+= 1
        selected = p
        actionTarget = p
    }

    private func startMoveActionTarget() {
        guard let p = actionTarget else { return }
        move.beginMove(p)
        try? modelContext.save()
        actionTarget = nil
        selected = nil
    }

    // MARK: ボックス切替 (循環)

    private func gotoPrev() {
        currentBox = currentBox == 1 ? AppSeed.boxCount : currentBox - 1
        emptyTarget = nil
    }

    private func gotoNext() {
        currentBox = currentBox == AppSeed.boxCount ? 1 : currentBox + 1
        emptyTarget = nil
    }

    // MARK: ボックス名変更

    private func saveRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let info = currentBoxInfo else { return }
        info.name = name
        try? modelContext.save()
    }
}


#Preview {
    BoxView(selected: .constant(nil), emptyTarget: .constant(nil))
}
