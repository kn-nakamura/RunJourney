/**
 * useAuth.js
 *
 * Firebase認証を管理するカスタムフック
 */

import { useState, useEffect, useCallback, createContext, useContext } from 'react';
import {
  isFirebaseConfigured,
  onAuthChange,
  signInWithEmail,
  signUpWithEmail,
  signInWithGoogle,
  logout
} from '../services/firebase';

// 認証コンテキスト
const AuthContext = createContext(null);

/**
 * 認証プロバイダーコンポーネント
 */
export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const firebaseEnabled = isFirebaseConfigured();

  // 認証状態の監視
  useEffect(() => {
    if (!firebaseEnabled) {
      setLoading(false);
      return;
    }

    const unsubscribe = onAuthChange((user) => {
      setUser(user);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [firebaseEnabled]);

  /**
   * メール/パスワードでログイン
   */
  const login = useCallback(async (email, password) => {
    if (!firebaseEnabled) {
      throw new Error('Firebase is not configured');
    }

    setError(null);
    try {
      const result = await signInWithEmail(email, password);
      return result.user;
    } catch (err) {
      setError(getErrorMessage(err.code));
      throw err;
    }
  }, [firebaseEnabled]);

  /**
   * メール/パスワードで新規登録
   */
  const register = useCallback(async (email, password) => {
    if (!firebaseEnabled) {
      throw new Error('Firebase is not configured');
    }

    setError(null);
    try {
      const result = await signUpWithEmail(email, password);
      return result.user;
    } catch (err) {
      setError(getErrorMessage(err.code));
      throw err;
    }
  }, [firebaseEnabled]);

  /**
   * Googleでログイン
   */
  const loginWithGoogle = useCallback(async () => {
    if (!firebaseEnabled) {
      throw new Error('Firebase is not configured');
    }

    setError(null);
    try {
      const result = await signInWithGoogle();
      return result.user;
    } catch (err) {
      setError(getErrorMessage(err.code));
      throw err;
    }
  }, [firebaseEnabled]);

  /**
   * ログアウト
   */
  const signOut = useCallback(async () => {
    if (!firebaseEnabled) {
      throw new Error('Firebase is not configured');
    }

    setError(null);
    try {
      await logout();
    } catch (err) {
      setError(getErrorMessage(err.code));
      throw err;
    }
  }, [firebaseEnabled]);

  /**
   * エラーをクリア
   */
  const clearError = useCallback(() => {
    setError(null);
  }, []);

  const value = {
    user,
    loading,
    error,
    firebaseEnabled,
    login,
    register,
    loginWithGoogle,
    signOut,
    clearError
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

/**
 * 認証フック
 */
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

/**
 * Firebase認証エラーメッセージの日本語変換
 */
const getErrorMessage = (code) => {
  const messages = {
    'auth/email-already-in-use': 'このメールアドレスは既に使用されています',
    'auth/invalid-email': 'メールアドレスの形式が正しくありません',
    'auth/operation-not-allowed': 'この操作は許可されていません',
    'auth/weak-password': 'パスワードは6文字以上で入力してください',
    'auth/user-disabled': 'このアカウントは無効化されています',
    'auth/user-not-found': 'ユーザーが見つかりません',
    'auth/wrong-password': 'パスワードが正しくありません',
    'auth/invalid-credential': 'メールアドレスまたはパスワードが正しくありません',
    'auth/too-many-requests': 'リクエストが多すぎます。しばらくしてから再試行してください',
    'auth/popup-closed-by-user': 'ログインがキャンセルされました',
    'auth/network-request-failed': 'ネットワークエラーが発生しました',
  };
  return messages[code] || 'エラーが発生しました';
};

export default useAuth;
