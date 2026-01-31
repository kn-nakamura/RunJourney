/**
 * Tabs.jsx
 *
 * タブ切り替えコンポーネント
 */

import React from 'react';

/**
 * Tabsコンポーネント
 * @param {Object} props
 * @param {Array} props.tabs - タブの配列 [{ id, label, icon }]
 * @param {string} props.activeTab - アクティブなタブのID
 * @param {Function} props.onChange - タブ変更ハンドラ
 */
export const Tabs = ({ tabs, activeTab, onChange }) => {
  return (
    <div className="border-b border-gray-200 dark:border-gray-700 overflow-x-auto">
      <nav className="flex justify-around md:justify-start md:space-x-8 md:px-6 min-w-max" aria-label="Tabs">
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          const Icon = tab.icon;

          return (
            <button
              key={tab.id}
              onClick={() => onChange(tab.id)}
              className={`
                flex flex-col md:flex-row items-center gap-1 md:gap-2 py-3 md:py-4 px-3 md:px-1 border-b-2 font-medium text-xs md:text-sm transition-colors whitespace-nowrap
                ${
                  isActive
                    ? 'border-primary-500 text-primary-600 dark:text-primary-400'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
                }
              `}
            >
              {Icon && <Icon size={20} />}
              <span>{tab.label}</span>
            </button>
          );
        })}
      </nav>
    </div>
  );
};
