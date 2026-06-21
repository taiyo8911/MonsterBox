//
//  PokemonEditorView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

// 個体の追加・編集フォーム。
// 種族を選ぶと、技候補がその種族の学習セットに限定される。
// 追加時は空きスロットを自動割り当てして保存。
struct PokemonEditorView: View {
    enum Mode {
        case create
        case edit(OwnedPokemon)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // フォーム状態
    @State private var speciesDex: Int = 1
    @State private var nickname: String = ""
    @State private var gender: Gender = .genderless
    @State private var level: Int = 0
    @State private var hp: Int = 0
    @State private var attack: Int = 0
    @State private var defense: Int = 0
    @State private var spAttack: Int = 0
    @State private var spDefense: Int = 0
    @State private var speed: Int = 0
    @State private var nature: Nature = .hardy
    @State private var heldItem: String = ""
    @State private var moveIDs: [String] = []
    @State private var memo: String = ""

    @State private var showSpeciesPicker = false
    @State private var didLoad = false

    private let master = MasterData.shared

    private var isEdit: Bool {
        if case .edit = mode { return true } else { return false }
    }

    private var species: Species? { master.species(dex: speciesDex) }
    private var learnable: [Move] { master.learnableMoves(forDex: speciesDex) }

    var body: some View {
        Form {
            speciesSection
            profileSection
            statusSection
            movesSection
            memoSection
        }
        .navigationTitle(isEdit ? "編集する" : "新規登録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { save() }
                    .disabled(species == nil)
            }
        }
        .onAppear { loadIfNeeded() }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPickerView(selectedDex: $speciesDex)
        }
    }

    // MARK: - セクション

    private var speciesSection: some View {
        Section("種族") {
            Button {
                showSpeciesPicker = true
            } label: {
                HStack(spacing: 12) {
                    SpriteImage(dex: speciesDex, typeIDs: species?.types ?? [])
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading) {
                        Text(species?.nameJa ?? "—")
                            .foregroundStyle(.primary)
                        Text("No.\(speciesDex)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var profileSection: some View {
        Section("プロフィール") {
            TextField("ニックネーム", text: $nickname)
            Picker("性別", selection: $gender) {
                ForEach(Gender.allCases) { Text($0.nameJa).tag($0) }
            }
            Picker("性格", selection: $nature) {
                ForEach(Nature.allCases) { Text($0.nameJa).tag($0) }
            }
            TextField("持ち物", text: $heldItem)
        }
    }

    private var statusSection: some View {
        Section("能力") {
            HStack {
                Text("レベル")
                Spacer()
                TextField("1", text: Binding(
                    get: { level == 0 ? "" : String(level) },
                    set: {
                        let n = Int($0) ?? 0
                        level = min(100, n)
                    }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 6))
                .padding(.trailing, 4)
            }
            statRow("HP", value: $hp)
            statRow("こうげき", value: $attack)
            statRow("ぼうぎょ", value: $defense)
            statRow("とくこう", value: $spAttack)
            statRow("とくぼう", value: $spDefense)
            statRow("すばやさ", value: $speed)
        }
    }

    private func statRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: Binding(
                get: { value.wrappedValue == 0 ? "" : String(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) ?? 0 }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 6))
            .padding(.trailing, 4)
        }
    }

    private var movesSection: some View {
        Section {
            if learnable.isEmpty {
                Text("この種族の技候補がありません").foregroundStyle(.secondary)
            } else {
                ForEach(learnable) { move in
                    moveToggleRow(move)
                }
            }
        } header: {
            HStack {
                Text("覚えている技")
                Spacer()
                Text("\(moveIDs.count) / 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("最大4つまで選択できます。")
        }
    }

    private func moveToggleRow(_ move: Move) -> some View {
        let selected = moveIDs.contains(move.id)
        let disabled = !selected && moveIDs.count >= 4
        return Button {
            toggleMove(move.id)
        } label: {
            HStack {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(move.nameJa)
                    .foregroundStyle(.primary)
                Spacer()
                TypeBadge(typeID: move.type)
            }
        }
        .disabled(disabled)
    }

    private var memoSection: some View {
        Section("メモ") {
            TextField("自由記入", text: $memo, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    // MARK: - ロード / 保存

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case .edit(let p) = mode {
            speciesDex = p.speciesDex
            nickname = p.nickname
            gender = p.gender
            level = p.level
            hp = p.hp
            attack = p.attack
            defense = p.defense
            spAttack = p.spAttack
            spDefense = p.spDefense
            speed = p.speed
            nature = p.nature
            heldItem = p.heldItem
            moveIDs = p.moveIDs
            memo = p.memo
        }
    }

    private func toggleMove(_ id: String) {
        if let idx = moveIDs.firstIndex(of: id) {
            moveIDs.remove(at: idx)
        } else if moveIDs.count < 4 {
            moveIDs.append(id)
        }
    }

    private func save() {
        // 種族変更で互換性のない技は除外
        let validIDs = Set(learnable.map { $0.id })
        let filteredMoves = moveIDs.filter { validIDs.contains($0) }
        // レベルは編集中の空入力で 0 になり得るため、保存時に下限補正
        let safeLevel = max(1, level)

        switch mode {
        case .create:
            guard let (box, slot) = findFreeSlot() else { return }
            let new = OwnedPokemon(
                speciesDex: speciesDex,
                nickname: nickname,
                gender: gender,
                level: safeLevel,
                hp: hp, attack: attack, defense: defense,
                spAttack: spAttack, spDefense: spDefense, speed: speed,
                nature: nature,
                heldItem: heldItem,
                moveIDs: filteredMoves,
                boxNumber: box,
                slot: slot,
                isShiny: false,
                memo: memo
            )
            modelContext.insert(new)
        case .edit(let p):
            p.speciesDex = speciesDex
            p.nickname = nickname
            p.gender = gender
            p.level = safeLevel
            p.hp = hp; p.attack = attack; p.defense = defense
            p.spAttack = spAttack; p.spDefense = spDefense; p.speed = speed
            p.nature = nature
            p.heldItem = heldItem
            p.moveIDs = filteredMoves
            p.memo = memo
        }
        try? modelContext.save()
        dismiss()
    }

    /// 全ボックスを走査して最初の空きマスを返す。満杯なら nil。
    private func findFreeSlot() -> (box: Int, slot: Int)? {
        let descriptor = FetchDescriptor<OwnedPokemon>()
        let owned = (try? modelContext.fetch(descriptor)) ?? []
        var occupied: Set<Int> = []  // key = box * 100 + slot
        for o in owned { occupied.insert(o.boxNumber * 100 + o.slot) }
        for box in 1...AppSeed.boxCount {
            for slot in 0..<AppSeed.boxCapacity {
                if !occupied.contains(box * 100 + slot) { return (box, slot) }
            }
        }
        return nil
    }
}

// MARK: - 種族ピッカー (図鑑番号順)

struct SpeciesPickerView: View {
    @Binding var selectedDex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var species: [Species] {
        let all = MasterData.shared.species
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.nameJa.localizedStandardContains(q) ||
            $0.nameEn.localizedCaseInsensitiveContains(q) ||
            String($0.dex).contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(species) { s in
                Button {
                    selectedDex = s.dex
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        SpriteImage(dex: s.dex, typeIDs: s.types)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(s.nameJa).foregroundStyle(.primary)
                            Text("No.\(s.dex)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(s.types, id: \.self) { TypeBadge(typeID: $0) }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "図鑑番号 / 名前")
            .navigationTitle("種族を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}


#Preview {
    NavigationStack {
        PokemonEditorView(mode: .create)
    }
    .modelContainer(for: [OwnedPokemon.self], inMemory: true)
}
