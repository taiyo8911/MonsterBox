# 仕様書: FRLG わざ・ポケモン管理アプリ（仮）

ver 1.5 / Phase 1 完成版

> 開発方針: 初版はポケモン管理に絞り、**登録・一覧・ボックス・個体詳細**を作る。タイプ別グラフは次アップデート、技マシン／教え技はPhase 2。

---

## 0. 決定事項サマリ

| 項目 | 決定 |
| --- | --- |
| プロダクト名（内部） | MonsterBox（中立名・ASCII）。表示名は別途設定し商標を避ける |
| セーブ管理 | 単一セーブのみ |
| 対象種族 | 第1〜2世代（1〜251）＋ デオキシス（386）。ホウエン除外 |
| 技の入力候補 | 種族の覚える技（学習セット）に限定 |
| 技名の表示 | 日本語（内部は安定IDで参照） |
| 能力の範囲 | 能力値6つのみ |
| ボックス | 14箱・固定／箱名は編集可／各30マス（6×5） |
| ボックス操作 | タップ選択→メニュー（移動／強さを見る／編集する） |
| 移動の挙動 | 「持ち替え」式（占有マスに置くと元の子を持ち上げ、空きマスに置くまで継続）|
| ボックス切替 | 左右ボタンのみ／端は循環（14→1） |
| 一覧ソートキー | 図鑑番号・レベル・名前・タイプ・性格 |
| 表示（画像） | 第3世代ドット絵（FRLG＝カントー＋デオキシス、エメラルド＝ジョウト）＋タイプ色フォールバック |
| 動作 | 初回起動時に全スプライトを取得・キャッシュ → 以降はオフライン（マスタJSONは同梱） |
| タイプ別グラフ | 棒グラフ／2タイプ各+1（※次アップデート） |
| マスタデータ | `frlg_master.json` を同梱（第3世代相当に補正済み） |

---

## 1. 概要・目的

Switch版『ポケットモンスター ファイアレッド・リーフグリーン』（第3世代仕様）のプレイを補助する、iOS向けの記録＆計画アプリ。最終的には在庫×覚える技×手持ちを突き合わせた育成計画まで支援するが、初版は **ポケモン管理** に絞る。

---

## 2. 開発フェーズ

| フェーズ | 内容 |
| --- | --- |
| **Phase 1（初版）** | 登録フォーム／一覧表示／ボックス表示（操作含む）／個体詳細 |
| 次アップデート | タイプ別グラフ |
| Phase 2 以降 | 技マシン管理／教え技管理／技からの逆引き（育成計画） |

---

## 3. 前提・対象

- 対応ソフト: Switch版FRLG（第3世代仕様。フェアリー無し、物理／特殊はタイプ依存）
- 対象ユーザー: 個人利用前提・単一セーブを管理
- プラットフォーム: iOS / SwiftUI
- 永続化: SwiftData（端末内）
- 動作: **初回起動時のみ通信**（全スプライトを先読みしてキャッシュ）。以降はオフライン。マスタJSONは同梱
- プロダクト名: 内部名（Product Name／モジュール名）は **MonsterBox**（中立・ASCII）。App Store表示名は別途設定し、他社商標（ポケモン／FRLG等）は用いない
- 設計方針: 初版は単機能だが、将来のタブ追加（技マシン／教え技）を見据えた構成にしておく

---

## 4. Phase 1 機能

### 4.1 登録フォーム（個体の追加・編集）
- 全項目を入力: ニックネーム／ポケモン名（種族）／性別／レベル／能力値6／性格／技（最大4）
- **種族を選ぶと、技候補がその種族の学習セットに限定される**（`MasterData.learnableMoves(forDex:)`）
- ボックス番号・スロットを割り当てて保存

### 4.2 一覧表示
- ソート可能: 図鑑番号 / レベル / 名前 / タイプ / 性格
- 行タップで個体詳細（4.4）へ
- 一覧とボックスは同じ所持データの表示切替（ホーム上で切替）

### 4.3 ボックス表示
- **レイアウト**: 1ボックス＝6列×5行＝30マス。スロット 0〜29 ↔ マス（row = slot / 6, col = slot % 6）
- **ヘッダ**: 現在のボックス名（タップで編集可）＋ 左右ボタン `‹` `›`
- **ボックス切替**: 左右ボタンのみ。14箱を循環（14箱目→1箱目）
- **表示**: 各マスに第3世代スプライト（初回キャッシュ済み）。無い場合はタイプ色タイル
- **個体の操作（タップ式）**:
  1. ポケモンをタップ → 選択状態
  2. メニュー表示（**移動 / 強さを見る / 編集する**）
     - **移動**: そのポケモンを「手に持った」状態になり、元マスは空く。空きマスをタップで置く。占有マスをタップすると、そこへ置きつつ元の子を持ち上げる（**持ち替え**）。空きマスに置くまで継続。移動モード中に左右ボタンで別ボックスへ移れば**箱間移動**も可。手放す前のキャンセルで元に戻せる
     - **強さを見る**: 個体詳細（4.4）
     - **編集する**: 登録フォーム（編集）
- **データ更新**: 移動は `OwnedPokemon.boxNumber` / `slot` の書き換えのみ

### 4.4 個体詳細（強さを見る）
- 種族・タイプ・レベル・能力値6・性格・覚えている技（日本語名）を表示
- 編集フォームへの導線

### 画面構成
- 初回起動: スプライト先読み（進捗表示）→ 完了後にホームへ
- 一覧／ボックス 切替ビュー（ホーム）／ 個体詳細 ／ 追加・編集フォーム

---

## 5. データモデル（SwiftData・実装済み）

マスタ（同梱・読み取り専用）とユーザーデータ（編集可）を分離。実装は `FRLGMasterData.swift` / `UserModels.swift`。

### マスタ（`frlg_master.json` を読み込み）
- **TypeEntry**: id / nameJa / nameEn
- **Species**: dex / nameJa / nameEn / types[] / learnset[]（move・methods・level）
- **Move**: id / nameJa / nameEn / type / category（physical・special・status）/ power / accuracy / pp

### ユーザーデータ（編集可）
- **OwnedPokemon**: speciesDex / nickname / gender / level / 能力値6 / nature / moveIDs[最大4] / boxNumber（1〜14）/ slot（0〜29）/ isShiny・memo（任意）/ createdAt
- **BoxInfo**: boxNumber（1〜14・unique）/ name（編集可）
- 初回起動で14箱を生成（`AppSeed.seedBoxesIfNeeded`）

> 技名は技IDで保持し、表示時に `MasterData.moveNameJa(_:)` で日本語名へ変換。

---

## 6. アセット

### マスタデータ `frlg_master.json`（同梱）
PokeAPI由来、第3世代相当に補正済み。

| ブロック | 件数 |
| --- | --- |
| types | 17（フェアリー無し） |
| species | 252（1〜251＋デオキシス386） |
| moves | 336 |

- 学習セットはFRLG優先、未収録種族のみ emerald / ruby-sapphire で補完
- タイプ・技は過去データで第3世代へ巻き戻し。物理／特殊はタイプ判定
- デオキシスはフォルム非分割（基本＝エスパー単タイプ）

### スプライト（初回取得・キャッシュ）
- 取得元: 第3世代ドット絵（FRLG＝カントー＋デオキシス、エメラルド＝ジョウト）
- **初回起動時に全252体を取得**し、Application Support にキャッシュ（OSに消されにくい・バックアップ対象外）。以降はオフライン表示
- 一部取得失敗時もアプリは起動し、不足分はタイプ色タイルで表示（次回起動で再取得）
- 実装: `SpritePrefetcher`（先読み・進捗）／`SpriteImage(dex:typeIDs:)`（表示）

---

## 7. 将来アップデート（メモ）

- 次アップデート: **タイプ別グラフ**（棒グラフ／2タイプ各+1）
- Phase 2: 技マシン管理（所持数・逆引き）／教え技管理（使用済み・未使用・逆引き）／技からの逆引き／個体詳細に「覚えられる技＋在庫」表示
- 下部タブを3構成へ拡張。追加マスタ: TMMaster / TutorMaster / TMInventory / TutorUsage
- 必要に応じてデオキシスのフォルム対応、対象種族の拡張

---

## 8. 要検討事項・注意

- Phase 1 の仕様判断はすべて確定。
- **権利上の注意**: ポケモンの名前・データ・スプライトは任天堂／ゲームフリーク／ポケモン社の知的財産。非公式アプリとしてApp Store公開する場合の権利・審査リスクは残るため、最終的な可否は専門家への確認を推奨（本仕様は実装範囲の合意を示すもので、権利上の保証ではない）。
- Phase 2 持ち越し: TM在庫の個数管理か所持フラグか／HOME連携／教え技の場所・NPC情報。

---

## 9. プロジェクト構成（Xcode）

3層構成。**App（起動・組み立て）／ Core（土台・共有）／ Features（機能＝タブ単位）**。新しいタブは Features にフォルダを足すだけで増やせる。

- **MonsterBox/**（プロジェクトルート）
  - `MonsterBox.xcodeproj` — 自動生成（さわらない）
  - **MonsterBox/**（ソース）
    - **App/** — 起動・組み立て
      - `MonsterBoxApp.swift` — 自動生成を編集。@main、ModelContainer(OwnedPokemon, BoxInfo)
      - `RootView.swift` — 自動生成 ContentView.swift をリネーム。初回先読みゲート → TabView（将来3タブ）
    - **Core/** — 全機能で使う土台・共有
      - **Models/**
        - `UserModels.swift` — OwnedPokemon / BoxInfo / Gender / Nature / AppSeed
      - **Master/**
        - `FRLGMasterData.swift` — Codable ＋ MasterData(ローダ)
        - `frlg_master.json` — ターゲット(Bundle)に追加
      - **Sprites/**
        - `PokemonSprite.swift` — SpritePrefetcher / SpriteImage / TypeColor
    - **Features/** — 機能＝タブ単位
      - **Pokemon/** ← Phase 1
        - `PokemonHomeView.swift` — 一覧⇄ボックス 切替
        - `PokemonListView.swift` — 一覧＋ソート
        - `BoxView.swift` — 14箱・6×5・左右切替
        - `BoxCell.swift` — 1マス（SpriteImage）
        - `BoxMoveModel.swift` — 持ち替え移動の状態（@Observable）
        - `PokemonDetailView.swift` — 強さを見る
        - `PokemonEditorView.swift` — 追加／編集フォーム
      - **Machines/** ← Phase 2 技マシン（今は空）
      - **Tutors/** ← Phase 2 教え技（今は空）
    - **Resources/**
      - `Assets.xcassets` — アプリアイコン等
      - `Preview Content/` — 自動生成（プレビュー用）

設計メモ:
- ViewModelは基本不要。SwiftDataの `@Query` と `@Environment(\.modelContext)` でViewから直接読み書きする。
- 例外は移動の一時状態（手に持っている個体・移動モード）で、`BoxMoveModel`（@Observable）に持たせる。
- 自動生成の `MonsterBoxApp.swift` は編集、`ContentView.swift` は `RootView.swift` にリネームして転用する。

---

## 付録: 関連ファイル
- `frlg_master.json` … 同梱マスタ（types / species / moves）
- `build_frlg_master.py` … マスタ生成スクリプト
- `FRLGMasterData.swift` … マスタ読み込み（Codable＋ローダ）
- `UserModels.swift` … SwiftData モデル（OwnedPokemon / BoxInfo）＋初期投入
- `PokemonSprite.swift` … スプライト（初回先読み＋キャッシュ・表示）＋タイプ色
