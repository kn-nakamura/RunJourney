/**
 * useLocalStorage.js
 * 
 * LocalStorageを簡単に使うためのカスタムフック
 */

import { useState, useEffect } from 'react';

/**
 * LocalStorageと同期するステートフック
 * @param {string} key - LocalStorageのキー
 * @param {any} initialValue - 初期値
 * @returns {Array} [value, setValue]
 */
export const useLocalStorage = (key, initialValue) => {
  // ステートの初期化
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Error loading ${key} from localStorage:`, error);
      return initialValue;
    }
  });

  // 値が変更されたらLocalStorageに保存
  useEffect(() => {
    try {
      window.localStorage.setItem(key, JSON.stringify(storedValue));
    } catch (error) {
      console.error(`Error saving ${key} to localStorage:`, error);
    }
  }, [key, storedValue]);

  return [storedValue, setStoredValue];
};
