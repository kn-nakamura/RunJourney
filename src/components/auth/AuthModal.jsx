/**
 * AuthModal.jsx
 *
 * ログイン・新規登録モーダル
 */

import React, { useState } from 'react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { X, Mail, Lock, User, AlertCircle, Chrome } from 'lucide-react';

/**
 * 認証モーダルコンポーネント
 */
export const AuthModal = ({
  isOpen,
  onClose,
  onLogin,
  onRegister,
  onGoogleLogin,
  error,
  onClearError
}) => {
  const [mode, setMode] = useState('login'); // 'login' or 'register'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [localError, setLocalError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLocalError('');
    onClearError?.();

    if (mode === 'register' && password !== confirmPassword) {
      setLocalError('パスワードが一致しません');
      return;
    }

    if (password.length < 6) {
      setLocalError('パスワードは6文字以上で入力してください');
      return;
    }

    setLoading(true);
    try {
      if (mode === 'login') {
        await onLogin(email, password);
      } else {
        await onRegister(email, password);
      }
      handleClose();
    } catch (err) {
      // エラーは親コンポーネントで処理
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setLocalError('');
    onClearError?.();
    setLoading(true);
    try {
      await onGoogleLogin();
      handleClose();
    } catch (err) {
      // エラーは親コンポーネントで処理
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setEmail('');
    setPassword('');
    setConfirmPassword('');
    setLocalError('');
    onClearError?.();
    onClose();
  };

  const switchMode = () => {
    setMode(mode === 'login' ? 'register' : 'login');
    setLocalError('');
    onClearError?.();
  };

  const displayError = localError || error;

  return (
    <Modal isOpen={isOpen} onClose={handleClose}>
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-md mx-4">
        {/* ヘッダー */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-xl font-bold text-gray-800 dark:text-white">
            {mode === 'login' ? 'ログイン' : '新規登録'}
          </h2>
          <button
            onClick={handleClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
          >
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        {/* コンテンツ */}
        <div className="p-6">
          {/* エラー表示 */}
          {displayError && (
            <div className="mb-4 p-3 bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-lg flex items-center gap-2 text-red-700 dark:text-red-400">
              <AlertCircle size={18} />
              <span className="text-sm">{displayError}</span>
            </div>
          )}

          {/* Googleログイン */}
          <button
            type="button"
            onClick={handleGoogleLogin}
            disabled={loading}
            className="w-full flex items-center justify-center gap-3 px-4 py-3 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Chrome size={20} className="text-blue-500" />
            <span className="font-medium text-gray-700 dark:text-gray-200">
              Googleでログイン
            </span>
          </button>

          {/* 区切り線 */}
          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-300 dark:border-gray-600" />
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-white dark:bg-gray-800 text-gray-500">
                または
              </span>
            </div>
          </div>

          {/* メール/パスワードフォーム */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                メールアドレス
              </label>
              <div className="relative">
                <Mail size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="example@email.com"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                パスワード
              </label>
              <div className="relative">
                <Lock size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={6}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  placeholder="6文字以上"
                />
              </div>
            </div>

            {mode === 'register' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  パスワード（確認）
                </label>
                <div className="relative">
                  <Lock size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                    minLength={6}
                    className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="パスワードを再入力"
                  />
                </div>
              </div>
            )}

            <Button
              type="submit"
              className="w-full"
              disabled={loading}
            >
              {loading ? '処理中...' : mode === 'login' ? 'ログイン' : '登録'}
            </Button>
          </form>

          {/* モード切り替え */}
          <div className="mt-4 text-center text-sm text-gray-600 dark:text-gray-400">
            {mode === 'login' ? (
              <>
                アカウントをお持ちでないですか？{' '}
                <button
                  type="button"
                  onClick={switchMode}
                  className="text-primary-600 dark:text-primary-400 hover:underline font-medium"
                >
                  新規登録
                </button>
              </>
            ) : (
              <>
                既にアカウントをお持ちですか？{' '}
                <button
                  type="button"
                  onClick={switchMode}
                  className="text-primary-600 dark:text-primary-400 hover:underline font-medium"
                >
                  ログイン
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </Modal>
  );
};
