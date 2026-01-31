/**
 * ChartsView.jsx
 * 
 * Chart.jsを使用した統計グラフ表示コンポーネント
 */

import React, { useMemo } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import { Line, Bar } from 'react-chartjs-2';
import { timeToSeconds, secondsToTime } from '../../utils/timeUtils';
import { formatDateShort } from '../../utils/dateFormat';
import { getDistanceLabel, calculateStats } from '../../utils/calculations';

/**
 * 秒数を距離に適したフォーマットの時間文字列に変換
 * @param {number} seconds - 秒数
 * @param {number} distance - 距離（km）
 * @returns {string} フォーマットされた時間文字列
 */
const formatTimeForDistance = (seconds, distance) => {
  if (!seconds || seconds <= 0) return '0:00:00';

  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  // フルマラソン、ハーフマラソン、10km以上は時:分:秒
  if (distance >= 10) {
    if (hours > 0) {
      return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }
    return `${minutes}:${String(secs).padStart(2, '0')}`;
  }

  // 短距離は分:秒
  return `${minutes}:${String(secs).padStart(2, '0')}`;
};

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend
);

/**
 * ChartsViewコンポーネント
 * @param {Object} props
 * @param {Array} props.marathons - マラソンデータの配列
 */
export const ChartsView = ({ marathons }) => {
  const [selectedDistance, setSelectedDistance] = React.useState('all');

  // 利用可能な距離一覧
  const availableDistances = useMemo(() => {
    const distances = marathons.map((m) => m.distance);
    return [...new Set(distances)].sort((a, b) => b - a);
  }, [marathons]);

  // フィルタリングされたマラソンデータ
  const filteredMarathons = useMemo(() => {
    if (selectedDistance === 'all') return marathons;
    return marathons.filter(
      (m) => m.distance === parseFloat(selectedDistance)
    );
  }, [marathons, selectedDistance]);

  // フィルターされた距離を取得（グラフ表示用）
  const currentDistance = useMemo(() => {
    if (selectedDistance === 'all') {
      // 全距離の場合は最大距離を使用
      return filteredMarathons.length > 0
        ? Math.max(...filteredMarathons.map((m) => m.distance))
        : 42.195;
    }
    return parseFloat(selectedDistance);
  }, [selectedDistance, filteredMarathons]);

  // タイム推移グラフデータ
  const timeProgressionData = useMemo(() => {
    const sorted = [...filteredMarathons].sort(
      (a, b) => new Date(a.date) - new Date(b.date)
    );

    return {
      labels: sorted.map((m) => formatDateShort(m.date)),
      datasets: [
        {
          label: 'タイム',
          data: sorted.map((m) => timeToSeconds(m.time)),
          borderColor: 'rgb(249, 115, 22)',
          backgroundColor: 'rgba(249, 115, 22, 0.5)',
          tension: 0.3,
        },
      ],
    };
  }, [filteredMarathons]);

  // 距離別参加回数グラフデータ
  const distanceCountData = useMemo(() => {
    const stats = calculateStats(marathons);
    const distanceLabels = Object.keys(stats.distanceCounts)
      .map(Number)
      .sort((a, b) => b - a)
      .map(getDistanceLabel);
    const counts = Object.keys(stats.distanceCounts)
      .map(Number)
      .sort((a, b) => b - a)
      .map((d) => stats.distanceCounts[d]);

    return {
      labels: distanceLabels,
      datasets: [
        {
          label: '参加回数',
          data: counts,
          backgroundColor: [
            'rgba(59, 130, 246, 0.8)',
            'rgba(249, 115, 22, 0.8)',
            'rgba(34, 197, 94, 0.8)',
            'rgba(168, 85, 247, 0.8)',
            'rgba(236, 72, 153, 0.8)',
          ],
        },
      ],
    };
  }, [marathons]);

  // 月別参加回数グラフデータ
  const monthlyCountData = useMemo(() => {
    const stats = calculateStats(marathons);
    const monthLabels = Array.from({ length: 12 }, (_, i) => `${i + 1}月`);
    const counts = Array.from(
      { length: 12 },
      (_, i) => stats.monthCounts[i + 1] || 0
    );

    return {
      labels: monthLabels,
      datasets: [
        {
          label: '参加回数',
          data: counts,
          backgroundColor: 'rgba(59, 130, 246, 0.8)',
        },
      ],
    };
  }, [marathons]);

  // 統計サマリー
  const stats = useMemo(() => calculateStats(marathons), [marathons]);

  // 基本チャートオプション（距離別参加回数、月別参加回数用）
  const baseChartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: true,
        labels: {
          color: document.documentElement.classList.contains('dark')
            ? '#e5e7eb'
            : '#1f2937',
        },
      },
    },
    scales: {
      y: {
        ticks: {
          color: document.documentElement.classList.contains('dark')
            ? '#9ca3af'
            : '#6b7280',
        },
        grid: {
          color: document.documentElement.classList.contains('dark')
            ? '#374151'
            : '#e5e7eb',
        },
      },
      x: {
        ticks: {
          color: document.documentElement.classList.contains('dark')
            ? '#9ca3af'
            : '#6b7280',
        },
        grid: {
          color: document.documentElement.classList.contains('dark')
            ? '#374151'
            : '#e5e7eb',
        },
      },
    },
  };

  // タイム推移グラフ用オプション（Y軸を時間形式で表示）
  const timeChartOptions = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          labels: {
            color: document.documentElement.classList.contains('dark')
              ? '#e5e7eb'
              : '#1f2937',
          },
        },
        tooltip: {
          callbacks: {
            label: (context) => {
              const seconds = context.raw;
              return `タイム: ${formatTimeForDistance(seconds, currentDistance)}`;
            },
          },
        },
      },
      scales: {
        y: {
          reverse: true, // 速いタイムが上になるように
          ticks: {
            color: document.documentElement.classList.contains('dark')
              ? '#9ca3af'
              : '#6b7280',
            callback: (value) => formatTimeForDistance(value, currentDistance),
          },
          grid: {
            color: document.documentElement.classList.contains('dark')
              ? '#374151'
              : '#e5e7eb',
          },
        },
        x: {
          ticks: {
            color: document.documentElement.classList.contains('dark')
              ? '#9ca3af'
              : '#6b7280',
          },
          grid: {
            color: document.documentElement.classList.contains('dark')
              ? '#374151'
              : '#e5e7eb',
          },
        },
      },
    }),
    [currentDistance]
  );

  return (
    <div className="space-y-8">
      {/* 距離フィルター */}
      <div className="flex items-center gap-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-xl">
        <label className="text-sm font-medium">距離:</label>
        <select
          value={selectedDistance}
          onChange={(e) => setSelectedDistance(e.target.value)}
          className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
        >
          <option value="all">全距離</option>
          {availableDistances.map((distance) => (
            <option key={distance} value={distance}>
              {getDistanceLabel(distance)}
            </option>
          ))}
        </select>
      </div>

      {/* タイム推移グラフ */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          タイム推移
        </h3>
        <p className="text-sm text-gray-500 dark:text-gray-400 mb-2">
          ※上にあるほど速いタイム
        </p>
        <div className="h-80">
          <Line data={timeProgressionData} options={timeChartOptions} />
        </div>
      </div>

      {/* 距離別参加回数 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          距離別参加回数
        </h3>
        <div className="h-80">
          <Bar data={distanceCountData} options={baseChartOptions} />
        </div>
      </div>

      {/* 月別参加回数 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          月別参加回数
        </h3>
        <div className="h-80">
          <Bar data={monthlyCountData} options={baseChartOptions} />
        </div>
      </div>

      {/* 統計サマリー */}
      <div className="bg-gradient-to-br from-primary-50 to-secondary-50 dark:from-primary-900/20 dark:to-secondary-900/20 rounded-xl p-6 border-2 border-primary-500/30">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          📊 統計サマリー
        </h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">総大会数</p>
            <p className="text-2xl font-bold text-gray-900 dark:text-white">
              {stats.totalRaces}回
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">総距離</p>
            <p className="text-2xl font-bold text-gray-900 dark:text-white">
              {stats.totalDistance}km
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">最多参加月</p>
            <p className="text-2xl font-bold text-gray-900 dark:text-white">
              {Object.keys(stats.monthCounts).length > 0
                ? `${Object.entries(stats.monthCounts).sort(
                    (a, b) => b[1] - a[1]
                  )[0][0]}月`
                : '-'}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">種目数</p>
            <p className="text-2xl font-bold text-gray-900 dark:text-white">
              {Object.keys(stats.distanceCounts).length}種目
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
