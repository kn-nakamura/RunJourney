/**
 * useMarathons.js
 * 
 * マラソンデータの管理と操作を行うカスタムフック
 */

import { useState, useMemo } from 'react';
import { useLocalStorage } from './useLocalStorage';
import { STORAGE_KEYS } from '../constants/config';
import { addBestFlags, calculatePBs, calculateSBs } from '../utils/calculations';

/**
 * マラソンデータ管理フック
 * @returns {Object} マラソン管理機能
 */
export const useMarathons = () => {
  const [marathons, setMarathons] = useLocalStorage(
    STORAGE_KEYS.MARATHONS,
    []
  );
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());

  /**
   * 新しいマラソンを追加
   * @param {Object} marathon - マラソンデータ
   */
  const addMarathon = (marathon) => {
    const newMarathon = {
      ...marathon,
      id: `marathon-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      createdAt: new Date().toISOString(),
    };
    setMarathons([...marathons, newMarathon]);
  };

  /**
   * マラソンを更新
   * @param {string} id - マラソンID
   * @param {Object} updates - 更新データ
   */
  const updateMarathon = (id, updates) => {
    setMarathons(
      marathons.map((m) =>
        m.id === id ? { ...m, ...updates, updatedAt: new Date().toISOString() } : m
      )
    );
  };

  /**
   * マラソンを削除
   * @param {string} id - マラソンID
   */
  const deleteMarathon = (id) => {
    setMarathons(marathons.filter((m) => m.id !== id));
  };

  /**
   * すべてのマラソンを削除
   */
  const clearAllMarathons = () => {
    setMarathons([]);
  };

  /**
   * マラソンデータをインポート
   * @param {Array} importedMarathons - インポートするマラソンデータ
   * @param {boolean} merge - 既存データとマージするか
   */
  const importMarathons = (importedMarathons, merge = false) => {
    if (merge) {
      // マージ: 既存データに追加
      const newMarathons = importedMarathons.map((m) => ({
        ...m,
        id: m.id || `marathon-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      }));
      setMarathons([...marathons, ...newMarathons]);
    } else {
      // 上書き: すべて置き換え
      setMarathons(importedMarathons);
    }
  };

  // PB/SBフラグ付きマラソンデータ
  const marathonsWithFlags = useMemo(
    () => addBestFlags(marathons, selectedYear),
    [marathons, selectedYear]
  );

  // PB計算
  const pbs = useMemo(() => calculatePBs(marathons), [marathons]);

  // SB計算
  const sbs = useMemo(
    () => calculateSBs(marathons, selectedYear),
    [marathons, selectedYear]
  );

  return {
    marathons: marathonsWithFlags,
    rawMarathons: marathons,
    addMarathon,
    updateMarathon,
    deleteMarathon,
    clearAllMarathons,
    importMarathons,
    pbs,
    sbs,
    selectedYear,
    setSelectedYear,
  };
};
