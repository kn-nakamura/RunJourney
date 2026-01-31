/**
 * geocoding.js
 * 
 * Nominatim APIを使用した住所検索サービス
 */

const NOMINATIM_BASE_URL = 'https://nominatim.openstreetmap.org';

/**
 * 住所から座標を検索
 * @param {string} query - 検索クエリ（住所、施設名など）
 * @returns {Promise<Array>} 検索結果の配列
 */
export const searchLocation = async (query) => {
  if (!query || query.trim() === '') {
    return [];
  }

  try {
    const response = await fetch(
      `${NOMINATIM_BASE_URL}/search?` +
        new URLSearchParams({
          q: query,
          format: 'json',
          limit: '5',
          'accept-language': 'ja',
        })
    );

    if (!response.ok) {
      throw new Error('Failed to fetch location data');
    }

    const data = await response.json();

    return data.map((item) => ({
      lat: parseFloat(item.lat),
      lng: parseFloat(item.lon),
      displayName: item.display_name,
      address: item.address,
    }));
  } catch (error) {
    console.error('Geocoding error:', error);
    return [];
  }
};

/**
 * 座標から住所を取得（リバースジオコーディング）
 * @param {number} lat - 緯度
 * @param {number} lng - 経度
 * @returns {Promise<Object>} 住所情報
 */
export const reverseGeocode = async (lat, lng) => {
  try {
    const response = await fetch(
      `${NOMINATIM_BASE_URL}/reverse?` +
        new URLSearchParams({
          lat: lat.toString(),
          lon: lng.toString(),
          format: 'json',
          'accept-language': 'ja',
        })
    );

    if (!response.ok) {
      throw new Error('Failed to fetch address data');
    }

    const data = await response.json();

    return {
      displayName: data.display_name,
      address: data.address,
    };
  } catch (error) {
    console.error('Reverse geocoding error:', error);
    return null;
  }
};
