//
//  MonsterBoxApp.swift
//  MonsterBox
//
//  Created by Taiyo KOSHIBA on 2026/06/15.
//

import SwiftUI
import SwiftData

@main
struct MonsterBoxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [OwnedPokemon.self, BoxInfo.self])
    }
}
