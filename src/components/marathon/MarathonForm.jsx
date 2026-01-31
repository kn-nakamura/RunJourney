/**
 * MarathonForm.jsx
 * 
 * マラソン大会の登録・編集フォーム
 */

import React, { useState, useEffect } from 'react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { searchLocation } from '../../services/geocoding';
import { fetchWeatherData } from '../../services/weather';
import {
  DISTANCE_PRESETS,
  WEATHER_OPTIONS,
  CONDITION_EMOJIS,
} from '../../constants/config';
import { Search, CloudRain, Upload } from 'lucide-react';

/**
 * MarathonFormコンポーネント
 * @param {Object} props
 * @param {boolean} props.isOpen - フォームの表示状態
 * @param {Function} props.onClose - 閉じるハンドラ
 * @param {Function} props.onSubmit - 送信ハンドラ
 * @param {Object} props.initialData - 初期データ（編集時）
 */
export const MarathonForm = ({ isOpen, onClose, onSubmit, initialData }) => {
  // フォームデータ
  const [formData, setFormData] = useState({
    name: '',
    date: '',
    distance: '',
    customDistance: '',
    hours: '',
    minutes: '',
    seconds: '',
    rank: '',
    locationSearch: '',
    location: null,
    externalLinks: {
      strava: '',
      garmin: '',
    },
    condition: {
      physical: 3,
      physicalEmoji: '😐',
      notes: '',
    },
    weather: null,
    photo: null,
    notes: '',
  });

  const [locationResults, setLocationResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isFetchingWeather, setIsFetchingWeather] = useState(false);

  // 初期データをセット（編集時）
  useEffect(() => {
    if (initialData) {
      setFormData({
        ...initialData,
        customDistance: initialData.distance,
        ...initialData.time && {
          hours: parseInt(initialData.time.split(':')[0]),
          minutes: parseInt(initialData.time.split(':')[1]),
          seconds: parseInt(initialData.time.split(':')[2]),
        },
      });
    }
  }, [initialData]);

  // 住所検索
  const handleLocationSearch = async () => {
    if (!formData.locationSearch.trim()) return;

    setIsSearching(true);
    try {
      const results = await searchLocation(formData.locationSearch);
      setLocationResults(results);
    } catch (error) {
      console.error('Location search error:', error);
    } finally {
      setIsSearching(false);
    }
  };

  // 場所を選択
  const handleSelectLocation = (location) => {
    setFormData({
      ...formData,
      location: {
        lat: location.lat,
        lng: location.lng,
        address: location.displayName,
      },
    });
    setLocationResults([]);
  };

  // 天候を自動取得
  const handleFetchWeather = async () => {
    if (!formData.location || !formData.date) {
      alert('先に日付と場所を入力してください');
      return;
    }

    setIsFetchingWeather(true);
    try {
      const weatherData = await fetchWeatherData(
        formData.location.lat,
        formData.location.lng,
        formData.date
      );
      setFormData({ ...formData, weather: weatherData });
    } catch (error) {
      console.error('Weather fetch error:', error);
      alert('天候データの取得に失敗しました');
    } finally {
      setIsFetchingWeather(false);
    }
  };

  // 写真アップロード
  const handlePhotoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      setFormData({ ...formData, photo: event.target?.result });
    };
    reader.readAsDataURL(file);
  };

  // フォーム送信
  const handleSubmit = (e) => {
    e.preventDefault();

    // バリデーション
    if (!formData.name || !formData.date || !formData.location) {
      alert('必須項目を入力してください');
      return;
    }

    const distance = formData.distance === 'custom' 
      ? parseFloat(formData.customDistance) 
      : parseFloat(formData.distance);

    if (!distance || distance <= 0) {
      alert('正しい距離を入力してください');
      return;
    }

    const time = `${formData.hours || 0}:${String(formData.minutes || 0).padStart(2, '0')}:${String(formData.seconds || 0).padStart(2, '0')}`;

    const marathonData = {
      name: formData.name,
      date: formData.date,
      distance,
      time,
      rank: formData.rank ? parseInt(formData.rank) : null,
      location: formData.location,
      externalLinks: formData.externalLinks,
      condition: formData.condition,
      weather: formData.weather,
      photo: formData.photo,
      notes: formData.notes,
    };

    onSubmit(marathonData);
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="新しい大会を追加" size="lg">
      <form onSubmit={handleSubmit} className="space-y-6">
        {/* 大会名 */}
        <div>
          <label className="block text-sm font-medium mb-2">
            大会名 <span className="text-red-500">*</span>
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
            placeholder="例: 東京マラソン 2024"
          />
        </div>

        {/* 開催日 */}
        <div>
          <label className="block text-sm font-medium mb-2">
            開催日 <span className="text-red-500">*</span>
          </label>
          <input
            type="date"
            value={formData.date}
            onChange={(e) => setFormData({ ...formData, date: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
          />
        </div>

        {/* 距離 */}
        <div>
          <label className="block text-sm font-medium mb-2">
            距離 <span className="text-red-500">*</span>
          </label>
          <select
            value={formData.distance}
            onChange={(e) => setFormData({ ...formData, distance: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
          >
            <option value="">選択してください</option>
            {DISTANCE_PRESETS.map((preset) => (
              <option key={preset.value} value={preset.value}>
                {preset.label}
              </option>
            ))}
          </select>

          {formData.distance === 'custom' && (
            <input
              type="number"
              step="0.001"
              value={formData.customDistance}
              onChange={(e) =>
                setFormData({ ...formData, customDistance: e.target.value })
              }
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 mt-2"
              placeholder="カスタム距離（km）"
            />
          )}
        </div>

        {/* タイム */}
        <div>
          <label className="block text-sm font-medium mb-2">
            記録タイム <span className="text-red-500">*</span>
          </label>
          <div className="flex gap-2 items-center">
            <input
              type="number"
              min="0"
              max="23"
              value={formData.hours}
              onChange={(e) => setFormData({ ...formData, hours: e.target.value })}
              className="w-20 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="0"
            />
            <span className="text-gray-600 dark:text-gray-400">:</span>
            <input
              type="number"
              min="0"
              max="59"
              value={formData.minutes}
              onChange={(e) => setFormData({ ...formData, minutes: e.target.value })}
              className="w-20 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="00"
            />
            <span className="text-gray-600 dark:text-gray-400">:</span>
            <input
              type="number"
              min="0"
              max="59"
              value={formData.seconds}
              onChange={(e) => setFormData({ ...formData, seconds: e.target.value })}
              className="w-20 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="00"
            />
            <span className="text-gray-600 dark:text-gray-400 text-sm ml-2">
              時 分 秒
            </span>
          </div>
        </div>

        {/* 順位 */}
        <div>
          <label className="block text-sm font-medium mb-2">順位（任意）</label>
          <input
            type="number"
            min="1"
            value={formData.rank}
            onChange={(e) => setFormData({ ...formData, rank: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
            placeholder="例: 120"
          />
        </div>

        {/* 場所検索 */}
        <div>
          <label className="block text-sm font-medium mb-2">
            場所 <span className="text-red-500">*</span>
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={formData.locationSearch}
              onChange={(e) =>
                setFormData({ ...formData, locationSearch: e.target.value })
              }
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="例: 東京マラソン、東京都庁"
            />
            <Button
              type="button"
              onClick={handleLocationSearch}
              disabled={isSearching}
            >
              <Search size={20} />
            </Button>
          </div>

          {formData.location && (
            <p className="mt-2 text-sm text-green-600 dark:text-green-400">
              ✓ {formData.location.address}
            </p>
          )}

          {locationResults.length > 0 && (
            <div className="mt-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 max-h-48 overflow-y-auto">
              {locationResults.map((result, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => handleSelectLocation(result)}
                  className="w-full px-4 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-600 text-sm"
                >
                  {result.displayName}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* 天候 */}
        <div>
          <label className="block text-sm font-medium mb-2">天候（任意）</label>
          <Button
            type="button"
            onClick={handleFetchWeather}
            disabled={isFetchingWeather || !formData.location || !formData.date}
            variant="outline"
            className="mb-2"
          >
            <CloudRain size={20} />
            {isFetchingWeather ? '取得中...' : '天候を自動取得'}
          </Button>

          {formData.weather && (
            <div className="p-4 bg-gray-100 dark:bg-gray-700 rounded-lg">
              <p>
                {formData.weather.icon} {formData.weather.description}
              </p>
              <p className="text-sm">
                気温: {formData.weather.temperature}℃
                {formData.weather.temperatureRange && (
                  <span className="text-gray-600 dark:text-gray-400">
                    {' '}
                    ({formData.weather.temperatureRange.min}-
                    {formData.weather.temperatureRange.max}℃)
                  </span>
                )}
              </p>
            </div>
          )}

          <div className="mt-2 flex gap-2 flex-wrap">
            {WEATHER_OPTIONS.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() =>
                  setFormData({
                    ...formData,
                    weather: {
                      icon: option.icon,
                      value: option.value,
                      description: option.label,
                      autoFetched: false,
                    },
                  })
                }
                className={`px-3 py-2 border rounded-lg ${
                  formData.weather?.value === option.value
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                    : 'border-gray-300 dark:border-gray-600'
                }`}
              >
                {option.icon} {option.label}
              </button>
            ))}
          </div>
        </div>

        {/* 体調 */}
        <div>
          <label className="block text-sm font-medium mb-2">体調（任意）</label>
          <div className="flex gap-2">
            {CONDITION_EMOJIS.map((condition) => (
              <button
                key={condition.value}
                type="button"
                onClick={() =>
                  setFormData({
                    ...formData,
                    condition: {
                      ...formData.condition,
                      physical: condition.value,
                      physicalEmoji: condition.emoji,
                    },
                  })
                }
                className={`px-4 py-2 border rounded-lg text-2xl ${
                  formData.condition.physical === condition.value
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                    : 'border-gray-300 dark:border-gray-600'
                }`}
                title={condition.label}
              >
                {condition.emoji}
              </button>
            ))}
          </div>
          <input
            type="text"
            value={formData.condition.notes}
            onChange={(e) =>
              setFormData({
                ...formData,
                condition: { ...formData.condition, notes: e.target.value },
              })
            }
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 mt-2"
            placeholder="体調メモ（例: 前日よく眠れた）"
          />
        </div>

        {/* 外部リンク */}
        <div>
          <label className="block text-sm font-medium mb-2">
            外部リンク（任意）
          </label>
          <div className="space-y-2">
            <input
              type="url"
              value={formData.externalLinks.strava}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  externalLinks: {
                    ...formData.externalLinks,
                    strava: e.target.value,
                  },
                })
              }
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="STRAVA URL"
            />
            <input
              type="url"
              value={formData.externalLinks.garmin}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  externalLinks: {
                    ...formData.externalLinks,
                    garmin: e.target.value,
                  },
                })
              }
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="Garmin Connect URL"
            />
          </div>
        </div>

        {/* 写真 */}
        <div>
          <label className="block text-sm font-medium mb-2">写真（任意）</label>
          <input
            type="file"
            accept="image/*"
            onChange={handlePhotoUpload}
            className="hidden"
            id="photo-upload"
          />
          <label
            htmlFor="photo-upload"
            className="flex items-center justify-center gap-2 w-full px-4 py-8 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg cursor-pointer hover:border-primary-500 transition-colors"
          >
            <Upload size={24} />
            <span>写真をアップロード</span>
          </label>
          {formData.photo && (
            <img
              src={formData.photo}
              alt="Preview"
              className="mt-2 w-full h-48 object-cover rounded-lg"
            />
          )}
        </div>

        {/* メモ */}
        <div>
          <label className="block text-sm font-medium mb-2">メモ（任意）</label>
          <textarea
            value={formData.notes}
            onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
            rows="3"
            placeholder="その他のメモ"
          />
        </div>

        {/* ボタン */}
        <div className="flex gap-3 justify-end pt-4 border-t border-gray-200 dark:border-gray-700">
          <Button type="button" variant="secondary" onClick={onClose}>
            キャンセル
          </Button>
          <Button type="submit">保存</Button>
        </div>
      </form>
    </Modal>
  );
};
