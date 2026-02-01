/**
 * SettingsView.jsx
 *
 * 設定画面コンポーネント
 * - Firebase認証対応
 * - CSV形式でのエクスポート/インポート
 * - サンプルCSV出力
 * - アプリ共有機能
 */

import React, { useState, useMemo, useRef } from 'react';
import { Button } from '../ui/Button';
import { exportData, importData } from '../../services/storage';
import {
  Download,
  Upload,
  Trash2,
  Sun,
  Moon,
  User,
  LogIn,
  LogOut,
  Cloud,
  CloudOff,
  Share2,
  FileJson,
  FileText,
  FileSpreadsheet,
} from 'lucide-react';
import { APP_VERSION, APP_NAME, APP_URL } from '../../constants/config';

// データ削除確認用のランダム英単語リスト
const RANDOM_WORDS = [
  'apple', 'banana', 'cherry', 'dolphin', 'eagle', 'forest', 'guitar', 'harbor',
  'island', 'jungle', 'knight', 'lemon', 'mountain', 'nature', 'ocean', 'planet',
  'queen', 'river', 'sunset', 'tiger', 'umbrella', 'valley', 'winter', 'yellow'
];

// CSVヘッダー定義
const CSV_HEADERS = [
  'name', 'date', 'distance', 'time', 'rank', 'location_address', 'location_lat', 'location_lng',
  'weather_description', 'weather_temperature', 'condition_physical', 'notes',
  'strava_url', 'garmin_url'
];

// CSVヘッダーの日本語説明
const CSV_HEADERS_JP = {
  name: '大会名（必須）',
  date: '開催日（必須、YYYY-MM-DD形式）',
  distance: '距離（必須、km）',
  time: 'タイム（必須、H:MM:SS形式）',
  rank: '順位',
  location_address: '場所の住所（必須）',
  location_lat: '緯度（必須）',
  location_lng: '経度（必須）',
  weather_description: '天候',
  weather_temperature: '気温',
  condition_physical: '体調（1-5）',
  notes: 'メモ',
  strava_url: 'STRAVA URL',
  garmin_url: 'Garmin URL'
};

/**
 * マラソンデータをCSV形式に変換
 */
const convertToCSV = (marathons) => {
  const rows = [CSV_HEADERS.join(',')];

  marathons.forEach(m => {
    const row = [
      `"${(m.name || '').replace(/"/g, '""')}"`,
      m.date || '',
      m.distance || '',
      m.time || '',
      m.rank || '',
      `"${(m.location?.address || '').replace(/"/g, '""')}"`,
      m.location?.lat || '',
      m.location?.lng || '',
      `"${(m.weather?.description || '').replace(/"/g, '""')}"`,
      m.weather?.temperature || '',
      m.condition?.physical || '',
      `"${(m.notes || '').replace(/"/g, '""')}"`,
      m.externalLinks?.strava || '',
      m.externalLinks?.garmin || ''
    ];
    rows.push(row.join(','));
  });

  return rows.join('\n');
};

/**
 * CSVをパースしてマラソンデータに変換
 */
const parseCSV = (csvText) => {
  const sanitizedText = csvText.replace(/^\uFEFF/, '');
  const lines = sanitizedText.split(/\r?\n/).filter(line => line.trim());
  if (lines.length < 2) {
    throw new Error('CSVファイルにデータがありません');
  }

  const headers = parseCSVLine(lines[0]).map((header) => (
    header.replace(/^\uFEFF/, '').trim().toLowerCase()
  ));
  const marathons = [];

  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVLine(lines[i]);
    const data = {};

    headers.forEach((header, idx) => {
      data[header] = values[idx] || '';
    });

    // 必須フィールドのチェック
    if (!data.name || !data.date || !data.distance || !data.time) {
      continue; // スキップ
    }

    const marathon = {
      id: `imported-${Date.now()}-${i}`,
      name: data.name,
      date: data.date,
      distance: parseFloat(data.distance),
      time: data.time,
      rank: data.rank ? parseInt(data.rank) : null,
      location: {
        address: data.location_address || '',
        lat: parseFloat(data.location_lat) || 35.6812,
        lng: parseFloat(data.location_lng) || 139.7671,
      },
      weather: data.weather_description ? {
        description: data.weather_description,
        temperature: data.weather_temperature ? parseFloat(data.weather_temperature) : null,
      } : null,
      condition: {
        physical: data.condition_physical ? parseInt(data.condition_physical) : 3,
        physicalEmoji: getConditionEmoji(parseInt(data.condition_physical) || 3),
      },
      notes: data.notes || '',
      externalLinks: {
        strava: data.strava_url || '',
        garmin: data.garmin_url || '',
      },
      photo: null, // CSVでは画像はサポートしない
    };

    marathons.push(marathon);
  }

  return marathons;
};

/**
 * CSVの1行をパース（ダブルクォート対応）
 */
const parseCSVLine = (line) => {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];

    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());

  return result;
};

/**
 * 体調の値から絵文字を取得
 */
const getConditionEmoji = (value) => {
  const emojis = { 1: '😷', 2: '😞', 3: '😐', 4: '😊', 5: '😄' };
  return emojis[value] || '😐';
};

/**
 * サンプルCSVを生成
 */
const generateSampleCSV = () => {
  const headers = CSV_HEADERS.join(',');
  const sampleData = [
    '"東京マラソン 2024",2024-03-03,42.195,3:45:30,1234,"東京都新宿区西新宿2丁目",35.6896,139.6922,"晴れ",12,4,"初フルマラソン完走！","https://strava.com/activities/xxx","https://connect.garmin.com/xxx"',
    '"横浜ハーフマラソン",2024-02-11,21.0975,1:45:00,567,"横浜市中区",35.4437,139.6380,"曇り",8,3,"PB更新","",""',
    '"駅伝大会 10km",2024-01-21,10,0:48:30,,"東京都港区",35.6581,139.7414,"晴れ時々曇り",15,5,"チームで参加",""',
  ];

  return headers + '\n' + sampleData.join('\n');
};

export const SettingsView = ({
  marathons,
  onImport,
  onClearAll,
  theme,
  onThemeToggle,
  user,
  useFirebase,
  hasLocalData,
  onMigrate,
  onLogin,
  onLogout,
}) => {
  const [importMode, setImportMode] = useState('merge');
  const [exportFormat, setExportFormat] = useState('json');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteWord, setDeleteWord] = useState('');
  const [confirmWord, setConfirmWord] = useState('');
  const fileInputRef = useRef(null);
  const csvInputRef = useRef(null);

  // JSONエクスポート
  const handleExportJSON = () => {
    const data = exportData(marathons, {});
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `runjourney-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // CSVエクスポート
  const handleExportCSV = () => {
    const csvContent = convertToCSV(marathons);
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF]); // UTF-8 BOM
    const blob = new Blob([bom, csvContent], {
      type: 'text/csv;charset=utf-8',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `runjourney-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // サンプルCSVダウンロード
  const handleDownloadSampleCSV = () => {
    const csvContent = generateSampleCSV();
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF]);
    const blob = new Blob([bom, csvContent], {
      type: 'text/csv;charset=utf-8',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'runjourney-sample.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // エクスポート
  const handleExport = () => {
    if (exportFormat === 'json') {
      handleExportJSON();
    } else {
      handleExportCSV();
    }
  };

  // JSONインポート
  const handleImportJSON = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const jsonData = JSON.parse(event.target?.result);
        const imported = importData(jsonData);
        onImport(imported.marathons, importMode === 'merge');
        alert('データをインポートしました');
      } catch (error) {
        console.error('Import error:', error);
        alert('インポートに失敗しました。正しいファイルを選択してください。');
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // CSVインポート
  const handleImportCSV = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const csvText = event.target?.result;
        const marathonsData = parseCSV(csvText);
        if (marathonsData.length === 0) {
          alert('インポート可能なデータがありません。必須フィールドを確認してください。');
          return;
        }
        onImport(marathonsData, importMode === 'merge');
        alert(`${marathonsData.length}件のデータをインポートしました`);
      } catch (error) {
        console.error('CSV Import error:', error);
        alert('CSVのインポートに失敗しました。フォーマットを確認してください。');
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // 削除確認モーダルを開く
  const openDeleteConfirm = () => {
    const word = RANDOM_WORDS[Math.floor(Math.random() * RANDOM_WORDS.length)];
    setDeleteWord(word);
    setConfirmWord('');
    setShowDeleteConfirm(true);
  };

  // 全削除
  const handleClearAll = () => {
    if (confirmWord === deleteWord) {
      onClearAll();
      setShowDeleteConfirm(false);
      alert('すべてのデータを削除しました');
    } else {
      alert('入力された単語が一致しません');
    }
  };

  // アプリ共有
  const handleShareApp = async () => {
    const shareData = {
      title: APP_NAME,
      text: `${APP_NAME} - マラソン大会の記録をマップで管理できるアプリ`,
      url: APP_URL,
    };

    if (navigator.share) {
      try {
        await navigator.share(shareData);
      } catch (error) {
        if (error.name !== 'AbortError') {
          await navigator.clipboard.writeText(APP_URL);
          alert('URLをクリップボードにコピーしました');
        }
      }
    } else {
      await navigator.clipboard.writeText(APP_URL);
      alert('URLをクリップボードにコピーしました');
    }
  };

  // ストレージ使用量を計算（概算）
  const storageSize = useMemo(() => {
    const dataStr = JSON.stringify(marathons);
    return (dataStr.length / 1024).toFixed(2);
  }, [marathons]);

  return (
    <div className="max-w-4xl mx-auto space-y-6 md:space-y-8">
      {/* アカウント設定（Firebase有効時のみ表示） */}
      {(onLogin || onLogout) && (
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 md:p-6 shadow-lg">
          <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-4 md:mb-6">
            アカウント
          </h2>

          <div className="space-y-4 md:space-y-6">
            {/* ログイン状態 */}
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="flex items-center gap-3 md:gap-4">
                  <User className="text-primary-500 flex-shrink-0" size={24} />
                  <div>
                    <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white">
                      {user ? 'ログイン中' : 'ゲストモード'}
                    </h3>
                    {user ? (
                      <p className="text-sm text-gray-600 dark:text-gray-400 break-all">
                        {user.email}
                      </p>
                    ) : (
                      <p className="text-sm text-gray-600 dark:text-gray-400">
                        ログインするとデータを同期できます
                      </p>
                    )}
                  </div>
                </div>
                {user ? (
                  <Button onClick={onLogout} variant="outline" className="w-full md:w-auto">
                    <LogOut size={18} className="mr-2" />
                    ログアウト
                  </Button>
                ) : (
                  <Button onClick={onLogin} className="w-full md:w-auto">
                    <LogIn size={18} className="mr-2" />
                    ログイン
                  </Button>
                )}
              </div>
            </div>

            {/* 同期状態 */}
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
              <div className="flex items-center gap-3 md:gap-4">
                {useFirebase ? (
                  <Cloud className="text-green-500 flex-shrink-0" size={24} />
                ) : (
                  <CloudOff className="text-gray-400 flex-shrink-0" size={24} />
                )}
                <div className="flex-1">
                  <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white">
                    データ同期
                  </h3>
                  {useFirebase ? (
                    <p className="text-sm text-green-600 dark:text-green-400">
                      クラウドに同期中
                    </p>
                  ) : (
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      ローカル保存
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* データ移行 */}
            {user && hasLocalData && (
              <div className="border border-blue-200 dark:border-blue-800 rounded-lg p-4 md:p-6 bg-blue-50 dark:bg-blue-900/10">
                <div className="flex items-start gap-3 md:gap-4">
                  <Upload className="text-blue-500 mt-1 flex-shrink-0" size={24} />
                  <div className="flex-1">
                    <h3 className="font-bold text-base md:text-lg text-blue-700 dark:text-blue-400 mb-2">
                      ローカルデータをクラウドに移行
                    </h3>
                    <p className="text-sm text-blue-600 dark:text-blue-400 mb-4">
                      ログイン前に保存されたデータをクラウドに移行できます。
                    </p>
                    <Button onClick={onMigrate} className="w-full md:w-auto">
                      <Upload size={20} className="mr-2" />
                      データを移行
                    </Button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* データ管理 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 md:p-6 shadow-lg">
        <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-4 md:mb-6">
          データ管理
        </h2>

        <div className="space-y-4 md:space-y-6">
          {/* エクスポート */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
            <div className="flex items-start gap-3 md:gap-4">
              <Download className="text-primary-500 mt-1 flex-shrink-0" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white mb-2">
                  データをエクスポート
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  マラソンデータをダウンロードします。
                </p>

                {/* フォーマット選択 */}
                <div className="mb-4 flex flex-wrap gap-2">
                  <button
                    onClick={() => setExportFormat('json')}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg border ${
                      exportFormat === 'json'
                        ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-300'
                        : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400'
                    }`}
                  >
                    <FileJson size={18} />
                    JSON
                  </button>
                  <button
                    onClick={() => setExportFormat('csv')}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg border ${
                      exportFormat === 'csv'
                        ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-300'
                        : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400'
                    }`}
                  >
                    <FileSpreadsheet size={18} />
                    CSV
                  </button>
                </div>

                <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
                  {exportFormat === 'json'
                    ? '※ JSON形式は画像データを含む完全なバックアップです'
                    : '※ CSV形式はExcel等で編集できます（画像は含まれません）'}
                </p>

                <Button onClick={handleExport} className="w-full md:w-auto">
                  <Download size={20} className="mr-2" />
                  {exportFormat.toUpperCase()}でエクスポート
                </Button>
              </div>
            </div>
          </div>

          {/* インポート */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
            <div className="flex items-start gap-3 md:gap-4">
              <Upload className="text-primary-500 mt-1 flex-shrink-0" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white mb-2">
                  データをインポート
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  JSONまたはCSVファイルからデータを復元します。
                </p>

                {/* インポートモード選択 */}
                <div className="mb-4 space-y-2">
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      value="merge"
                      checked={importMode === 'merge'}
                      onChange={(e) => setImportMode(e.target.value)}
                      className="text-primary-500"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">
                      追加（既存データに追加）
                    </span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      value="replace"
                      checked={importMode === 'replace'}
                      onChange={(e) => setImportMode(e.target.value)}
                      className="text-primary-500"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">
                      上書き（既存データを置き換え）
                    </span>
                  </label>
                </div>

                <input
                  type="file"
                  accept=".json"
                  onChange={handleImportJSON}
                  className="hidden"
                  ref={fileInputRef}
                />
                <input
                  type="file"
                  accept=".csv"
                  onChange={handleImportCSV}
                  className="hidden"
                  ref={csvInputRef}
                />
                <div className="flex flex-wrap gap-2">
                  <Button onClick={() => fileInputRef.current?.click()} variant="outline" className="flex-1 md:flex-none">
                    <FileJson size={18} className="mr-2" />
                    JSON
                  </Button>
                  <Button onClick={() => csvInputRef.current?.click()} variant="outline" className="flex-1 md:flex-none">
                    <FileSpreadsheet size={18} className="mr-2" />
                    CSV
                  </Button>
                </div>
              </div>
            </div>
          </div>

          {/* サンプルCSV */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
            <div className="flex items-start gap-3 md:gap-4">
              <FileText className="text-primary-500 mt-1 flex-shrink-0" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white mb-2">
                  サンプルCSV
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  CSVの書式を確認できるサンプルファイルをダウンロードできます。
                  このファイルを編集して一括インポートに使用できます。
                </p>
                <Button onClick={handleDownloadSampleCSV} variant="outline" className="w-full md:w-auto">
                  <Download size={20} className="mr-2" />
                  サンプルCSVをダウンロード
                </Button>
              </div>
            </div>
          </div>

          {/* データ削除 */}
          <div className="border border-red-200 dark:border-red-800 rounded-lg p-4 md:p-6 bg-red-50 dark:bg-red-900/10">
            <div className="flex items-start gap-3 md:gap-4">
              <Trash2 className="text-red-500 mt-1 flex-shrink-0" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-base md:text-lg text-red-700 dark:text-red-400 mb-2">
                  すべてのデータを削除
                </h3>
                <p className="text-sm text-red-600 dark:text-red-400 mb-4">
                  この操作は取り消せません。
                </p>
                <Button variant="danger" onClick={openDeleteConfirm} className="w-full md:w-auto">
                  <Trash2 size={20} className="mr-2" />
                  削除
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 表示設定 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 md:p-6 shadow-lg">
        <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-4 md:mb-6">
          表示設定
        </h2>

        <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-center gap-3 md:gap-4">
              {theme === 'dark' ? (
                <Moon className="text-primary-500 flex-shrink-0" size={24} />
              ) : (
                <Sun className="text-primary-500 flex-shrink-0" size={24} />
              )}
              <div>
                <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white">
                  テーマ
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  現在: {theme === 'dark' ? 'ダーク' : 'ライト'}モード
                </p>
              </div>
            </div>
            <Button onClick={onThemeToggle} variant="outline" className="w-full md:w-auto">
              {theme === 'dark' ? 'ライトモード' : 'ダークモード'}
            </Button>
          </div>
        </div>
      </div>

      {/* アプリ共有 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 md:p-6 shadow-lg">
        <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-4 md:mb-6">
          アプリを共有
        </h2>

        <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:p-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-center gap-3 md:gap-4">
              <Share2 className="text-primary-500 flex-shrink-0" size={24} />
              <div>
                <h3 className="font-bold text-base md:text-lg text-gray-900 dark:text-white">
                  友達に共有
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  {APP_URL}
                </p>
              </div>
            </div>
            <Button onClick={handleShareApp} className="w-full md:w-auto">
              <Share2 size={20} className="mr-2" />
              共有
            </Button>
          </div>
        </div>
      </div>

      {/* アプリ情報 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 md:p-6 shadow-lg">
        <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-4 md:mb-6">
          アプリ情報
        </h2>

        <div className="space-y-3 text-sm">
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">アプリ名:</span>
            <span className="font-medium text-gray-900 dark:text-white">
              {APP_NAME}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">バージョン:</span>
            <span className="font-medium text-gray-900 dark:text-white">
              {APP_VERSION}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">データ件数:</span>
            <span className="font-medium text-gray-900 dark:text-white">
              {marathons.length}件
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">使用容量:</span>
            <span className="font-medium text-gray-900 dark:text-white">
              約 {storageSize}KB
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">保存先:</span>
            <span className="font-medium text-gray-900 dark:text-white">
              {useFirebase ? 'クラウド' : 'ローカル'}
            </span>
          </div>
        </div>

        <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
          <p className="text-xs text-gray-500 dark:text-gray-400 text-center">
            Made with ❤️ for Runners
          </p>
        </div>
      </div>

      {/* 削除確認モーダル */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-xl p-6 max-w-md w-full shadow-2xl">
            <h3 className="text-xl font-bold text-red-600 dark:text-red-400 mb-4">
              データ削除の確認
            </h3>
            <p className="text-gray-700 dark:text-gray-300 mb-4">
              この操作は取り消せません。すべてのデータが完全に削除されます。
            </p>
            <p className="text-gray-700 dark:text-gray-300 mb-2">
              削除を確認するには、以下の単語を入力してください：
            </p>
            <p className="text-2xl font-bold text-center text-red-600 dark:text-red-400 mb-4 bg-red-50 dark:bg-red-900/20 py-2 rounded-lg">
              {deleteWord}
            </p>
            <input
              type="text"
              value={confirmWord}
              onChange={(e) => setConfirmWord(e.target.value)}
              placeholder="上記の単語を入力"
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-red-500 mb-4"
            />
            <div className="flex gap-3 justify-end">
              <Button
                variant="secondary"
                onClick={() => setShowDeleteConfirm(false)}
              >
                キャンセル
              </Button>
              <Button
                variant="danger"
                onClick={handleClearAll}
                disabled={confirmWord !== deleteWord}
              >
                削除実行
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
