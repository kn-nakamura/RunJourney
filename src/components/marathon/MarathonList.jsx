/**
 * MarathonList.jsx
 *
 * マラソン大会の一覧表示コンポーネント
 * - カード表示とリスト表示の切り替え
 * - 検索機能
 * - フィルタリングとソート
 */

import React, { useState, useMemo } from 'react';
import { MarathonCard } from './MarathonCard';
import { getAvailableYears, getAvailableDistances } from '../../utils/calculations';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace } from '../../utils/timeUtils';
import { Search, Grid, List, Edit } from 'lucide-react';

/**
 * MarathonListコンポーネント
 * @param {Object} props
 * @param {Array} props.marathons - マラソンデータの配列
 * @param {Function} props.onEdit - 編集ハンドラ
 * @param {Function} props.onDelete - 削除ハンドラ
 */
export const MarathonList = ({ marathons, onEdit, onDelete }) => {
  const [sortBy, setSortBy] = useState('date-desc');
  const [filterYear, setFilterYear] = useState('all');
  const [filterDistance, setFilterDistance] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState('card'); // 'card' | 'list'

  const availableYears = useMemo(
    () => getAvailableYears(marathons),
    [marathons]
  );
  const availableDistances = useMemo(
    () => getAvailableDistances(marathons),
    [marathons]
  );

  // フィルタリングとソート
  const filteredAndSortedMarathons = useMemo(() => {
    let result = [...marathons];

    // 検索フィルター
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (m) =>
          m.name.toLowerCase().includes(query) ||
          m.location?.address?.toLowerCase().includes(query) ||
          m.notes?.toLowerCase().includes(query)
      );
    }

    // 年度フィルター
    if (filterYear !== 'all') {
      result = result.filter(
        (m) => new Date(m.date).getFullYear() === parseInt(filterYear)
      );
    }

    // 距離フィルター
    if (filterDistance !== 'all') {
      result = result.filter(
        (m) => m.distance === parseFloat(filterDistance)
      );
    }

    // ソート
    result.sort((a, b) => {
      switch (sortBy) {
        case 'date-desc':
          return new Date(b.date) - new Date(a.date);
        case 'date-asc':
          return new Date(a.date) - new Date(b.date);
        case 'time-asc':
          return (
            a.time.split(':').reduce((acc, val) => acc * 60 + parseInt(val), 0) -
            b.time.split(':').reduce((acc, val) => acc * 60 + parseInt(val), 0)
          );
        case 'time-desc':
          return (
            b.time.split(':').reduce((acc, val) => acc * 60 + parseInt(val), 0) -
            a.time.split(':').reduce((acc, val) => acc * 60 + parseInt(val), 0)
          );
        case 'distance-desc':
          return b.distance - a.distance;
        case 'distance-asc':
          return a.distance - b.distance;
        default:
          return 0;
      }
    });

    return result;
  }, [marathons, sortBy, filterYear, filterDistance, searchQuery]);

  return (
    <div className="space-y-4">
      {/* 検索バー */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="大会名、場所、メモで検索..."
          className="w-full pl-10 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent"
        />
      </div>

      {/* フィルター・ソートコントロール */}
      <div className="flex flex-wrap gap-2 md:gap-4 p-3 md:p-4 bg-gray-100 dark:bg-gray-800 rounded-xl">
        {/* ソート */}
        <div className="flex-1 min-w-[140px]">
          <label className="block text-xs font-medium mb-1 text-gray-600 dark:text-gray-400">並び替え</label>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="date-desc">日付（新しい）</option>
            <option value="date-asc">日付（古い）</option>
            <option value="time-asc">タイム（速い）</option>
            <option value="time-desc">タイム（遅い）</option>
            <option value="distance-desc">距離（長い）</option>
            <option value="distance-asc">距離（短い）</option>
          </select>
        </div>

        {/* 年度フィルター */}
        <div className="flex-1 min-w-[100px]">
          <label className="block text-xs font-medium mb-1 text-gray-600 dark:text-gray-400">年度</label>
          <select
            value={filterYear}
            onChange={(e) => setFilterYear(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="all">全期間</option>
            {availableYears.map((year) => (
              <option key={year} value={year}>
                {year}年
              </option>
            ))}
          </select>
        </div>

        {/* 距離フィルター */}
        <div className="flex-1 min-w-[100px]">
          <label className="block text-xs font-medium mb-1 text-gray-600 dark:text-gray-400">距離</label>
          <select
            value={filterDistance}
            onChange={(e) => setFilterDistance(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="all">全距離</option>
            {availableDistances.map((distance) => (
              <option key={distance} value={distance}>
                {distance === 42.195
                  ? 'フル'
                  : distance === 21.0975
                  ? 'ハーフ'
                  : `${distance}km`}
              </option>
            ))}
          </select>
        </div>

        {/* 表示切替 */}
        <div className="flex items-end gap-1">
          <button
            onClick={() => setViewMode('card')}
            className={`p-2 rounded-lg transition-colors ${
              viewMode === 'card'
                ? 'bg-primary-500 text-white'
                : 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
            }`}
            title="カード表示"
          >
            <Grid size={20} />
          </button>
          <button
            onClick={() => setViewMode('list')}
            className={`p-2 rounded-lg transition-colors ${
              viewMode === 'list'
                ? 'bg-primary-500 text-white'
                : 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
            }`}
            title="リスト表示"
          >
            <List size={20} />
          </button>
        </div>
      </div>

      {/* 大会数表示 */}
      <p className="text-sm text-gray-600 dark:text-gray-400">
        {filteredAndSortedMarathons.length}件の大会
        {searchQuery && ` (「${searchQuery}」で検索)`}
      </p>

      {/* 大会一覧 */}
      {filteredAndSortedMarathons.length > 0 ? (
        viewMode === 'card' ? (
          // カード表示
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
            {filteredAndSortedMarathons.map((marathon) => (
              <MarathonCard
                key={marathon.id}
                marathon={marathon}
                onEdit={onEdit}
                onDelete={onDelete}
              />
            ))}
          </div>
        ) : (
          // リスト表示
          <div className="space-y-2">
            {filteredAndSortedMarathons.map((marathon) => (
              <div
                key={marathon.id}
                id={`marathon-${marathon.id}`}
                className="bg-white dark:bg-gray-800 rounded-lg shadow p-4 flex items-center justify-between gap-3"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    {marathon.isPB && (
                      <span className="text-yellow-500 text-sm flex-shrink-0" title="PB">🏆</span>
                    )}
                    {marathon.isSB && !marathon.isPB && (
                      <span className="text-gray-400 text-sm flex-shrink-0" title="SB">📅</span>
                    )}
                    <span className="font-medium text-gray-900 dark:text-white truncate">
                      {marathon.name}
                    </span>
                  </div>
                  <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-gray-600 dark:text-gray-400">
                    <span>{formatDateShort(marathon.date)}</span>
                    <span>
                      {marathon.distance === 42.195
                        ? 'フル'
                        : marathon.distance === 21.0975
                        ? 'ハーフ'
                        : `${marathon.distance}km`}
                    </span>
                    <span className="font-medium text-gray-900 dark:text-white">{marathon.time}</span>
                    <span>{calculatePace(marathon.time, marathon.distance)}/km</span>
                  </div>
                </div>
                <button
                  onClick={() => onEdit(marathon)}
                  className="p-2 text-gray-500 hover:text-primary-500 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors flex-shrink-0"
                  title="編集"
                >
                  <Edit size={18} />
                </button>
              </div>
            ))}
          </div>
        )
      ) : (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400 text-lg">
            {searchQuery ? '検索結果がありません' : '該当する大会がありません'}
          </p>
        </div>
      )}
    </div>
  );
};
