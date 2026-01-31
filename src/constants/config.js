/**
 * config.js
 * 
 * アプリケーション全体で使用する定数を定義
 */

// マラソン距離のプリセット
export const DISTANCE_PRESETS = [
  { value: 42.195, label: 'フルマラソン (42.195km)' },
  { value: 21.0975, label: 'ハーフマラソン (21.0975km)' },
  { value: 10, label: '10km' },
  { value: 5, label: '5km' },
  { value: 3, label: '3km' },
  { value: 'custom', label: 'カスタム' },
];

// 天候アイコンと説明
export const WEATHER_OPTIONS = [
  { icon: '☀️', value: 'sunny', label: '晴れ' },
  { icon: '⛅', value: 'partly-cloudy', label: '晴れ時々曇り' },
  { icon: '☁️', value: 'cloudy', label: '曇り' },
  { icon: '🌧️', value: 'rainy', label: '雨' },
  { icon: '⛈️', value: 'stormy', label: '雷雨' },
  { icon: '🌨️', value: 'snowy', label: '雪' },
];

// 体調評価の絵文字
export const CONDITION_EMOJIS = [
  { value: 1, emoji: '😷', label: '体調不良' },
  { value: 2, emoji: '😞', label: '不調' },
  { value: 3, emoji: '😐', label: '普通' },
  { value: 4, emoji: '😊', label: '良好' },
  { value: 5, emoji: '😄', label: '最高' },
];

// ローカルストレージのキー
export const STORAGE_KEYS = {
  MARATHONS: 'marathon-tracker-marathons',
  THEME: 'marathon-tracker-theme',
  SETTINGS: 'marathon-tracker-settings',
};

// デフォルト設定
export const DEFAULT_SETTINGS = {
  theme: 'light',
  unit: 'km',
  defaultMapCenter: [35.6812, 139.7671], // 東京
  defaultMapZoom: 5,
};

// タブの定義
export const TABS = {
  MAP: 'map',
  RECORDS: 'records',
  STATS: 'stats',
  SETTINGS: 'settings',
};

// マーカーの色
export const MARKER_COLORS = {
  PB: '#FFD700', // 金色
  SB: '#C0C0C0', // 銀色
  NORMAL: '#3b82f6', // 青色
};

// アプリバージョン
export const APP_VERSION = '1.1.0';
