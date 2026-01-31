# 開発ガイド

マラソントラッカーへの貢献ありがとうございます！このドキュメントでは、プロジェクトの構造と開発方法について説明します。

## 📋 目次

1. [開発環境のセットアップ](#開発環境のセットアップ)
2. [プロジェクト構造](#プロジェクト構造)
3. [機能追加ガイド](#機能追加ガイド)
4. [コーディング規約](#コーディング規約)
5. [デバッグのヒント](#デバッグのヒント)

## 🛠️ 開発環境のセットアップ

### 必要なツール

- Node.js 18.0.0以上
- npm 9.0.0以上
- Git
- VS Code（推奨）

### VS Code拡張機能（推奨）

- ESLint
- Prettier
- Tailwind CSS IntelliSense
- ES7+ React/Redux/React-Native snippets

### 初回セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/yourusername/marathon-tracker.git
cd marathon-tracker

# 依存関係のインストール
npm install

# 開発サーバーの起動
npm run dev
```

## 📂 プロジェクト構造

```
src/
├── components/          # Reactコンポーネント
│   ├── map/            # 地図関連のコンポーネント
│   │   └── MapView.jsx
│   ├── marathon/       # マラソン関連のコンポーネント
│   │   ├── MarathonCard.jsx
│   │   ├── MarathonForm.jsx
│   │   └── MarathonList.jsx
│   ├── stats/          # 統計・グラフコンポーネント
│   │   ├── BestRecords.jsx
│   │   └── ChartsView.jsx
│   ├── settings/       # 設定画面コンポーネント
│   │   └── SettingsView.jsx
│   └── ui/             # 再利用可能なUIコンポーネント
│       ├── Button.jsx
│       ├── Modal.jsx
│       └── Tabs.jsx
├── hooks/              # カスタムフック
│   ├── useMarathons.js # マラソンデータ管理
│   ├── useLocalStorage.js
│   └── useTheme.js
├── services/           # 外部サービスとの連携
│   ├── storage.js      # LocalStorage操作
│   ├── geocoding.js    # Nominatim API
│   └── weather.js      # Open-Meteo API
├── utils/              # ユーティリティ関数
│   ├── dateFormat.js   # 日付フォーマット
│   ├── timeUtils.js    # タイム計算
│   └── calculations.js # PB/SB計算など
└── constants/          # 定数
    └── config.js
```

## 🎯 機能追加ガイド

### 新しいマラソンデータ項目を追加する場合

#### 1. データ構造の更新

`src/constants/config.js` でデータ構造を定義：

```javascript
// 新しいプリセットを追加する例
export const NEW_PRESET = [
  { value: 'option1', label: 'オプション1' },
  { value: 'option2', label: 'オプション2' },
];
```

#### 2. フォームの更新

`src/components/marathon/MarathonForm.jsx` に新しい入力欄を追加：

```javascript
// formDataに新しいフィールドを追加
const [formData, setFormData] = useState({
  // 既存のフィールド...
  newField: '', // 新しいフィールド
});

// フォームに入力欄を追加
<div>
  <label>新しいフィールド</label>
  <input
    value={formData.newField}
    onChange={(e) => setFormData({ ...formData, newField: e.target.value })}
  />
</div>
```

#### 3. 表示の更新

`src/components/marathon/MarathonCard.jsx` で新しいデータを表示：

```javascript
{marathon.newField && (
  <p>{marathon.newField}</p>
)}
```

### ストレージをFirebaseに切り替える場合

#### 1. Firebaseの設定

```bash
npm install firebase
```

#### 2. Firebase設定ファイルの作成

`src/services/firebase.js` を作成：

```javascript
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  // Firebase設定
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
```

#### 3. useMarathonsフックの更新

`src/hooks/useMarathons.js` のimportを変更：

```javascript
// LocalStorageからFirebaseに切り替え
import { saveMarathons, loadMarathons } from '../services/firebase';
```

### 新しいグラフを追加する場合

`src/components/stats/ChartsView.jsx` に追加：

```javascript
// 新しいグラフデータの計算
const newChartData = useMemo(() => {
  // データ処理ロジック
  return {
    labels: [...],
    datasets: [...],
  };
}, [marathons]);

// JSX内にグラフを追加
<div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
  <h3>新しいグラフ</h3>
  <Line data={newChartData} options={chartOptions} />
</div>
```

## 📝 コーディング規約

### JavaScript/React

- **関数コンポーネント**を使用
- **フック**でロジックを分離
- **PropTypes**は使用せず、コメントで型を記述

```javascript
/**
 * Buttonコンポーネント
 * @param {Object} props
 * @param {string} props.variant - ボタンのスタイル
 * @param {Function} props.onClick - クリックハンドラ
 */
export const Button = ({ variant, onClick }) => {
  // 実装
};
```

### ファイル命名

- コンポーネント: `PascalCase.jsx`
- フック: `useCamelCase.js`
- ユーティリティ: `camelCase.js`
- 定数: `UPPER_SNAKE_CASE`

### スタイリング

- **Tailwind CSS**を優先
- カスタムCSSは`index.css`に追加
- ダークモード対応を常に考慮

```jsx
// Good
<div className="bg-white dark:bg-gray-800">

// Bad
<div style={{ backgroundColor: 'white' }}>
```

### コメント

- **ファイルの先頭**に概要を記述
- **複雑なロジック**には説明を追加
- **TODO**コメントでタスクを管理

```javascript
/**
 * calculatePBs
 * 
 * 距離別のPB（Personal Best）を計算
 * 
 * @param {Array} marathons - マラソンデータの配列
 * @returns {Object} 距離をキーとしたPBオブジェクト
 */
export const calculatePBs = (marathons) => {
  // TODO: パフォーマンス最適化
  // 実装
};
```

## 🐛 デバッグのヒント

### よくある問題

#### 1. データが保存されない

```javascript
// LocalStorageの確認
console.log(localStorage.getItem('marathon-tracker-marathons'));

// デバッグ用にconsole.logを追加
const saveMarathons = (marathons) => {
  console.log('Saving:', marathons);
  // 保存処理
};
```

#### 2. 地図が表示されない

```javascript
// Leafletのインポート確認
import 'leaflet/dist/leaflet.css';

// マーカーアイコンの設定確認
delete L.Icon.Default.prototype._getIconUrl;
```

#### 3. グラフが正しく表示されない

```javascript
// データ構造の確認
console.log('Chart data:', timeProgressionData);

// Chart.jsの登録確認
ChartJS.register(/* 必要な要素 */);
```

### デバッグツール

- **React Developer Tools**: コンポーネントの状態確認
- **Redux DevTools**: 状態管理のデバッグ（将来的に）
- **ブラウザのコンソール**: console.logでデバッグ

## 🧪 テスト

現在、テストは実装されていませんが、将来的に追加予定です。

```bash
# テストの実行（将来）
npm run test

# カバレッジ確認（将来）
npm run test:coverage
```

## 📦 ビルド

```bash
# 本番ビルド
npm run build

# ビルド結果の確認
npm run preview
```

## 🚀 デプロイ

### Vercelへのデプロイ

```bash
# Vercel CLIでデプロイ
vercel

# 本番環境にデプロイ
vercel --prod
```

## 💡 ベストプラクティス

### パフォーマンス

- **useMemo**で重い計算をメモ化
- **useCallback**でコールバック関数をメモ化
- **React.lazy**でコード分割（必要に応じて）

### アクセシビリティ

- **セマンティックHTML**を使用
- **alt属性**を必ず追加
- **キーボードナビゲーション**をサポート

### セキュリティ

- **XSS対策**: ユーザー入力をサニタイズ
- **APIキー**: 環境変数で管理（将来）

## 📞 質問・サポート

- GitHub Issues: バグ報告・機能要望
- GitHub Discussions: 質問・議論

---

Happy Coding! 🚀
