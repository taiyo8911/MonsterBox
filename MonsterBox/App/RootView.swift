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
    /// 一部失敗でも「このまま進む」をユーザーが選んだ場合 true。
    @State private var userProceeded = false

    /// ゲートを抜けて Home を表示してよいか。
    private var shouldShowHome: Bool {
        guard prefetcher.isFinished else { return false }
        return prefetcher.success == prefetcher.total || userProceeded
    }

    var body: some View {
        Group {
            if shouldShowHome {
                PokemonHomeView()
            } else {
                PrefetchGateView(prefetcher: prefetcher, onProceed: { userProceeded = true })
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
    let onProceed: () -> Void

    private var failedCount: Int {
        max(prefetcher.total - prefetcher.success, 0)
    }

    private var hasFailures: Bool {
        prefetcher.isFinished && failedCount > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(hasFailures ? "一部の取得に失敗しました" : "初期データを準備中…")
                .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 240)
            Text("\(prefetcher.completed) / \(max(prefetcher.total, 1))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if hasFailures {
                Text("\(failedCount) 件取得できませんでした。\nそのまま進んでも問題はありません")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                HStack(spacing: 12) {
                    Button("データを再取得する") {
                        Task { await prefetcher.retry() }
                    }
                    .buttonStyle(.bordered)
                    Button("このまま進む") { onProceed() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
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
