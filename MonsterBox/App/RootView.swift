//
//  RootView.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var prefetcher = SpritePrefetcher()

    var body: some View {
        Group {
            if prefetcher.isFinished {
                PokemonHomeView()
            } else {
                PrefetchGateView(prefetcher: prefetcher)
            }
        }
        .task {
            AppSeed.seedBoxesIfNeeded(modelContext)
            await prefetcher.prefetchAllIfNeeded()
        }
    }
}

// MARK: - 初回スプライト先読み画面

private struct PrefetchGateView: View {
    @ObservedObject var prefetcher: SpritePrefetcher

    var body: some View {
        VStack(spacing: 16) {
            Text("スプライトを準備中…")
                .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 240)
            Text("\(prefetcher.completed) / \(max(prefetcher.total, 1))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var progress: Double {
        guard prefetcher.total > 0 else { return 0 }
        return Double(prefetcher.completed) / Double(prefetcher.total)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [OwnedPokemon.self, BoxInfo.self], inMemory: true)
}
