/**
 * BestRecords.jsx
 * 
 * PB（Personal Best）とSB（Season Best）の表示コンポーネント
 */

import React from 'react';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace, timeDifference } from '../../utils/timeUtils';
import { getDistanceLabel } from '../../utils/calculations';
import { Trophy, Calendar } from 'lucide-react';

/**
 * BestRecordsコンポーネント
 * @param {Object} props
 * @param {Object} props.pbs - 距離別PBデータ
 * @param {Object} props.sbs - 距離別SBデータ
 * @param {number} props.selectedYear - 選択中の年度
 * @param {Function} props.onYearChange - 年度変更ハンドラ
 * @param {Array} props.availableYears - 利用可能な年度一覧
 * @param {Function} props.onRecordClick - 記録クリック時のハンドラ
 */
export const BestRecords = ({
  pbs,
  sbs,
  selectedYear,
  onYearChange,
  availableYears,
  onRecordClick,
}) => {
  const distances = Object.keys(pbs).map(Number).sort((a, b) => b - a);

  return (
    <div className="space-y-8">
      {/* PBセクション */}
      <div>
        <div className="flex items-center gap-2 mb-6">
          <Trophy className="text-yellow-500" size={28} />
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
            自己ベスト記録 (PB)
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {distances.map((distance) => {
            const pb = pbs[distance];
            if (!pb) return null;

            return (
              <div
                key={distance}
                onClick={() => onRecordClick && onRecordClick(pb)}
                className="bg-gradient-to-br from-yellow-50 to-yellow-100 dark:from-yellow-900/20 dark:to-yellow-800/20 rounded-xl p-6 border-2 border-yellow-500/30 cursor-pointer hover:shadow-lg hover:scale-[1.02] transition-all duration-200"
              >
                <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-3">
                  {getDistanceLabel(distance)}
                </h3>
                <div className="space-y-2">
                  <div className="flex items-baseline gap-2">
                    <span className="text-3xl font-bold text-yellow-600 dark:text-yellow-400">
                      {pb.time}
                    </span>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    📅 {pb.name}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    {formatDateShort(pb.date)}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    📊 ペース: {calculatePace(pb.time, pb.distance)}/km
                  </p>
                </div>
                <p className="text-xs text-yellow-600 dark:text-yellow-400 mt-3 text-center">
                  クリックで詳細を表示
                </p>
              </div>
            );
          })}
        </div>

        {distances.length === 0 && (
          <p className="text-center text-gray-500 dark:text-gray-400 py-8">
            まだ記録がありません
          </p>
        )}
      </div>

      {/* SBセクション */}
      <div>
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2">
            <Calendar className="text-gray-500" size={28} />
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
              シーズンベスト記録 (SB)
            </h2>
          </div>

          {/* 年度選択 */}
          <select
            value={selectedYear}
            onChange={(e) => onYearChange(parseInt(e.target.value))}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            {availableYears.map((year) => (
              <option key={year} value={year}>
                {year}年
              </option>
            ))}
          </select>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {distances.map((distance) => {
            const sb = sbs[distance];
            const pb = pbs[distance];

            if (!sb) {
              return (
                <div
                  key={distance}
                  className="bg-gray-100 dark:bg-gray-800 rounded-xl p-6 border border-gray-300 dark:border-gray-700"
                >
                  <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-3">
                    {getDistanceLabel(distance)}
                  </h3>
                  <p className="text-gray-500 dark:text-gray-400">
                    {selectedYear}年の記録なし
                  </p>
                </div>
              );
            }

            const diff = timeDifference(sb.time, pb.time);
            const isNewPB = sb.id === pb.id;

            return (
              <div
                key={distance}
                onClick={() => onRecordClick && onRecordClick(sb)}
                className="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 rounded-xl p-6 border-2 border-blue-500/30 cursor-pointer hover:shadow-lg hover:scale-[1.02] transition-all duration-200"
              >
                <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-3">
                  {getDistanceLabel(distance)}
                </h3>
                <div className="space-y-2">
                  <div className="flex items-baseline gap-2">
                    <span className="text-3xl font-bold text-blue-600 dark:text-blue-400">
                      {sb.time}
                    </span>
                    {isNewPB && (
                      <span className="text-xs font-bold text-yellow-600 dark:text-yellow-400">
                        NEW PB! 🎉
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    📅 {sb.name}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    {formatDateShort(sb.date)}
                  </p>
                  {!isNewPB && (
                    <p
                      className={`text-sm font-medium ${
                        diff.startsWith('+')
                          ? 'text-red-600 dark:text-red-400'
                          : diff.startsWith('-')
                          ? 'text-green-600 dark:text-green-400'
                          : 'text-gray-600 dark:text-gray-400'
                      }`}
                    >
                      PBとの差: {diff}
                    </p>
                  )}
                </div>
                <p className="text-xs text-blue-600 dark:text-blue-400 mt-3 text-center">
                  クリックで詳細を表示
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
