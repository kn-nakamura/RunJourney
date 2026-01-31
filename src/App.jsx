/**
 * App.jsx
 * 
 * メインアプリケーションコンポーネント
 */

import React, { useState } from 'react';
import { Tabs } from './components/ui/Tabs';
import { Button } from './components/ui/Button';
import { MapView } from './components/map/MapView';
import { MarathonForm } from './components/marathon/MarathonForm';
import { MarathonList } from './components/marathon/MarathonList';
import { BestRecords } from './components/stats/BestRecords';
import { ChartsView } from './components/stats/ChartsView';
import { SettingsView } from './components/settings/SettingsView';
import { useMarathons } from './hooks/useMarathons';
import { useTheme } from './hooks/useTheme';
import { getAvailableYears } from './utils/calculations';
import { Map, FileText, BarChart3, Settings, Plus } from 'lucide-react';
import { TABS } from './constants/config';

function App() {
  const [activeTab, setActiveTab] = useState(TABS.MAP);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingMarathon, setEditingMarathon] = useState(null);
  const [recordsSubTab, setRecordsSubTab] = useState('best'); // 'best' or 'list'

  const { theme, toggleTheme } = useTheme();
  const {
    marathons,
    rawMarathons,
    addMarathon,
    updateMarathon,
    deleteMarathon,
    clearAllMarathons,
    importMarathons,
    pbs,
    sbs,
    selectedYear,
    setSelectedYear,
  } = useMarathons();

  const availableYears = getAvailableYears(marathons);

  // タブ定義
  const tabs = [
    { id: TABS.MAP, label: 'マップ', icon: Map },
    { id: TABS.RECORDS, label: '記録', icon: FileText },
    { id: TABS.STATS, label: 'グラフ', icon: BarChart3 },
    { id: TABS.SETTINGS, label: '設定', icon: Settings },
  ];

  // フォーム送信
  const handleFormSubmit = (marathonData) => {
    if (editingMarathon) {
      updateMarathon(editingMarathon.id, marathonData);
      setEditingMarathon(null);
    } else {
      addMarathon(marathonData);
    }
    setIsFormOpen(false);
  };

  // 編集開始
  const handleEdit = (marathon) => {
    setEditingMarathon(marathon);
    setIsFormOpen(true);
  };

  // 削除
  const handleDelete = (id) => {
    if (window.confirm('この大会を削除しますか？')) {
      deleteMarathon(id);
    }
  };

  // マーカークリック
  const handleMarkerClick = (marathon) => {
    setActiveTab(TABS.RECORDS);
    setRecordsSubTab('list');
  };

  // 詳細に移動（マップやベスト記録から）
  const handleNavigateToDetail = (marathon) => {
    setActiveTab(TABS.RECORDS);
    setRecordsSubTab('list');
    // スクロールのためにマラソンIDを一時的に保存
    setTimeout(() => {
      const element = document.getElementById(`marathon-${marathon.id}`);
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        element.classList.add('ring-2', 'ring-primary-500');
        setTimeout(() => {
          element.classList.remove('ring-2', 'ring-primary-500');
        }, 2000);
      }
    }, 100);
  };

  // インポート
  const handleImport = (importedMarathons, merge) => {
    importMarathons(importedMarathons, merge);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 transition-colors duration-200">
      {/* ヘッダー */}
      <header className="bg-white dark:bg-gray-800 shadow-md sticky top-0 z-40">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-gradient-to-br from-primary-500 to-secondary-500 rounded-xl flex items-center justify-center text-white text-2xl font-bold shadow-lg">
                🏃
              </div>
              <h1 className="text-2xl md:text-3xl font-bold bg-gradient-to-r from-primary-600 to-secondary-600 bg-clip-text text-transparent">
                マラソントラッカー
              </h1>
            </div>

            {/* 新規追加ボタン（デスクトップ） */}
            <div className="hidden md:block">
              <Button
                onClick={() => {
                  setEditingMarathon(null);
                  setIsFormOpen(true);
                }}
                size="lg"
              >
                <Plus size={20} className="mr-2" />
                新しい大会を追加
              </Button>
            </div>
          </div>
        </div>

        {/* タブナビゲーション */}
        <Tabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />
      </header>

      {/* メインコンテンツ */}
      <main className="container mx-auto px-4 py-6">
        {/* マップタブ */}
        {activeTab === TABS.MAP && (
          <div className="h-[calc(100vh-200px)] animate-fade-in">
            {marathons.length > 0 ? (
              <MapView
                marathons={marathons}
                onMarkerClick={handleMarkerClick}
                onNavigateToDetail={handleNavigateToDetail}
              />
            ) : (
              <div className="h-full flex items-center justify-center bg-white dark:bg-gray-800 rounded-xl shadow-lg">
                <div className="text-center">
                  <p className="text-gray-500 dark:text-gray-400 text-lg mb-4">
                    まだ大会が登録されていません
                  </p>
                  <Button onClick={() => setIsFormOpen(true)}>
                    <Plus size={20} className="mr-2" />
                    最初の大会を追加
                  </Button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* 記録タブ */}
        {activeTab === TABS.RECORDS && (
          <div className="animate-fade-in">
            {/* サブタブ */}
            <div className="mb-6 flex gap-4 border-b border-gray-200 dark:border-gray-700">
              <button
                onClick={() => setRecordsSubTab('best')}
                className={`px-4 py-2 font-medium border-b-2 transition-colors ${
                  recordsSubTab === 'best'
                    ? 'border-primary-500 text-primary-600 dark:text-primary-400'
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400'
                }`}
              >
                ベスト記録
              </button>
              <button
                onClick={() => setRecordsSubTab('list')}
                className={`px-4 py-2 font-medium border-b-2 transition-colors ${
                  recordsSubTab === 'list'
                    ? 'border-primary-500 text-primary-600 dark:text-primary-400'
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400'
                }`}
              >
                大会一覧
              </button>
            </div>

            {recordsSubTab === 'best' ? (
              <BestRecords
                pbs={pbs}
                sbs={sbs}
                selectedYear={selectedYear}
                onYearChange={setSelectedYear}
                availableYears={availableYears}
                onRecordClick={handleNavigateToDetail}
              />
            ) : (
              <MarathonList
                marathons={marathons}
                onEdit={handleEdit}
                onDelete={handleDelete}
              />
            )}
          </div>
        )}

        {/* グラフタブ */}
        {activeTab === TABS.STATS && (
          <div className="animate-fade-in">
            {marathons.length > 0 ? (
              <ChartsView marathons={marathons} />
            ) : (
              <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-12 text-center">
                <p className="text-gray-500 dark:text-gray-400 text-lg mb-4">
                  まだ大会が登録されていません
                </p>
                <Button onClick={() => setIsFormOpen(true)}>
                  <Plus size={20} className="mr-2" />
                  最初の大会を追加
                </Button>
              </div>
            )}
          </div>
        )}

        {/* 設定タブ */}
        {activeTab === TABS.SETTINGS && (
          <div className="animate-fade-in">
            <SettingsView
              marathons={rawMarathons}
              onImport={handleImport}
              onClearAll={clearAllMarathons}
              theme={theme}
              onThemeToggle={toggleTheme}
            />
          </div>
        )}
      </main>

      {/* フローティング追加ボタン（モバイル） */}
      <button
        onClick={() => {
          setEditingMarathon(null);
          setIsFormOpen(true);
        }}
        className="md:hidden fixed bottom-6 right-6 w-14 h-14 bg-gradient-to-r from-primary-500 to-primary-600 text-white rounded-full shadow-2xl flex items-center justify-center hover:shadow-3xl transition-all duration-200 z-50"
      >
        <Plus size={28} />
      </button>

      {/* マラソン登録フォーム */}
      <MarathonForm
        isOpen={isFormOpen}
        onClose={() => {
          setIsFormOpen(false);
          setEditingMarathon(null);
        }}
        onSubmit={handleFormSubmit}
        initialData={editingMarathon}
      />
    </div>
  );
}

export default App;
