/**
 * App.jsx
 *
 * メインアプリケーションコンポーネント
 * Firebase認証対応
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
import { AuthModal } from './components/auth/AuthModal';
import { useMarathons } from './hooks/useMarathons';
import { useTheme } from './hooks/useTheme';
import { useAuth, AuthProvider } from './hooks/useAuth';
import { getAvailableYears } from './utils/calculations';
import { Map, FileText, BarChart3, Settings, Plus, LogIn, LogOut, User, Cloud, CloudOff, Upload } from 'lucide-react';
import { TABS } from './constants/config';

function AppContent() {
  const [activeTab, setActiveTab] = useState(TABS.MAP);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingMarathon, setEditingMarathon] = useState(null);
  const [recordsSubTab, setRecordsSubTab] = useState('best'); // 'best' or 'list'
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);

  const { theme, toggleTheme } = useTheme();
  const {
    user,
    loading: authLoading,
    error: authError,
    firebaseEnabled,
    login,
    register,
    loginWithGoogle,
    signOut,
    clearError
  } = useAuth();

  const {
    marathons,
    rawMarathons,
    addMarathon,
    updateMarathon,
    deleteMarathon,
    clearAllMarathons,
    importMarathons,
    migrateToFirebase,
    pbs,
    sbs,
    selectedYear,
    setSelectedYear,
    loading: dataLoading,
    useFirebase,
    hasLocalData
  } = useMarathons(user);

  const availableYears = getAvailableYears(marathons);

  // タブ定義
  const tabs = [
    { id: TABS.MAP, label: 'マップ', icon: Map },
    { id: TABS.RECORDS, label: '記録', icon: FileText },
    { id: TABS.STATS, label: 'グラフ', icon: BarChart3 },
    { id: TABS.SETTINGS, label: '設定', icon: Settings },
  ];

  // フォーム送信
  const handleFormSubmit = async (marathonData) => {
    if (editingMarathon) {
      await updateMarathon(editingMarathon.id, marathonData);
      setEditingMarathon(null);
    } else {
      await addMarathon(marathonData);
    }
    setIsFormOpen(false);
  };

  // 編集開始
  const handleEdit = (marathon) => {
    setEditingMarathon(marathon);
    setIsFormOpen(true);
  };

  // 削除
  const handleDelete = async (id) => {
    if (window.confirm('この大会を削除しますか？')) {
      await deleteMarathon(id);
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
  const handleImport = async (importedMarathons, merge) => {
    await importMarathons(importedMarathons, merge);
  };

  // データ移行
  const handleMigrate = async () => {
    if (window.confirm('ローカルデータをクラウドに移行しますか？移行後、ローカルデータは削除されます。')) {
      try {
        await migrateToFirebase();
        alert('データの移行が完了しました！');
      } catch (err) {
        alert('移行に失敗しました: ' + err.message);
      }
    }
  };

  // ログアウト
  const handleLogout = async () => {
    if (window.confirm('ログアウトしますか？')) {
      await signOut();
    }
  };

  // 認証読み込み中
  if (authLoading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p className="text-gray-500 dark:text-gray-400">読み込み中...</p>
        </div>
      </div>
    );
  }

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
              <div>
                <h1 className="text-2xl md:text-3xl font-bold bg-gradient-to-r from-primary-600 to-secondary-600 bg-clip-text text-transparent">
                  マラソントラッカー
                </h1>
                {/* 同期状態表示 */}
                {firebaseEnabled && (
                  <div className="flex items-center gap-1 text-xs">
                    {user ? (
                      <span className="flex items-center gap-1 text-green-600 dark:text-green-400">
                        <Cloud size={12} />
                        クラウド同期中
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                        <CloudOff size={12} />
                        ローカル保存
                      </span>
                    )}
                  </div>
                )}
              </div>
            </div>

            <div className="flex items-center gap-2">
              {/* データ移行ボタン */}
              {user && hasLocalData && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleMigrate}
                  className="hidden md:flex"
                >
                  <Upload size={16} className="mr-1" />
                  データ移行
                </Button>
              )}

              {/* ユーザー情報 / ログインボタン */}
              {firebaseEnabled && (
                user ? (
                  <div className="flex items-center gap-2">
                    <div className="hidden md:flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                      <User size={16} />
                      <span className="max-w-[120px] truncate">{user.email}</span>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={handleLogout}
                    >
                      <LogOut size={18} />
                    </Button>
                  </div>
                ) : (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setIsAuthModalOpen(true)}
                  >
                    <LogIn size={16} className="mr-1" />
                    ログイン
                  </Button>
                )
              )}

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
        </div>

        {/* タブナビゲーション */}
        <Tabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />
      </header>

      {/* メインコンテンツ */}
      <main className="container mx-auto px-4 py-6">
        {/* データ読み込み中 */}
        {dataLoading && (
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500 mr-3"></div>
            <span className="text-gray-500 dark:text-gray-400">データを読み込み中...</span>
          </div>
        )}

        {/* マップタブ */}
        {activeTab === TABS.MAP && !dataLoading && (
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
        {activeTab === TABS.RECORDS && !dataLoading && (
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
        {activeTab === TABS.STATS && !dataLoading && (
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
        {activeTab === TABS.SETTINGS && !dataLoading && (
          <div className="animate-fade-in">
            <SettingsView
              marathons={rawMarathons}
              onImport={handleImport}
              onClearAll={clearAllMarathons}
              theme={theme}
              onThemeToggle={toggleTheme}
              user={user}
              useFirebase={useFirebase}
              hasLocalData={hasLocalData}
              onMigrate={handleMigrate}
              onLogin={() => setIsAuthModalOpen(true)}
              onLogout={handleLogout}
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

      {/* 認証モーダル */}
      {firebaseEnabled && (
        <AuthModal
          isOpen={isAuthModalOpen}
          onClose={() => setIsAuthModalOpen(false)}
          onLogin={login}
          onRegister={register}
          onGoogleLogin={loginWithGoogle}
          error={authError}
          onClearError={clearError}
        />
      )}
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
