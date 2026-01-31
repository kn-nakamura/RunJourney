# 🏃 マラソントラッカー

マラソン大会の記録を管理し、地図上に表示するWebアプリケーションです。

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![React](https://img.shields.io/badge/React-18.2.0-61dafb)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 機能

### 📍 マップ表示
- Leafletを使用した地図上にマラソン大会の位置を表示
- PB（Personal Best）は金色、SB（Season Best）は銀色のマーカーで表示
- マーカークリックで詳細情報をポップアップ表示

### 📋 記録管理
- **ベスト記録**: 距離別のPB/SB自動計算・表示
- **大会一覧**: カード形式での美しい一覧表示
- **フィルタリング**: 年度別、距離別、タイム順での並び替え

### 📊 統計・グラフ
- タイム推移グラフ（折れ線グラフ）
- 距離別参加回数（棒グラフ）
- 月別参加回数（棒グラフ）
- 統計サマリー（総大会数、総距離など）

### ⚙️ 設定
- データのエクスポート/インポート（JSON形式）
- ダークモード対応
- すべてのデータ削除機能

### 🎯 記録入力
- **距離**: プリセット選択（フル、ハーフ、10km、5kmなど）+ カスタム入力
- **タイム**: 時・分・秒の分離入力（数値のみ）
- **場所**: Nominatim APIを使った住所検索
- **天候**: Open-Meteo APIによる過去天候データの自動取得 + 手動選択
- **体調**: 5段階評価 + メモ
- **外部リンク**: STRAVAやGarmin Connectへのリンク
- **写真**: サムネイル画像のアップロード
- **メモ**: 自由記述欄

## 🚀 セットアップ

### 必要環境
- Node.js 18.0.0以上
- npm 9.0.0以上

### インストール

```bash
# リポジトリのクローン
git clone https://github.com/yourusername/marathon-tracker.git
cd marathon-tracker

# 依存関係のインストール
npm install

# 開発サーバーの起動
npm run dev
```

ブラウザで `http://localhost:3000` を開いてください。

### ビルド

```bash
# 本番用ビルド
npm run build

# ビルド結果のプレビュー
npm run preview
```

## 📦 Vercelへのデプロイ

### 方法1: Vercel CLI

```bash
# Vercel CLIのインストール
npm i -g vercel

# デプロイ
vercel
```

### 方法2: GitHubとの連携

1. GitHubにリポジトリをpush
2. [Vercel](https://vercel.com)にログイン
3. "Import Project"からリポジトリを選択
4. デプロイボタンをクリック

自動的にビルドとデプロイが完了します！

## 🛠️ 技術スタック

- **Frontend**: React 18 + Vite
- **スタイリング**: Tailwind CSS
- **地図**: Leaflet + React Leaflet
- **グラフ**: Chart.js + React Chartjs 2
- **アイコン**: Lucide React
- **日付処理**: date-fns
- **データ保存**: LocalStorage（将来的にFirebase対応予定）

### 使用API
- **Nominatim API**: 住所検索（無料、APIキー不要）
- **Open-Meteo API**: 過去の天候データ取得（無料、APIキー不要）

## 📂 プロジェクト構造

```
marathon-tracker/
├── public/              # 静的ファイル
├── src/
│   ├── components/     # Reactコンポーネント
│   │   ├── map/       # 地図関連
│   │   ├── marathon/  # マラソン関連
│   │   ├── stats/     # 統計関連
│   │   ├── settings/  # 設定関連
│   │   └── ui/        # 共通UIコンポーネント
│   ├── hooks/         # カスタムフック
│   ├── services/      # API・データ処理
│   ├── utils/         # ユーティリティ関数
│   ├── constants/     # 定数
│   ├── App.jsx        # メインアプリ
│   ├── main.jsx       # エントリーポイント
│   └── index.css      # グローバルスタイル
├── package.json
├── vite.config.js
├── tailwind.config.js
└── vercel.json
```

## 🎨 デザインについて

このアプリは**スポーティー・ミニマル・モダン**なデザインを採用しています：

- **カラー**: オレンジとブルーのグラデーション
- **フォント**: Outfit（スポーティーでモダン）
- **アニメーション**: スムーズなトランジション
- **ダークモード**: 完全対応

## 📱 レスポンシブ対応

- デスクトップ（1280px以上）
- タブレット（768px - 1279px）
- モバイル（767px以下）

モバイルでは右下にフローティングボタンを配置し、使いやすさを向上させています。

## 🔧 開発ガイド

### コードフォーマット

```bash
# ESLintでチェック
npm run lint

# Prettierでフォーマット
npm run format
```

### 新機能の追加

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## 📊 データ形式

### エクスポートデータ（JSON）

```json
{
  "version": "1.0",
  "exportDate": "2024-01-31T10:00:00Z",
  "marathons": [
    {
      "id": "marathon-001",
      "name": "東京マラソン",
      "date": "2023-03-05",
      "distance": 42.195,
      "time": "3:45:30",
      "rank": 120,
      "location": {
        "lat": 35.6812,
        "lng": 139.7671,
        "address": "東京都庁"
      },
      "externalLinks": {
        "strava": "https://...",
        "garmin": "https://..."
      },
      "condition": {
        "physical": 4,
        "physicalEmoji": "😊",
        "notes": "体調良好"
      },
      "weather": {
        "icon": "☀️",
        "description": "晴れ",
        "temperature": 18,
        "autoFetched": true
      },
      "photo": "base64...",
      "notes": "良いレースでした",
      "isPB": true,
      "isSB": false
    }
  ]
}
```

## 🔮 今後の予定（Phase 2）

- [ ] Firebase連携（複数デバイス同期）
- [ ] 複数写真のアップロード
- [ ] ルート描画機能
- [ ] SNSシェア機能
- [ ] 目標設定機能
- [ ] 天候・体調別パフォーマンス分析
- [ ] コミュニティ機能
- [ ] PWA対応

## 🐛 問題が発生した場合

### 地図が表示されない
- ブラウザのコンソールでエラーを確認
- インターネット接続を確認

### データが保存されない
- ブラウザのLocalStorageが有効か確認
- プライベートブラウジングモードでは動作しない可能性あり

### Vercelデプロイ後に文字だけになる
- `vercel.json` が正しく設定されているか確認
- ビルドコマンドが `npm run build` になっているか確認

## 📄 ライセンス

MIT License

## 👤 作成者

Marathon Runner

## 🙏 謝辞

- [Leaflet](https://leafletjs.com/) - 地図表示
- [Chart.js](https://www.chartjs.org/) - グラフ描画
- [Nominatim](https://nominatim.org/) - 住所検索
- [Open-Meteo](https://open-meteo.com/) - 天候データ
- [Lucide](https://lucide.dev/) - アイコン

---

Happy Running! 🏃‍♂️💨
