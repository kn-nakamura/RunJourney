/**
 * MarathonList.jsx
 * 
 * マラソン大会の一覧表示コンポーネント
 */

import React, { useState, useMemo } from 'react';
import { MarathonCard } from './MarathonCard';
import { getAvailableYears, getAvailableDistances } from '../../utils/calculations';

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

    // フィルタリング
    if (filterYear !== 'all') {
      result = result.filter(
        (m) => new Date(m.date).getFullYear() === parseInt(filterYear)
      );
    }
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
  }, [marathons, sortBy, filterYear, filterDistance]);

  return (
    <div className="space-y-6">
      {/* フィルター・ソートコントロール */}
      <div className="flex flex-wrap gap-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-xl">
        {/* ソート */}
        <div className="flex-1 min-w-[200px]">
          <label className="block text-sm font-medium mb-2">並び替え</label>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="date-desc">日付順（新しい）</option>
            <option value="date-asc">日付順（古い）</option>
            <option value="time-asc">タイム順（速い）</option>
            <option value="time-desc">タイム順（遅い）</option>
            <option value="distance-desc">距離順（長い）</option>
            <option value="distance-asc">距離順（短い）</option>
          </select>
        </div>

        {/* 年度フィルター */}
        <div className="flex-1 min-w-[150px]">
          <label className="block text-sm font-medium mb-2">年度</label>
          <select
            value={filterYear}
            onChange={(e) => setFilterYear(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
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
        <div className="flex-1 min-w-[150px]">
          <label className="block text-sm font-medium mb-2">距離</label>
          <select
            value={filterDistance}
            onChange={(e) => setFilterDistance(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="all">全距離</option>
            {availableDistances.map((distance) => (
              <option key={distance} value={distance}>
                {distance === 42.195
                  ? 'フルマラソン'
                  : distance === 21.0975
                  ? 'ハーフマラソン'
                  : `${distance}km`}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* 大会数表示 */}
      <p className="text-sm text-gray-600 dark:text-gray-400">
        {filteredAndSortedMarathons.length}件の大会
      </p>

      {/* カード一覧 */}
      {filteredAndSortedMarathons.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
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
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400 text-lg">
            該当する大会がありません
          </p>
        </div>
      )}
    </div>
  );
};
