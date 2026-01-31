/**
 * timeUtils.js
 * 
 * タイムの変換・計算関連のユーティリティ関数
 */

/**
 * タイム文字列（HH:MM:SS）を秒数に変換
 * @param {string} time - タイム文字列（例: "3:45:30"）
 * @returns {number} 秒数
 */
export const timeToSeconds = (time) => {
  if (!time) return 0;
  const parts = time.split(':').map((p) => parseInt(p, 10));
  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  return 0;
};

/**
 * 秒数をタイム文字列（HH:MM:SS）に変換
 * @param {number} seconds - 秒数
 * @returns {string} タイム文字列
 */
export const secondsToTime = (seconds) => {
  if (!seconds || seconds <= 0) return '0:00:00';
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
};

/**
 * 時、分、秒からタイム文字列を生成
 * @param {number} hours - 時間
 * @param {number} minutes - 分
 * @param {number} seconds - 秒
 * @returns {string} タイム文字列
 */
export const createTimeString = (hours, minutes, seconds) => {
  return `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
};

/**
 * タイム文字列を時、分、秒に分解
 * @param {string} time - タイム文字列
 * @returns {object} { hours, minutes, seconds }
 */
export const parseTimeString = (time) => {
  if (!time) return { hours: 0, minutes: 0, seconds: 0 };
  const parts = time.split(':').map((p) => parseInt(p, 10) || 0);
  return {
    hours: parts[0] || 0,
    minutes: parts[1] || 0,
    seconds: parts[2] || 0,
  };
};

/**
 * ペース（分/km）を計算
 * @param {string} time - タイム文字列
 * @param {number} distance - 距離（km）
 * @returns {string} ペース文字列（例: "5:20"）
 */
export const calculatePace = (time, distance) => {
  if (!time || !distance || distance <= 0) return '-';
  const totalSeconds = timeToSeconds(time);
  const paceSeconds = totalSeconds / distance;
  const paceMinutes = Math.floor(paceSeconds / 60);
  const paceSecs = Math.floor(paceSeconds % 60);
  return `${paceMinutes}:${String(paceSecs).padStart(2, '0')}`;
};

/**
 * 2つのタイムの差分を計算
 * @param {string} time1 - タイム1
 * @param {string} time2 - タイム2
 * @returns {string} 差分（例: "+5:30" or "-5:30"）
 */
export const timeDifference = (time1, time2) => {
  const seconds1 = timeToSeconds(time1);
  const seconds2 = timeToSeconds(time2);
  const diff = seconds1 - seconds2;
  
  if (diff === 0) return '±0:00';
  
  const absDiff = Math.abs(diff);
  const sign = diff > 0 ? '+' : '-';
  const minutes = Math.floor(absDiff / 60);
  const seconds = absDiff % 60;
  
  return `${sign}${minutes}:${String(seconds).padStart(2, '0')}`;
};

/**
 * タイムを比較（ソート用）
 * @param {string} time1 - タイム1
 * @param {string} time2 - タイム2
 * @returns {number} 比較結果
 */
export const compareTime = (time1, time2) => {
  return timeToSeconds(time1) - timeToSeconds(time2);
};
