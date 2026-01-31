/**
 * dateFormat.js
 * 
 * 日付のフォーマット関連のユーティリティ関数
 */

import { format, parseISO } from 'date-fns';
import { ja } from 'date-fns/locale';

/**
 * 日付を "YYYY年MM月DD日" 形式でフォーマット
 * @param {string|Date} date - 日付文字列またはDateオブジェクト
 * @returns {string} フォーマットされた日付文字列
 */
export const formatDate = (date) => {
  if (!date) return '';
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, 'yyyy年MM月dd日', { locale: ja });
};

/**
 * 日付を "YYYY/MM/DD" 形式でフォーマット
 * @param {string|Date} date - 日付文字列またはDateオブジェクト
 * @returns {string} フォーマットされた日付文字列
 */
export const formatDateShort = (date) => {
  if (!date) return '';
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, 'yyyy/MM/dd');
};

/**
 * 日付から年を取得
 * @param {string|Date} date - 日付文字列またはDateオブジェクト
 * @returns {number} 年
 */
export const getYear = (date) => {
  if (!date) return null;
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return dateObj.getFullYear();
};

/**
 * 日付から月を取得（1-12）
 * @param {string|Date} date - 日付文字列またはDateオブジェクト
 * @returns {number} 月
 */
export const getMonth = (date) => {
  if (!date) return null;
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return dateObj.getMonth() + 1;
};

/**
 * ISO形式の日付文字列を取得
 * @param {Date} date - Dateオブジェクト
 * @returns {string} YYYY-MM-DD形式の日付
 */
export const toISODate = (date) => {
  if (!date) return '';
  return format(date, 'yyyy-MM-dd');
};
