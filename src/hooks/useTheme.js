/**
 * useTheme.js
 * 
 * ダークモード/ライトモードを管理するカスタムフック
 */

import { useEffect } from 'react';
import { useLocalStorage } from './useLocalStorage';
import { STORAGE_KEYS } from '../constants/config';

/**
 * テーマ管理フック
 * @returns {Object} { theme, toggleTheme }
 */
export const useTheme = () => {
  const [theme, setTheme] = useLocalStorage(STORAGE_KEYS.THEME, 'light');

  useEffect(() => {
    // HTMLのクラスを更新
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prevTheme) => (prevTheme === 'light' ? 'dark' : 'light'));
  };

  return { theme, toggleTheme };
};
