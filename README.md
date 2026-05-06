# RunJourney

マラソン大会の記録を地図上に可視化し、ルートをアニメーション再生・動画書き出しできる **iOS / iPadOS / macOS ネイティブアプリ**。

[`marathon-record-app`](../marathon-record-app)（React + Mapbox + Supabase の Webアプリ）の純正アプリ版。

リポジトリ: https://github.com/kn-nakamura/run-journey-ios （private）

## 主な機能

### 取り込み
- **TCX / GPX / FIT / ZIP** の4形式に対応した自前パーサ（外部依存ゼロ）
- ZIP は中の `.fit` を自動展開
- **Apple Health** からランニングワークアウト (HKWorkout) を直接取り込み可能（ルート / 心拍 / ラップ）
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
- 保存先切替（On This Device / iCloud Sync）
- iCloud Sync 選択時は CloudKit アカウントの状態を表示（Sync Active / Not Signed In / Restricted など）
- アプリ情報・GitHub リンク

## 技術スタック

| 領域 | 採用 |
|---|---|
| UI | SwiftUI（iPhone/iPad/Macマルチプラットフォーム1ターゲット） |
| 最低OS | iOS 26.4 / iPadOS 26.4 / macOS 26.4 |
| データ | SwiftData + CloudKit private DB ミラーリング (オプトイン) |
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

- **画面録画は iOS 実機推奨**: シミュレータでは `RPScreenRecorder.isAvailable == false` のことが多い。
- **フライスルーのカメラ追従**: 高速時にランナーが画面から見切れることがある（Phase 5 polish 予定）。
- **PhotoAsset 添付**: `PHAsset.localIdentifier` はデバイスローカルなので CloudKit 越しに別端末で解決できない。Photos Library から選んだ画像は端末をまたぐ表示はできない（PDF / Photo Picker 画像など `binaryData` を持つ添付は同期される）。

## アプリ内課金 (StoreKit 2)

### 商品構成
| Product ID | 種別 | 用途 |
|---|---|---|
| `runjourney.premium` | Non-Consumable | Premium 機能 (無制限の Race / Result、PDF / 画像添付、ロゴ画像) |
| `runjourney.tip.small` | Consumable | Tip Jar (小) |
| `runjourney.tip.medium` | Consumable | Tip Jar (中) |
| `runjourney.tip.large` | Consumable | Tip Jar (大) |

### 無料プランの上限
- 大会 (Race) 5 件まで
- 結果 (RaceResult) 合計 20 件まで
- 添付はノート / リンクのみ（PDF・画像は Premium）
- 大会ロゴは URL のみ（画像アップロードは Premium）

上限を超えた状態で「+」をタップすると `PaywallSheet` が開き、Premium 一括購入と Tip Jar
の支援動線が表示される。Premium はデバイス間で `AppStore.sync()` 経由で復元できる。

### Apple Developer Portal / App Store Connect 作業
1. App Store Connect で本アプリの「アプリ内課金」セクションに 4 つの Product を登録
   - Product ID は上表どおり。type はそれぞれ Non-Consumable / Consumable
   - 価格と各国向けローカライズ表記 (英/日) は `RunJourney/Resources/StoreKitConfiguration.storekit`
     を参照
2. Sandbox テスト用の Apple ID をデバイスに追加（App Store Connect → Users and Access → Sandbox Testers）
3. 実機で `Settings → App Store → Sandbox Account` を切替して動作確認

### Xcode 上のローカルテスト
バンドルされている `RunJourney/Resources/StoreKitConfiguration.storekit` を Scheme で
有効化すると、Sandbox テスタ無しでも購入動作の検証ができる。

1. Xcode の Scheme editor (`Product → Scheme → Edit Scheme`) を開く
2. `Run → Options` タブ → **StoreKit Configuration** ドロップダウン →
   `StoreKitConfiguration.storekit` を選択
3. 実行すると `PurchaseManager` が同 ファイルから商品を読み込み、Premium 購入や
   Tip Jar 購入をシミュレート可能になる

### コード構造
- `Services/PurchaseManager.swift` — StoreKit 2 を `@Observable` でラップ。`hasPremium` と
  `tipCount` を公開、`Transaction.updates` を購読
- `Services/PremiumLimits.swift` — 無料上限とフィーチャーフラグ
- `Features/Paywall/PaywallSheet.swift` — Premium + Tip Jar の購入シート

## HealthKit

Apple Health に保存されているランニングワークアウト (HKWorkout) を読み込み、既存の
ファイル取り込みと同じパイプライン (`ParsedActivity` → `ActivityImporter`) で
RaceResult として保存できる。

`Services/HealthKitWorkoutFetcher.swift` が以下を取得する:
- HKWorkout 本体（startDate / endDate / duration / totalDistance）
- HKWorkoutRoute（GPS 座標の時系列）
- 心拍 (HKQuantityType .heartRate)
- ラップは workout の `.lap` イベントを優先、無ければ 1km ごとに自動分割

UI 入口は `AddResultSheet` の "Import (Optional)" セクション → "Import from Apple Health"。

### 必要な portal 作業
1. Apple Developer Portal の App ID で **HealthKit** capability を ON
2. 端末側で初回タップ時に権限ダイアログが表示される（`NSHealthShareUsageDescription` を表示）
3. 後から権限を再付与/取り消ししたい場合は iOS Settings → Health → Data Access & Devices → RunJourney

## WeatherKit

レース詳細の Weather セクションでは Apple WeatherKit を最優先、失敗時は
Open-Meteo Archive にフォールバックする (`Services/WeatherFetcher.swift`)。

### 必要な portal 作業
1. Apple Developer Portal の App ID で **WeatherKit** capability を ON
2. 月 50 万コール無料枠以内で運用
3. シミュレータでは entitlement が無いと毎回失敗 → Open-Meteo にフォールバックする想定

実機の場合、entitlement とコードは揃っているので Apple Developer Program に
加入して App ID を更新すれば即座に WeatherKit が優先される。

## iCloud / CloudKit 同期

オンボーディング時 or Settings → Storage で `iCloud Sync` を選ぶと SwiftData が
CloudKit private DB をミラーリングする。

### 同期される内容
- `Race` / `RaceResult` / `PacePlan` 各レコード
- `Attachment` のバイナリ (PDF / 画像) — `binaryData` プロパティで保存し、
  1MB 超は CloudKit が自動的に CKAsset として転送する
- `Race.logoData` (大会ロゴ画像)

### 必要な portal 作業（Apple Developer Program 加入後）
1. [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) で
   iCloud Container `iCloud.com.kn-nakamura.RunJourney` を作成
2. App ID の Capabilities で iCloud (CloudKit) を有効化し、上記コンテナを紐付け
3. 初回実機起動後、CloudKit Console でスキーマを Development → Production に deploy
4. (任意) 別端末で動作確認

## ライセンス

Private project — 個人開発。
