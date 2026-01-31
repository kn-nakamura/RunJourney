/**
 * MapView.jsx
 *
 * Leafletを使った地図表示コンポーネント
 */

import React, { useMemo, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace } from '../../utils/timeUtils';
import { Layers, ExternalLink } from 'lucide-react';

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
 * 地図の中心とズームを調整するコンポーネント
 */
const MapController = ({ marathons }) => {
  const map = useMap();

  React.useEffect(() => {
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

  // マーカーアイコンをメモ化
  const pbIcon = useMemo(() => createCustomIcon('#FFD700'), []);
  const sbIcon = useMemo(() => createCustomIcon('#C0C0C0'), []);
  const normalIcon = useMemo(() => createCustomIcon('#3b82f6'), []);

  const currentTile = MAP_TILES[selectedTile];

  return (
    <div className="h-full w-full rounded-xl overflow-hidden shadow-lg relative">
      <MapContainer
        center={defaultCenter}
        zoom={defaultZoom}
        style={{ height: '100%', width: '100%' }}
        className="z-0"
      >
        <TileLayer attribution={currentTile.attribution} url={currentTile.url} />

        <MapController marathons={marathons} />

        {marathons.map((marathon) => {
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
      <TileSelector selectedTile={selectedTile} onTileChange={setSelectedTile} />
    </div>
  );
};
