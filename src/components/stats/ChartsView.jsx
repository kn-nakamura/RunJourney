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
import { timeToSeconds } from '../../utils/timeUtils';
import { formatDateShort } from '../../utils/dateFormat';
import { getDistanceLabel, calculateStats } from '../../utils/calculations';

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

  // タイム推移グラフデータ
  const timeProgressionData = useMemo(() => {
    const sorted = [...filteredMarathons].sort(
      (a, b) => new Date(a.date) - new Date(b.date)
    );

    return {
      labels: sorted.map((m) => formatDateShort(m.date)),
      datasets: [
        {
          label: 'タイム（秒）',
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

  const chartOptions = {
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
        <div className="h-80">
          <Line data={timeProgressionData} options={chartOptions} />
        </div>
      </div>

      {/* 距離別参加回数 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          距離別参加回数
        </h3>
        <div className="h-80">
          <Bar data={distanceCountData} options={chartOptions} />
        </div>
      </div>

      {/* 月別参加回数 */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-lg">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
          月別参加回数
        </h3>
        <div className="h-80">
          <Bar data={monthlyCountData} options={chartOptions} />
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
