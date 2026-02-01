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
import { Search, CloudRain, Upload, Trash2 } from 'lucide-react';

/**
 * 全角数字を半角数字に変換
 * @param {string} str - 入力文字列
 * @returns {string} 半角変換後の文字列
 */
const toHalfWidth = (str) => {
  if (!str) return '';
  return str.replace(/[０-９]/g, (char) => {
    return String.fromCharCode(char.charCodeAt(0) - 0xfee0);
  });
};

/**
 * MarathonFormコンポーネント
 * @param {Object} props
 * @param {boolean} props.isOpen - フォームの表示状態
 * @param {Function} props.onClose - 閉じるハンドラ
 * @param {Function} props.onSubmit - 送信ハンドラ
 * @param {Object} props.initialData - 初期データ（編集時）
 * @param {Function} props.onDelete - 削除ハンドラ（編集時のみ）
 */
export const MarathonForm = ({ isOpen, onClose, onSubmit, initialData, onDelete }) => {
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

  // 初期フォームデータ
  const initialFormData = {
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
  };

  // 初期データをセット（編集時）またはリセット（新規作成時）
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
    } else {
      // 新規作成時はフォームをリセット
      setFormData(initialFormData);
      setLocationResults([]);
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

  // 画像を圧縮する関数
  const compressImage = (file, maxWidth = 1024, quality = 0.8) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          // 元のサイズを取得
          let width = img.width;
          let height = img.height;

          // 最大幅を超える場合はリサイズ
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          }

          // Canvasで描画
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;

          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);

          // JPEG形式で圧縮（PNG以外はJPEGに変換）
          const mimeType = file.type === 'image/png' ? 'image/png' : 'image/jpeg';
          const compressedDataUrl = canvas.toDataURL(mimeType, quality);

          // 圧縮後のサイズを確認（デバッグ用）
          const originalSize = Math.round(file.size / 1024);
          const compressedSize = Math.round((compressedDataUrl.length * 3) / 4 / 1024);
          console.log(`Image compressed: ${originalSize}KB → ${compressedSize}KB (${Math.round((1 - compressedSize / originalSize) * 100)}% reduction)`);

          resolve(compressedDataUrl);
        };
        img.onerror = reject;
        img.src = e.target?.result;
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  };

  // 写真アップロード（圧縮付き）
  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      // 画像を圧縮
      const compressedPhoto = await compressImage(file, 1024, 0.8);
      setFormData({ ...formData, photo: compressedPhoto });
    } catch (error) {
      console.error('Image compression error:', error);
      // 圧縮に失敗した場合は元の画像を使用
      const reader = new FileReader();
      reader.onload = (event) => {
        setFormData({ ...formData, photo: event.target?.result });
      };
      reader.readAsDataURL(file);
    }
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

  const isEditMode = !!initialData?.id;

  const handleDelete = () => {
    if (window.confirm('この大会の記録を削除しますか？この操作は取り消せません。')) {
      onDelete && onDelete(initialData.id);
      onClose();
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={isEditMode ? "大会を編集" : "新しい大会を追加"} size="lg">
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
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              min="0"
              max="23"
              value={formData.hours}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  hours: toHalfWidth(e.target.value).replace(/[^0-9]/g, ''),
                })
              }
              className="w-20 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="0"
            />
            <span className="text-gray-600 dark:text-gray-400">:</span>
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              min="0"
              max="59"
              value={formData.minutes}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  minutes: toHalfWidth(e.target.value).replace(/[^0-9]/g, ''),
                })
              }
              className="w-20 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500"
              placeholder="00"
            />
            <span className="text-gray-600 dark:text-gray-400">:</span>
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              min="0"
              max="59"
              value={formData.seconds}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  seconds: toHalfWidth(e.target.value).replace(/[^0-9]/g, ''),
                })
              }
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
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            min="1"
            value={formData.rank}
            onChange={(e) =>
              setFormData({
                ...formData,
                rank: toHalfWidth(e.target.value).replace(/[^0-9]/g, ''),
              })
            }
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
        <div className="flex gap-3 justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
          {/* 削除ボタン（編集時のみ） */}
          <div>
            {isEditMode && onDelete && (
              <Button
                type="button"
                variant="danger"
                onClick={handleDelete}
                className="flex items-center gap-1"
              >
                <Trash2 size={16} />
                削除
              </Button>
            )}
          </div>
          <div className="flex gap-3">
            <Button type="button" variant="secondary" onClick={onClose}>
              キャンセル
            </Button>
            <Button type="submit">保存</Button>
          </div>
        </div>
      </form>
    </Modal>
  );
};
