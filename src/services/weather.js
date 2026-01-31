/**
 * weather.js
 *
 * Open-Meteo APIを使用した過去の天候データ取得サービス
 */

const OPEN_METEO_FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const OPEN_METEO_ARCHIVE_URL = 'https://archive-api.open-meteo.com/v1/archive';

/**
 * 天候アイコンを判定
 * @param {number} precipitation - 降水量（mm）
 * @param {number} cloudCover - 雲量（%）
 * @returns {string} 天候値
 */
const determineWeatherIcon = (precipitation, cloudCover = 50) => {
  if (precipitation > 10) return 'rainy';
  if (precipitation > 0) return 'partly-cloudy';
  if (cloudCover > 70) return 'cloudy';
  if (cloudCover > 30) return 'partly-cloudy';
  return 'sunny';
};

/**
 * 天候の説明を取得
 * @param {string} weatherValue - 天候値
 * @returns {string} 天候の説明
 */
const getWeatherDescription = (weatherValue) => {
  const descriptions = {
    sunny: '晴れ',
    'partly-cloudy': '晴れ時々曇り',
    cloudy: '曇り',
    rainy: '雨',
    stormy: '雷雨',
    snowy: '雪',
  };
  return descriptions[weatherValue] || '不明';
};

/**
 * 天候アイコンを取得
 * @param {string} weatherValue - 天候値
 * @returns {string} 天候アイコン
 */
const getWeatherIcon = (weatherValue) => {
  const icons = {
    sunny: '☀️',
    'partly-cloudy': '⛅',
    cloudy: '☁️',
    rainy: '🌧️',
    stormy: '⛈️',
    snowy: '🌨️',
  };
  return icons[weatherValue] || '☀️';
};

/**
 * 日付が過去かどうかを判定（予報APIの範囲外かどうか）
 * @param {string} date - 日付（YYYY-MM-DD形式）
 * @returns {boolean} 過去の日付かどうか
 */
const isHistoricalDate = (date) => {
  const targetDate = new Date(date);
  const today = new Date();
  // 7日前より古いデータはarchive APIを使用
  const threshold = new Date(today);
  threshold.setDate(today.getDate() - 7);
  return targetDate < threshold;
};

/**
 * 指定日の天候データを取得
 * @param {number} lat - 緯度
 * @param {number} lng - 経度
 * @param {string} date - 日付（YYYY-MM-DD形式）
 * @returns {Promise<Object>} 天候データ
 */
export const fetchWeatherData = async (lat, lng, date) => {
  if (!lat || !lng || !date) {
    throw new Error('Invalid parameters');
  }

  try {
    // 過去のデータかどうかでAPIエンドポイントを選択
    const isHistorical = isHistoricalDate(date);
    const baseUrl = isHistorical ? OPEN_METEO_ARCHIVE_URL : OPEN_METEO_FORECAST_URL;

    const response = await fetch(
      `${baseUrl}?` +
        new URLSearchParams({
          latitude: lat.toString(),
          longitude: lng.toString(),
          start_date: date,
          end_date: date,
          daily:
            'temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode',
          timezone: 'Asia/Tokyo',
        })
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Weather API error:', errorText);
      throw new Error('Failed to fetch weather data');
    }

    const data = await response.json();

    if (!data.daily || !data.daily.temperature_2m_max || data.daily.temperature_2m_max[0] === null) {
      throw new Error('No weather data available for this date');
    }

    const tempMax = Math.round(data.daily.temperature_2m_max[0]);
    const tempMin = Math.round(data.daily.temperature_2m_min[0]);
    const precipitation = data.daily.precipitation_sum[0] || 0;

    // 天候を判定
    const weatherValue = determineWeatherIcon(precipitation);

    return {
      icon: getWeatherIcon(weatherValue),
      description: getWeatherDescription(weatherValue),
      temperature: tempMax,
      temperatureRange: {
        min: tempMin,
        max: tempMax,
      },
      humidity: null, // Open-Meteoの無料版では取得不可
      precipitation: precipitation,
      autoFetched: true,
    };
  } catch (error) {
    console.error('Weather data fetch error:', error);
    throw error;
  }
};
