# RunJourney

マラソン大会の記録を地図上に可視化し、ルートをアニメーション再生・動画書き出しできる **iOS / iPadOS / macOS ネイティブアプリ**。

[`marathon-record-app`](../marathon-record-app)（React + Mapbox + Supabase の Webアプリ）の純正アプリ版。

リポジトリ: https://github.com/kn-nakamura/run-journey-ios （private）

## 主な機能

### 取り込み
- **TCX / GPX / FIT / ZIP** の4形式に対応した自前パーサ（外部依存ゼロ）
- ZIP は中の `.fit` を自動展開
- 取り込み確認シートで「新しい大会として作成」「既存の大会に結果を追加」を選択可能
- 開始地点が近い既存大会は自動で「近場」として優先表示

### 地図
- **MapKit** でカテゴリ別カラーピン表示（5K/10K/Half/Full/Trail/Ultra）
- ピンタップで結果一覧を表示
- 標準 / ハイブリッド / 航空写真の地図スタイル切替
- 「全レースを表示」「ルートにフィット」ボタンで自動ズーム

### 結果詳細
- **Bebas Neue** で大きく表示するヒーロータイム（蛍光イエロー）
- 統計グリッド (HR・標高・カロリー・ケイデンス・パワー・気温)
- ルートマップ → タップでフライスルー再生へ
- **Swift Charts** で:
  - ラップ別ペース棒グラフ（速いラップ緑/遅いラップ赤）
  - 標高プロファイル（距離 vs 標高、AreaMark）
  - 心拍推移 (時間 vs HR、LineMark)

### 同じ大会の年別比較
- 1つの大会(Race)に複数の結果(RaceResult)を紐付け
- 年別フィニッシュタイム棒グラフ（PB黄色強調）
- ラップペース重ね合わせ折れ線

### ルートフライスルー
- カメラ追従モード（pitch=60°、look-aheadで進行方向を向く）
- 全体俯瞰モード
- 走破済み区間をカテゴリ色で太く描画
- 1〜256倍速の9プリセット
- HUD: 経過時間・距離・ペース・心拍・標高をリアルタイム

### 録画 & 書き出し
- **ReplayKit** で画面録画 → Photos へ保存 or 共有
- iOSのみ対応（iOS実機推奨、シミュレータでは動作不可な場合あり）

### ダッシュボード
- 完走数・総距離・総時間・平均ペースのサマリーカード
- カテゴリ別 PB ボード
- 年別レース数の棒グラフ
- カテゴリ別レース数のドーナツチャート

### ペース計算
- 距離プリセット (5K/10K/Half/Full/Custom) + 目標タイム入力
- 平均ペース + 1km毎のスプリット表
- プラン保存（SwiftData 永続化）

### 設定
- 登録データの件数表示
- データ削除（結果のみ / 大会と結果 / プランのみ / すべて）
- iCloud 同期ステータス（MVPはローカル）
- アプリ情報・GitHub リンク

## 技術スタック

| 領域 | 採用 |
|---|---|
| UI | SwiftUI（iPhone/iPad/Macマルチプラットフォーム1ターゲット） |
| 最低OS | iOS 26.4 / iPadOS 26.4 / macOS 26.4 |
| データ | SwiftData (CloudKit対応設計、現状ローカル) |
| 地図 | MapKit (Map, MapPolyline, MapCamera) |
| チャート | Swift Charts (BarMark / LineMark / AreaMark / SectorMark) |
| GPX/TCX | 標準 XMLParser |
| FIT | 自前バイナリパーサ (Definition+Data Messages, LE/BE 両対応) |
| ZIP | Foundation Compression + central-directory ベースの自前パーサ |
| 画面録画 | ReplayKit (RPScreenRecorder) |
| フォント | Bebas Neue / DM Sans / JetBrains Mono (Resources/Fonts/) |

## ビルド

```bash
# iOS Simulator
xcodebuild -project RunJourney.xcodeproj -scheme RunJourney \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# macOS native
xcodebuild -project RunJourney.xcodeproj -scheme RunJourney \
  -destination 'generic/platform=macOS' build
```

または Xcode で `RunJourney.xcodeproj` を開いて Cmd+R。

## ディレクトリ

```
RunJourney/
├── RunJourneyApp.swift              # @main + ModelContainer
├── ContentView.swift                # 4タブ Root (iPhone) / Sidebar (iPad/Mac)
├── Models/                          # SwiftData @Model + enum
│   ├── Race.swift
│   ├── RaceResult.swift
│   ├── PacePlan.swift
│   ├── LapData.swift
│   ├── TrackPoint.swift
│   ├── SummaryStats.swift
│   ├── RaceCategory.swift
│   ├── WeatherDescription.swift
│   ├── Condition.swift
│   └── LapTrigger.swift
├── Services/
│   └── PBCalculator.swift           # PB/SB/年別/カテゴリ別集計
├── Theme/
│   ├── Color+RunJourney.swift       # Tailwind 400 + 蛍光イエロー
│   └── Font+RunJourney.swift        # Bebas/DMSans/JetBrainsMono helpers
├── Resources/
│   └── Fonts/                       # 6 TTF files (約800KB)
├── Features/
│   ├── Map/                         # RaceMapView + Annotation
│   ├── Import/                      # GPX/TCX/FIT/ZIP parsers + UI
│   ├── Detail/                      # RaceDetailView + RaceResultDetailView + Charts
│   ├── Playback/                    # RouteFlythruView + Controls + HUD
│   ├── Export/                      # ReplayKit wrapper
│   ├── Dashboard/                   # PB Board + Year/Category charts
│   ├── Pace/                        # PaceCalculatorView
│   └── Settings/                    # SettingsView
├── Info.plist
└── RunJourney.entitlements          # iCloud / CloudKit / Background
```

## 既知の制約

- **CloudKit 同期はオフ**: Personal Team では Container Dashboard 使用不可。
  Apple Developer Program 加入時に `ModelConfiguration(cloudKitDatabase: .private)` へ切替で有効化。
- **画面録画は iOS 実機推奨**: シミュレータでは `RPScreenRecorder.isAvailable == false` のことが多い。
- **フライスルーのカメラ追従**: 高速時にランナーが画面から見切れることがある（Phase 5 polish 予定）。

## ライセンス

Private project — 個人開発。
