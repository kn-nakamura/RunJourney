/**
 * Modal.jsx
 * 
 * モーダルダイアログコンポーネント
 */

import React, { useEffect } from 'react';
import { X } from 'lucide-react';

/**
 * Modalコンポーネント
 * @param {Object} props
 * @param {boolean} props.isOpen - モーダルの表示状態
 * @param {Function} props.onClose - 閉じるハンドラ
 * @param {string} props.title - モーダルのタイトル
 * @param {React.ReactNode} props.children - モーダルの内容
 * @param {string} props.size - モーダルのサイズ ('sm', 'md', 'lg', 'xl')
 */
export const Modal = ({
  isOpen,
  onClose,
  title,
  children,
  size = 'md',
}) => {
  // Escキーで閉じる
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const sizes = {
    sm: 'max-w-md',
    md: 'max-w-2xl',
    lg: 'max-w-4xl',
    xl: 'max-w-6xl',
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
      onClick={onClose}
    >
      <div
        className={`bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full ${sizes[size]} max-h-[90vh] overflow-hidden animate-scale-in`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* ヘッダー */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
            {title}
          </h2>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <X size={24} />
          </button>
        </div>

        {/* コンテンツ */}
        <div className="p-4 md:p-6 overflow-y-auto overflow-x-hidden max-h-[calc(90vh-80px)]">
          {children}
        </div>
      </div>
    </div>
  );
};
