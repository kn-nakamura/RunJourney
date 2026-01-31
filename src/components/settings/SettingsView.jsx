/**
 * SettingsView.jsx
 * 
 * 設定画面コンポーネント
 */

import React, { useState } from 'react';
import { Button } from '../ui/Button';
import { exportData, importData } from '../../services/storage';
import { Download, Upload, Trash2, Sun, Moon } from 'lucide-react';
import { APP_VERSION } from '../../constants/config';

/**
 * SettingsViewコンポーネント
 * @param {Object} props
 * @param {Array} props.marathons - マラソンデータ
 * @param {Function} props.onImport - インポートハンドラ
 * @param {Function} props.onClearAll - 全削除ハンドラ
 * @param {string} props.theme - 現在のテーマ
 * @param {Function} props.onThemeToggle - テーマ切り替えハンドラ
 */
export const SettingsView = ({
  marathons,
  onImport,
  onClearAll,
  theme,
  onThemeToggle,
}) => {
  const [importMode, setImportMode] = useState('merge');

  // エクスポート
  const handleExport = () => {
    const data = exportData(marathons, {});
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `marathon-tracker-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // インポート
  const handleImport = (e) => {
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
  };

  // 全削除
  const handleClearAll = () => {
    if (
      window.confirm(
        '本当にすべてのデータを削除しますか？この操作は取り消せません。'
      )
    ) {
      onClearAll();
      alert('すべてのデータを削除しました');
    }
  };

  // ストレージ使用量を計算（概算）
  const storageSize = useMemo(() => {
    const dataStr = JSON.stringify(marathons);
    return (dataStr.length / 1024).toFixed(2);
  }, [marathons]);

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* データ管理 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
          データ管理
        </h2>

        <div className="space-y-6">
          {/* エクスポート */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-6">
            <div className="flex items-start gap-4">
              <Download className="text-primary-500 mt-1" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-lg text-gray-900 dark:text-white mb-2">
                  データをエクスポート
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  すべてのマラソンデータをJSON形式でダウンロードします。
                  バックアップや他のデバイスへの移行に使用できます。
                </p>
                <Button onClick={handleExport}>
                  <Download size={20} className="mr-2" />
                  エクスポート実行
                </Button>
              </div>
            </div>
          </div>

          {/* インポート */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-6">
            <div className="flex items-start gap-4">
              <Upload className="text-primary-500 mt-1" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-lg text-gray-900 dark:text-white mb-2">
                  データをインポート
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  JSONファイルからデータを復元します。
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
                  onChange={handleImport}
                  className="hidden"
                  id="import-file"
                />
                <label htmlFor="import-file">
                  <Button as="span">
                    <Upload size={20} className="mr-2" />
                    ファイルを選択
                  </Button>
                </label>
              </div>
            </div>
          </div>

          {/* データ削除 */}
          <div className="border border-red-200 dark:border-red-800 rounded-lg p-6 bg-red-50 dark:bg-red-900/10">
            <div className="flex items-start gap-4">
              <Trash2 className="text-red-500 mt-1" size={24} />
              <div className="flex-1">
                <h3 className="font-bold text-lg text-red-700 dark:text-red-400 mb-2">
                  すべてのデータを削除
                </h3>
                <p className="text-sm text-red-600 dark:text-red-400 mb-4">
                  ⚠️ この操作は取り消せません。すべてのマラソンデータが完全に削除されます。
                </p>
                <Button variant="danger" onClick={handleClearAll}>
                  <Trash2 size={20} className="mr-2" />
                  削除（確認あり）
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 表示設定 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
          表示設定
        </h2>

        <div className="space-y-6">
          {/* テーマ */}
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-6">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                {theme === 'dark' ? (
                  <Moon className="text-primary-500" size={24} />
                ) : (
                  <Sun className="text-primary-500" size={24} />
                )}
                <div>
                  <h3 className="font-bold text-lg text-gray-900 dark:text-white">
                    テーマ
                  </h3>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    現在: {theme === 'dark' ? 'ダーク' : 'ライト'}モード
                  </p>
                </div>
              </div>
              <Button onClick={onThemeToggle} variant="outline">
                {theme === 'dark' ? '☀️ ライトモード' : '🌙 ダークモード'}
              </Button>
            </div>
          </div>
        </div>
      </div>

      {/* アプリ情報 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
          アプリ情報
        </h2>

        <div className="space-y-4 text-sm">
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
        </div>

        <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
          <p className="text-xs text-gray-500 dark:text-gray-400 text-center">
            Made with ❤️ by Marathon Runner
          </p>
        </div>
      </div>
    </div>
  );
};

// useMemoをインポート
import { useMemo } from 'react';
