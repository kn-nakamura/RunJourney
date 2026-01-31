/**
 * storage.js
 * 
 * LocalStorageを使用したデータ永続化サービス
 */

import { STORAGE_KEYS } from '../constants/config';

/**
 * マラソンデータを保存
 * @param {Array} marathons - マラソンデータの配列
 */
export const saveMarathons = (marathons) => {
  try {
    localStorage.setItem(STORAGE_KEYS.MARATHONS, JSON.stringify(marathons));
  } catch (error) {
    console.error('Failed to save marathons:', error);
  }
};

/**
 * マラソンデータを読み込み
 * @returns {Array} マラソンデータの配列
 */
export const loadMarathons = () => {
  try {
    const data = localStorage.getItem(STORAGE_KEYS.MARATHONS);
    return data ? JSON.parse(data) : [];
  } catch (error) {
    console.error('Failed to load marathons:', error);
    return [];
  }
};

/**
 * 設定を保存
 * @param {Object} settings - 設定オブジェクト
 */
export const saveSettings = (settings) => {
  try {
    localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(settings));
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
};

/**
 * 設定を読み込み
 * @returns {Object} 設定オブジェクト
 */
export const loadSettings = () => {
  try {
    const data = localStorage.getItem(STORAGE_KEYS.SETTINGS);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Failed to load settings:', error);
    return null;
  }
};

/**
 * テーマを保存
 * @param {string} theme - テーマ（'light' or 'dark'）
 */
export const saveTheme = (theme) => {
  try {
    localStorage.setItem(STORAGE_KEYS.THEME, theme);
  } catch (error) {
    console.error('Failed to save theme:', error);
  }
};

/**
 * テーマを読み込み
 * @returns {string} テーマ
 */
export const loadTheme = () => {
  try {
    return localStorage.getItem(STORAGE_KEYS.THEME) || 'light';
  } catch (error) {
    console.error('Failed to load theme:', error);
    return 'light';
  }
};

/**
 * すべてのデータを削除
 */
export const clearAllData = () => {
  try {
    localStorage.removeItem(STORAGE_KEYS.MARATHONS);
    localStorage.removeItem(STORAGE_KEYS.SETTINGS);
    // テーマは残す
  } catch (error) {
    console.error('Failed to clear data:', error);
  }
};

/**
 * データをJSONとしてエクスポート
 * @param {Array} marathons - マラソンデータ
 * @param {Object} settings - 設定データ
 * @returns {Object} エクスポートデータ
 */
export const exportData = (marathons, settings) => {
  return {
    version: '1.0',
    exportDate: new Date().toISOString(),
    marathons,
    settings,
  };
};

/**
 * JSONデータをインポート
 * @param {Object} data - インポートデータ
 * @returns {Object} { marathons, settings }
 */
export const importData = (data) => {
  try {
    if (!data.marathons) {
      throw new Error('Invalid data format');
    }
    return {
      marathons: data.marathons || [],
      settings: data.settings || null,
    };
  } catch (error) {
    console.error('Failed to import data:', error);
    throw error;
  }
};
