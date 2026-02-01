/**
 * MarathonCard.jsx
 * 
 * 個別のマラソン大会情報を表示するカード
 */

import React from 'react';
import { Button } from '../ui/Button';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace } from '../../utils/timeUtils';
import { Edit, Trash2, ExternalLink } from 'lucide-react';

/**
 * MarathonCardコンポーネント
 * @param {Object} props
 * @param {Object} props.marathon - マラソンデータ
 * @param {Function} props.onEdit - 編集ハンドラ
 * @param {Function} props.onDelete - 削除ハンドラ
 */
export const MarathonCard = ({ marathon, onEdit, onDelete }) => {
  const pace = calculatePace(marathon.time, marathon.distance);

  return (
    <div
      id={`marathon-${marathon.id}`}
      className="bg-white dark:bg-gray-800 rounded-xl shadow-lg hover:shadow-xl transition-all overflow-hidden border border-gray-200 dark:border-gray-700"
    >
      {/* 写真またはデフォルト背景 */}
      <div className="relative h-48 bg-gradient-to-br from-primary-400 to-secondary-500">
        {marathon.photo ? (
          <img
            src={marathon.photo}
            alt={marathon.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-white text-6xl">
            🏃
          </div>
        )}

        {/* PB/SBバッジ */}
        <div className="absolute top-3 left-3 flex gap-2">
          {marathon.isPB && (
            <span className="px-3 py-1 bg-yellow-500 text-white font-bold rounded-full text-sm shadow-lg">
              🏆 PB
            </span>
          )}
          {marathon.isSB && !marathon.isPB && (
            <span className="px-3 py-1 bg-gray-400 text-white font-bold rounded-full text-sm shadow-lg">
              📅 SB
            </span>
          )}
        </div>
      </div>

      {/* コンテンツ */}
      <div className="p-5">
        {/* タイトル */}
        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">
          {marathon.name}
        </h3>

        {/* 日付 */}
        <p className="text-gray-600 dark:text-gray-400 text-sm mb-4">
          📅 {formatDateShort(marathon.date)}
        </p>

        {/* 主要データ */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-sm text-gray-500 dark:text-gray-400">距離</p>
            <p className="text-lg font-semibold text-gray-900 dark:text-white">
              {marathon.distance}km
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-500 dark:text-gray-400">タイム</p>
            <p className="text-lg font-semibold text-gray-900 dark:text-white">
              {marathon.time}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-500 dark:text-gray-400">ペース</p>
            <p className="text-lg font-semibold text-gray-900 dark:text-white">
              {pace}/km
            </p>
          </div>
          {marathon.rank && (
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">順位</p>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">
                {marathon.rank}位
              </p>
            </div>
          )}
        </div>

        {/* 天候・体調 */}
        {(marathon.weather || marathon.condition) && (
          <div className="flex gap-4 mb-4 text-sm">
            {marathon.weather && (
              <span className="flex items-center gap-1">
                {marathon.weather.icon} {marathon.weather.description}
                {marathon.weather.temperature && (
                  <span className="text-gray-600 dark:text-gray-400">
                    {marathon.weather.temperature}℃
                  </span>
                )}
              </span>
            )}
            {marathon.condition && (
              <span className="flex items-center gap-1">
                {marathon.condition.physicalEmoji} 体調
              </span>
            )}
          </div>
        )}

        {/* 外部リンク */}
        {(marathon.externalLinks?.strava || marathon.externalLinks?.garmin) && (
          <div className="flex gap-2 mb-4">
            {marathon.externalLinks.strava && (
              <a
                href={marathon.externalLinks.strava}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1 px-3 py-1 bg-orange-500 text-white text-sm rounded-lg hover:bg-orange-600 transition-colors"
              >
                📊 STRAVA <ExternalLink size={14} />
              </a>
            )}
            {marathon.externalLinks.garmin && (
              <a
                href={marathon.externalLinks.garmin}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1 px-3 py-1 bg-blue-500 text-white text-sm rounded-lg hover:bg-blue-600 transition-colors"
              >
                ⌚ Garmin <ExternalLink size={14} />
              </a>
            )}
          </div>
        )}

        {/* メモ */}
        {marathon.notes && (
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-4 line-clamp-2">
            📝 {marathon.notes}
          </p>
        )}

        {/* アクションボタン - 編集アイコンのみ */}
        <div className="flex justify-end pt-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={() => onEdit(marathon)}
            className="p-2 text-gray-500 hover:text-primary-500 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
            title="編集"
          >
            <Edit size={18} />
          </button>
        </div>
      </div>
    </div>
  );
};
