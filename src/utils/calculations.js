/**
 * calculations.js
 * 
 * PB/SB計算などのビジネスロジック
 */

import { timeToSeconds } from './timeUtils';
import { getYear } from './dateFormat';

/**
 * 距離別のPB（Personal Best）を計算
 * @param {Array} marathons - マラソンデータの配列
 * @returns {Object} 距離をキーとしたPBオブジェクト
 */
export const calculatePBs = (marathons) => {
  if (!marathons || marathons.length === 0) return {};

  const pbByDistance = {};

  marathons.forEach((marathon) => {
    const distance = marathon.distance;
    const currentPB = pbByDistance[distance];

    if (
      !currentPB ||
      timeToSeconds(marathon.time) < timeToSeconds(currentPB.time)
    ) {
      pbByDistance[distance] = marathon;
    }
  });

  return pbByDistance;
};

/**
 * 指定年度の距離別SB（Season Best）を計算
 * @param {Array} marathons - マラソンデータの配列
 * @param {number} year - 年度
 * @returns {Object} 距離をキーとしたSBオブジェクト
 */
export const calculateSBs = (marathons, year) => {
  if (!marathons || marathons.length === 0) return {};

  const yearMarathons = marathons.filter((m) => getYear(m.date) === year);
  const sbByDistance = {};

  yearMarathons.forEach((marathon) => {
    const distance = marathon.distance;
    const currentSB = sbByDistance[distance];

    if (
      !currentSB ||
      timeToSeconds(marathon.time) < timeToSeconds(currentSB.time)
    ) {
      sbByDistance[distance] = marathon;
    }
  });

  return sbByDistance;
};

/**
 * マラソンデータにPB/SBフラグを付与
 * @param {Array} marathons - マラソンデータの配列
 * @param {number} selectedYear - 選択された年度
 * @returns {Array} フラグ付きマラソンデータ
 */
export const addBestFlags = (marathons, selectedYear) => {
  const pbs = calculatePBs(marathons);
  const sbs = calculateSBs(marathons, selectedYear);

  return marathons.map((marathon) => ({
    ...marathon,
    isPB: pbs[marathon.distance]?.id === marathon.id,
    isSB: sbs[marathon.distance]?.id === marathon.id,
  }));
};

/**
 * 統計データを計算
 * @param {Array} marathons - マラソンデータの配列
 * @returns {Object} 統計情報
 */
export const calculateStats = (marathons) => {
  if (!marathons || marathons.length === 0) {
    return {
      totalRaces: 0,
      totalDistance: 0,
      distanceCounts: {},
      monthCounts: {},
    };
  }

  const distanceCounts = {};
  const monthCounts = {};
  let totalDistance = 0;

  marathons.forEach((marathon) => {
    // 距離別カウント
    const distKey = marathon.distance;
    distanceCounts[distKey] = (distanceCounts[distKey] || 0) + 1;

    // 総距離
    totalDistance += marathon.distance;

    // 月別カウント
    const month = new Date(marathon.date).getMonth() + 1;
    monthCounts[month] = (monthCounts[month] || 0) + 1;
  });

  return {
    totalRaces: marathons.length,
    totalDistance: Math.round(totalDistance * 100) / 100,
    distanceCounts,
    monthCounts,
  };
};

/**
 * 利用可能な年度一覧を取得
 * @param {Array} marathons - マラソンデータの配列
 * @returns {Array} 年度の配列（降順）
 */
export const getAvailableYears = (marathons) => {
  if (!marathons || marathons.length === 0) return [];

  const years = marathons.map((m) => getYear(m.date));
  const uniqueYears = [...new Set(years)].sort((a, b) => b - a);
  return uniqueYears;
};

/**
 * 利用可能な距離一覧を取得
 * @param {Array} marathons - マラソンデータの配列
 * @returns {Array} 距離の配列（降順）
 */
export const getAvailableDistances = (marathons) => {
  if (!marathons || marathons.length === 0) return [];

  const distances = marathons.map((m) => m.distance);
  const uniqueDistances = [...new Set(distances)].sort((a, b) => b - a);
  return uniqueDistances;
};

/**
 * 距離のラベルを取得
 * @param {number} distance - 距離
 * @returns {string} ラベル
 */
export const getDistanceLabel = (distance) => {
  if (distance === 42.195) return 'フルマラソン';
  if (distance === 21.0975) return 'ハーフマラソン';
  return `${distance}km`;
};
