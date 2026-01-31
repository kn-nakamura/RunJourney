/**
 * Button.jsx
 * 
 * 再利用可能なボタンコンポーネント
 */

import React from 'react';

/**
 * Buttonコンポーネント
 * @param {Object} props
 * @param {React.ReactNode} props.children - ボタンの内容
 * @param {string} props.variant - ボタンのスタイル ('primary', 'secondary', 'danger')
 * @param {string} props.size - ボタンのサイズ ('sm', 'md', 'lg')
 * @param {boolean} props.disabled - 無効化
 * @param {Function} props.onClick - クリックハンドラ
 * @param {string} props.className - 追加のクラス名
 */
export const Button = ({
  children,
  variant = 'primary',
  size = 'md',
  disabled = false,
  onClick,
  className = '',
  ...props
}) => {
  const baseStyles =
    'font-medium rounded-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed';

  const variants = {
    primary:
      'bg-gradient-to-r from-primary-500 to-primary-600 text-white hover:from-primary-600 hover:to-primary-700 shadow-md hover:shadow-lg',
    secondary:
      'bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200 hover:bg-gray-300 dark:hover:bg-gray-600',
    danger:
      'bg-red-500 text-white hover:bg-red-600 shadow-md hover:shadow-lg',
    outline:
      'border-2 border-primary-500 text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-900/20',
  };

  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  };

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
};
