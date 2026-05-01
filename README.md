# RunJourney

マラソン大会の記録を地図上に可視化し、ルートをアニメーション再生・動画書き出しできる iOS / iPadOS / macOS ネイティブアプリ。

[`marathon-record-app`](../marathon-record-app)（React + Mapbox + Supabase Webアプリ）の純正アプリ版。

## 技術スタック

- **UI**: SwiftUI（iOS 17+ / iPadOS 17+ / macOS 14+）
- **データ**: SwiftData + iCloud (CloudKit) 同期
- **地図**: MapKit
- **チャート**: Swift Charts
- **ファイル取り込み**: TCX / GPX (`XMLParser`), FIT (`FitDataProtocol` SwiftPM)
- **動画書き出し**: AVAssetWriter + MKMapSnapshotter

## ビルド

```bash
xcodebuild -scheme RunJourney \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

または Xcode で `RunJourney.xcodeproj` を開いて Cmd+R。

## 開発計画

詳細は [`~/.claude/plans/developer-ios-ipados-mac-marathon-record-ancient-hennessy.md`](~/.claude/plans/) を参照。

## ライセンス

Private project — 個人開発。
