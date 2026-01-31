/**
 * MapView.jsx
 *
 * Leafletを使った地図表示コンポーネント
 * - 2本指操作のみ対応（モバイル）
 * - 現在地表示
 * - フィルタリング機能
 * - 凡例表示
 * - SNS共有カード
 */

import React, { useMemo, useState, useEffect, useRef, useCallback } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap, Circle } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace } from '../../utils/timeUtils';
import { getAvailableYears, getAvailableDistances } from '../../utils/calculations';
import { Layers, ExternalLink, Navigation, Filter, Info, Share2, X, Download, Camera } from 'lucide-react';
import html2canvas from 'html2canvas';

// マップタイルの種類
const MAP_TILES = {
  standard: {
    name: '標準',
    url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  },
  satellite: {
    name: '衛星',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution:
      'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community',
  },
  terrain: {
    name: '地形',
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution:
      'Map data: &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="http://viewfinderpanoramas.org">SRTM</a> | Map style: &copy; <a href="https://opentopomap.org">OpenTopoMap</a> (<a href="https://creativecommons.org/licenses/by-sa/3.0/">CC-BY-SA</a>)',
  },
  light: {
    name: 'ライト',
    url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
  },
  dark: {
    name: 'ダーク',
    url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
  },
};

// マーカーアイコンの修正（Leafletのデフォルトアイコンパス問題を解決）
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

/**
 * カスタムマーカーアイコンを作成
 * @param {string} color - マーカーの色
 */
const createCustomIcon = (color) => {
  const svgIcon = `
    <svg width="25" height="41" viewBox="0 0 25 41" xmlns="http://www.w3.org/2000/svg">
      <path d="M12.5 0C5.596 0 0 5.596 0 12.5c0 9.375 12.5 28.125 12.5 28.125S25 21.875 25 12.5C25 5.596 19.404 0 12.5 0z" fill="${color}"/>
      <circle cx="12.5" cy="12.5" r="5" fill="white"/>
    </svg>
  `;

  return L.divIcon({
    html: svgIcon,
    className: 'custom-marker',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
  });
};

/**
 * 現在地アイコンを作成
 */
const createCurrentLocationIcon = () => {
  const svgIcon = `
    <svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <circle cx="12" cy="12" r="10" fill="#4285F4" stroke="white" stroke-width="3"/>
      <circle cx="12" cy="12" r="4" fill="white"/>
    </svg>
  `;

  return L.divIcon({
    html: svgIcon,
    className: 'current-location-marker',
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  });
};

/**
 * 2本指操作を制御するコンポーネント
 */
const TouchController = () => {
  const map = useMap();

  useEffect(() => {
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    );

    if (isMobile) {
      // モバイルでは1本指でのドラッグを無効化
      map.dragging.disable();

      let touchStarted = false;

      const handleTouchStart = (e) => {
        if (e.touches.length >= 2) {
          touchStarted = true;
          map.dragging.enable();
        }
      };

      const handleTouchEnd = () => {
        if (touchStarted) {
          touchStarted = false;
          setTimeout(() => {
            map.dragging.disable();
          }, 100);
        }
      };

      const container = map.getContainer();
      container.addEventListener('touchstart', handleTouchStart, { passive: true });
      container.addEventListener('touchend', handleTouchEnd, { passive: true });

      return () => {
        container.removeEventListener('touchstart', handleTouchStart);
        container.removeEventListener('touchend', handleTouchEnd);
        map.dragging.enable();
      };
    }
  }, [map]);

  return null;
};

/**
 * 2本指操作のオーバーレイメッセージ
 */
const TouchOverlay = ({ show }) => {
  if (!show) return null;

  return (
    <div className="absolute inset-0 bg-black/50 flex items-center justify-center z-[1000] pointer-events-none">
      <div className="bg-white dark:bg-gray-800 px-4 py-2 rounded-lg text-sm text-gray-700 dark:text-gray-300">
        2本指で操作してください
      </div>
    </div>
  );
};

/**
 * 地図の中心とズームを調整するコンポーネント
 */
const MapController = ({ marathons }) => {
  const map = useMap();

  useEffect(() => {
    if (marathons.length > 0) {
      const bounds = marathons.map((m) => [m.location.lat, m.location.lng]);
      if (bounds.length === 1) {
        map.setView(bounds[0], 10);
      } else {
        map.fitBounds(bounds, { padding: [50, 50] });
      }
    }
  }, [marathons, map]);

  return null;
};

/**
 * マップタイル切り替えコンポーネント
 */
const TileSelector = ({ selectedTile, onTileChange }) => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="absolute top-4 right-4 z-[1000]">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="bg-white dark:bg-gray-800 p-2 rounded-lg shadow-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        title="マップの種類を変更"
      >
        <Layers size={20} className="text-gray-700 dark:text-gray-300" />
      </button>
      {isOpen && (
        <div className="absolute top-12 right-0 bg-white dark:bg-gray-800 rounded-lg shadow-lg p-2 min-w-[120px]">
          {Object.entries(MAP_TILES).map(([key, tile]) => (
            <button
              key={key}
              onClick={() => {
                onTileChange(key);
                setIsOpen(false);
              }}
              className={`w-full text-left px-3 py-2 rounded text-sm ${
                selectedTile === key
                  ? 'bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
                  : 'hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300'
              }`}
            >
              {tile.name}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

/**
 * フィルターパネル
 */
const FilterPanel = ({
  filterYear,
  setFilterYear,
  filterDistance,
  setFilterDistance,
  availableYears,
  availableDistances,
  onClose
}) => {
  return (
    <div className="absolute top-4 left-4 z-[1000] bg-white dark:bg-gray-800 rounded-lg shadow-lg p-4 min-w-[200px] max-w-[280px]">
      <div className="flex items-center justify-between mb-3">
        <h3 className="font-bold text-gray-900 dark:text-white text-sm">フィルター</h3>
        <button onClick={onClose} className="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300">
          <X size={16} />
        </button>
      </div>

      <div className="space-y-3">
        <div>
          <label className="block text-xs text-gray-600 dark:text-gray-400 mb-1">年度</label>
          <select
            value={filterYear}
            onChange={(e) => setFilterYear(e.target.value)}
            className="w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="all">全期間</option>
            {availableYears.map((year) => (
              <option key={year} value={year}>{year}年</option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-xs text-gray-600 dark:text-gray-400 mb-1">距離</label>
          <select
            value={filterDistance}
            onChange={(e) => setFilterDistance(e.target.value)}
            className="w-full px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
          >
            <option value="all">全距離</option>
            {availableDistances.map((distance) => (
              <option key={distance} value={distance}>
                {distance === 42.195
                  ? 'フルマラソン'
                  : distance === 21.0975
                  ? 'ハーフマラソン'
                  : `${distance}km`}
              </option>
            ))}
          </select>
        </div>
      </div>
    </div>
  );
};

/**
 * 凡例コンポーネント
 */
const Legend = ({ show, onToggle }) => {
  return (
    <div className="absolute bottom-20 left-4 z-[1000]">
      <button
        onClick={onToggle}
        className="bg-white dark:bg-gray-800 p-2 rounded-lg shadow-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors mb-2"
        title="凡例"
      >
        <Info size={20} className="text-gray-700 dark:text-gray-300" />
      </button>

      {show && (
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-3 min-w-[140px]">
          <h4 className="font-bold text-xs text-gray-900 dark:text-white mb-2">ピンの凡例</h4>
          <div className="space-y-2 text-xs">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 rounded-full bg-yellow-500"></div>
              <span className="text-gray-700 dark:text-gray-300">PB（自己ベスト）</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 rounded-full bg-gray-400"></div>
              <span className="text-gray-700 dark:text-gray-300">SB（シーズンベスト）</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 rounded-full bg-blue-500"></div>
              <span className="text-gray-700 dark:text-gray-300">通常</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 rounded-full bg-blue-400 border-2 border-white"></div>
              <span className="text-gray-700 dark:text-gray-300">現在地</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

/**
 * 共有カードモーダル
 */
const ShareCardModal = ({
  isOpen,
  onClose,
  marathons,
  filterYear,
  filterDistance,
  mapRef
}) => {
  const cardRef = useRef(null);
  const [isGenerating, setIsGenerating] = useState(false);

  const stats = useMemo(() => {
    const totalRaces = marathons.length;
    const totalDistance = marathons.reduce((acc, m) => acc + m.distance, 0);
    const pbCount = marathons.filter(m => m.isPB).length;

    return { totalRaces, totalDistance, pbCount };
  }, [marathons]);

  const handleDownload = async () => {
    if (!cardRef.current) return;

    setIsGenerating(true);
    try {
      const canvas = await html2canvas(cardRef.current, {
        backgroundColor: '#ffffff',
        scale: 2,
      });

      const link = document.createElement('a');
      link.download = `runjourney-${new Date().toISOString().split('T')[0]}.png`;
      link.href = canvas.toDataURL('image/png');
      link.click();
    } catch (error) {
      console.error('Failed to generate image:', error);
      alert('画像の生成に失敗しました');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleShare = async () => {
    const text = `🏃 RunJourney マラソン記録\n\n` +
      `📊 大会数: ${stats.totalRaces}件\n` +
      `📏 総走行距離: ${stats.totalDistance.toFixed(1)}km\n` +
      `🏆 PB達成: ${stats.pbCount}回\n\n` +
      `${filterYear !== 'all' ? `📅 ${filterYear}年` : '全期間'}` +
      `${filterDistance !== 'all' ? ` / ${filterDistance === '42.195' ? 'フル' : filterDistance === '21.0975' ? 'ハーフ' : filterDistance + 'km'}` : ''}\n\n` +
      `#RunJourney #マラソン`;

    if (navigator.share) {
      try {
        await navigator.share({
          title: 'RunJourney マラソン記録',
          text: text,
        });
      } catch (error) {
        if (error.name !== 'AbortError') {
          await navigator.clipboard.writeText(text);
          alert('クリップボードにコピーしました');
        }
      }
    } else {
      await navigator.clipboard.writeText(text);
      alert('クリップボードにコピーしました');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[2000] p-4">
      <div className="bg-white dark:bg-gray-800 rounded-xl max-w-md w-full max-h-[90vh] overflow-y-auto">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          <h3 className="font-bold text-lg text-gray-900 dark:text-white">共有カード</h3>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300">
            <X size={24} />
          </button>
        </div>

        <div className="p-4">
          {/* 共有カード */}
          <div
            ref={cardRef}
            className="bg-gradient-to-br from-primary-500 to-secondary-500 rounded-xl p-4 text-white"
          >
            <div className="flex items-center gap-2 mb-3">
              <span className="text-2xl">🏃</span>
              <span className="font-bold text-xl">RunJourney</span>
            </div>

            <div className="bg-white/20 backdrop-blur-sm rounded-lg p-3 mb-3">
              <div className="text-sm opacity-80 mb-1">
                {filterYear !== 'all' ? `${filterYear}年` : '全期間'}
                {filterDistance !== 'all' && ` / ${filterDistance === '42.195' ? 'フルマラソン' : filterDistance === '21.0975' ? 'ハーフマラソン' : filterDistance + 'km'}`}
              </div>
              <div className="grid grid-cols-3 gap-2 text-center">
                <div>
                  <div className="text-2xl font-bold">{stats.totalRaces}</div>
                  <div className="text-xs opacity-80">大会</div>
                </div>
                <div>
                  <div className="text-2xl font-bold">{stats.totalDistance.toFixed(0)}</div>
                  <div className="text-xs opacity-80">km</div>
                </div>
                <div>
                  <div className="text-2xl font-bold">{stats.pbCount}</div>
                  <div className="text-xs opacity-80">PB</div>
                </div>
              </div>
            </div>

            <div className="text-xs opacity-70 text-right">
              run-journey2.vercel.app
            </div>
          </div>

          {/* アクションボタン */}
          <div className="flex gap-2 mt-4">
            <button
              onClick={handleDownload}
              disabled={isGenerating}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg transition-colors disabled:opacity-50"
            >
              <Download size={18} />
              {isGenerating ? '生成中...' : '画像保存'}
            </button>
            <button
              onClick={handleShare}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg transition-colors"
            >
              <Share2 size={18} />
              テキスト共有
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

/**
 * MapViewコンポーネント
 * @param {Object} props
 * @param {Array} props.marathons - マラソンデータの配列
 * @param {Function} props.onMarkerClick - マーカークリック時のハンドラ
 * @param {Function} props.onNavigateToDetail - 詳細への遷移ハンドラ
 */
export const MapView = ({ marathons, onMarkerClick, onNavigateToDetail }) => {
  const defaultCenter = [35.6812, 139.7671]; // 東京
  const defaultZoom = 5;
  const [selectedTile, setSelectedTile] = useState('standard');
  const [showTouchOverlay, setShowTouchOverlay] = useState(false);
  const [currentLocation, setCurrentLocation] = useState(null);
  const [isLocating, setIsLocating] = useState(false);
  const [showFilter, setShowFilter] = useState(false);
  const [showLegend, setShowLegend] = useState(false);
  const [showShareCard, setShowShareCard] = useState(false);
  const [filterYear, setFilterYear] = useState('all');
  const [filterDistance, setFilterDistance] = useState('all');
  const mapRef = useRef(null);

  // 利用可能な年度と距離
  const availableYears = useMemo(() => getAvailableYears(marathons), [marathons]);
  const availableDistances = useMemo(() => getAvailableDistances(marathons), [marathons]);

  // フィルタリングされたマラソン
  const filteredMarathons = useMemo(() => {
    let result = [...marathons];

    if (filterYear !== 'all') {
      result = result.filter(
        (m) => new Date(m.date).getFullYear() === parseInt(filterYear)
      );
    }
    if (filterDistance !== 'all') {
      result = result.filter((m) => m.distance === parseFloat(filterDistance));
    }

    return result;
  }, [marathons, filterYear, filterDistance]);

  // マーカーアイコンをメモ化
  const pbIcon = useMemo(() => createCustomIcon('#FFD700'), []);
  const sbIcon = useMemo(() => createCustomIcon('#C0C0C0'), []);
  const normalIcon = useMemo(() => createCustomIcon('#3b82f6'), []);
  const currentLocationIcon = useMemo(() => createCurrentLocationIcon(), []);

  const currentTile = MAP_TILES[selectedTile];

  // 現在地を取得
  const getCurrentLocation = useCallback(() => {
    if (!navigator.geolocation) {
      alert('お使いのブラウザは位置情報に対応していません');
      return;
    }

    setIsLocating(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setCurrentLocation({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
          accuracy: position.coords.accuracy,
        });
        setIsLocating(false);
      },
      (error) => {
        console.error('Geolocation error:', error);
        alert('位置情報の取得に失敗しました');
        setIsLocating(false);
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
      }
    );
  }, []);

  // モバイルでのタッチ操作のオーバーレイ表示
  useEffect(() => {
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    );

    if (isMobile) {
      let timeout;
      const handleTouchStart = (e) => {
        if (e.touches.length === 1) {
          setShowTouchOverlay(true);
          clearTimeout(timeout);
          timeout = setTimeout(() => {
            setShowTouchOverlay(false);
          }, 2000);
        } else {
          setShowTouchOverlay(false);
        }
      };

      const container = document.querySelector('.map-container');
      if (container) {
        container.addEventListener('touchstart', handleTouchStart, { passive: true });
        return () => {
          container.removeEventListener('touchstart', handleTouchStart);
          clearTimeout(timeout);
        };
      }
    }
  }, []);

  const isFiltered = filterYear !== 'all' || filterDistance !== 'all';

  return (
    <div className="h-full w-full rounded-xl overflow-hidden shadow-lg relative map-container">
      <MapContainer
        ref={mapRef}
        center={defaultCenter}
        zoom={defaultZoom}
        style={{ height: '100%', width: '100%' }}
        className="z-0"
      >
        <TileLayer attribution={currentTile.attribution} url={currentTile.url} />
        <TouchController />
        <MapController marathons={filteredMarathons} />

        {/* 現在地マーカー */}
        {currentLocation && (
          <>
            <Circle
              center={[currentLocation.lat, currentLocation.lng]}
              radius={currentLocation.accuracy}
              pathOptions={{
                color: '#4285F4',
                fillColor: '#4285F4',
                fillOpacity: 0.15,
                weight: 1,
              }}
            />
            <Marker
              position={[currentLocation.lat, currentLocation.lng]}
              icon={currentLocationIcon}
            >
              <Popup>
                <div className="text-center">
                  <p className="font-bold">現在地</p>
                  <p className="text-xs text-gray-500">精度: {Math.round(currentLocation.accuracy)}m</p>
                </div>
              </Popup>
            </Marker>
          </>
        )}

        {filteredMarathons.map((marathon) => {
          // マーカーの色を決定
          let icon = normalIcon;
          if (marathon.isPB) icon = pbIcon;
          else if (marathon.isSB) icon = sbIcon;

          return (
            <Marker
              key={marathon.id}
              position={[marathon.location.lat, marathon.location.lng]}
              icon={icon}
            >
              <Popup>
                <div className="p-2 min-w-[220px]">
                  <div className="flex items-center gap-2 mb-2">
                    {marathon.isPB && (
                      <span className="text-yellow-500 font-bold">🏆 PB</span>
                    )}
                    {marathon.isSB && !marathon.isPB && (
                      <span className="text-gray-400 font-bold">📅 SB</span>
                    )}
                    <h3 className="font-bold text-lg">{marathon.name}</h3>
                  </div>
                  <div className="space-y-1 text-sm">
                    <p>📅 {formatDateShort(marathon.date)}</p>
                    <p>📏 {marathon.distance}km</p>
                    <p>⏱️ {marathon.time}</p>
                    <p>
                      📊 ペース: {calculatePace(marathon.time, marathon.distance)}
                      /km
                    </p>
                    {marathon.rank && <p>🏅 {marathon.rank}位</p>}
                    {marathon.weather && (
                      <p>
                        {marathon.weather.icon} {marathon.weather.description}
                      </p>
                    )}
                  </div>
                  <button
                    onClick={() =>
                      onNavigateToDetail && onNavigateToDetail(marathon)
                    }
                    className="mt-3 w-full flex items-center justify-center gap-2 px-3 py-2 bg-primary-500 hover:bg-primary-600 text-white text-sm rounded-lg transition-colors"
                  >
                    <ExternalLink size={16} />
                    詳細に移動
                  </button>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* タッチオーバーレイ */}
      <TouchOverlay show={showTouchOverlay} />

      {/* タイルセレクター */}
      <TileSelector selectedTile={selectedTile} onTileChange={setSelectedTile} />

      {/* フィルターボタン */}
      <div className="absolute top-4 right-16 z-[1000]">
        <button
          onClick={() => setShowFilter(!showFilter)}
          className={`p-2 rounded-lg shadow-lg transition-colors ${
            isFiltered
              ? 'bg-primary-500 text-white'
              : 'bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
          }`}
          title="フィルター"
        >
          <Filter size={20} />
        </button>
      </div>

      {/* フィルターパネル */}
      {showFilter && (
        <FilterPanel
          filterYear={filterYear}
          setFilterYear={setFilterYear}
          filterDistance={filterDistance}
          setFilterDistance={setFilterDistance}
          availableYears={availableYears}
          availableDistances={availableDistances}
          onClose={() => setShowFilter(false)}
        />
      )}

      {/* 凡例 */}
      <Legend show={showLegend} onToggle={() => setShowLegend(!showLegend)} />

      {/* 現在地ボタン */}
      <div className="absolute bottom-20 right-4 z-[1000]">
        <button
          onClick={getCurrentLocation}
          disabled={isLocating}
          className="bg-white dark:bg-gray-800 p-3 rounded-full shadow-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors disabled:opacity-50"
          title="現在地を表示"
        >
          <Navigation size={20} className={`text-gray-700 dark:text-gray-300 ${isLocating ? 'animate-pulse' : ''}`} />
        </button>
      </div>

      {/* 共有ボタン */}
      <div className="absolute bottom-32 right-4 z-[1000]">
        <button
          onClick={() => setShowShareCard(true)}
          className="bg-white dark:bg-gray-800 p-3 rounded-full shadow-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          title="共有カードを作成"
        >
          <Share2 size={20} className="text-gray-700 dark:text-gray-300" />
        </button>
      </div>

      {/* フィルター状態表示 */}
      {isFiltered && (
        <div className="absolute top-16 left-4 z-[1000] bg-primary-500 text-white text-xs px-3 py-1 rounded-full">
          {filterYear !== 'all' && `${filterYear}年`}
          {filterYear !== 'all' && filterDistance !== 'all' && ' / '}
          {filterDistance !== 'all' && (
            filterDistance === '42.195' ? 'フル' :
            filterDistance === '21.0975' ? 'ハーフ' :
            `${filterDistance}km`
          )}
          {' '}({filteredMarathons.length}件)
        </div>
      )}

      {/* 共有カードモーダル */}
      <ShareCardModal
        isOpen={showShareCard}
        onClose={() => setShowShareCard(false)}
        marathons={filteredMarathons}
        filterYear={filterYear}
        filterDistance={filterDistance}
        mapRef={mapRef}
      />
    </div>
  );
};
