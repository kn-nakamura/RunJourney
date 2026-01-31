/**
 * firebase.js
 *
 * Firebase設定と初期化
 * Authentication、Firestoreを使用
 */

import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  onAuthStateChanged
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  orderBy,
  onSnapshot,
  writeBatch
} from 'firebase/firestore';

// Firebase設定（環境変数から読み込み）
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};

// Firebase初期化（設定がある場合のみ）
let app = null;
let auth = null;
let db = null;
let googleProvider = null;

const isFirebaseConfigured = () => {
  return firebaseConfig.apiKey && firebaseConfig.projectId;
};

if (isFirebaseConfigured()) {
  app = initializeApp(firebaseConfig);
  auth = getAuth(app);
  db = getFirestore(app);
  googleProvider = new GoogleAuthProvider();
}

// ====== 認証関連 ======

/**
 * メール/パスワードでサインイン
 */
export const signInWithEmail = async (email, password) => {
  if (!auth) throw new Error('Firebase is not configured');
  return signInWithEmailAndPassword(auth, email, password);
};

/**
 * メール/パスワードで新規登録
 */
export const signUpWithEmail = async (email, password) => {
  if (!auth) throw new Error('Firebase is not configured');
  return createUserWithEmailAndPassword(auth, email, password);
};

/**
 * Googleでサインイン
 */
export const signInWithGoogle = async () => {
  if (!auth || !googleProvider) throw new Error('Firebase is not configured');
  return signInWithPopup(auth, googleProvider);
};

/**
 * サインアウト
 */
export const logout = async () => {
  if (!auth) throw new Error('Firebase is not configured');
  return signOut(auth);
};

/**
 * 認証状態の変更を監視
 */
export const onAuthChange = (callback) => {
  if (!auth) {
    callback(null);
    return () => {};
  }
  return onAuthStateChanged(auth, callback);
};

// ====== Firestore（マラソンデータ）関連 ======

/**
 * ユーザーのマラソンコレクション参照を取得
 */
const getUserMarathonsRef = (userId) => {
  if (!db) throw new Error('Firebase is not configured');
  return collection(db, 'users', userId, 'marathons');
};

/**
 * マラソンデータをリアルタイムで購読
 */
export const subscribeToMarathons = (userId, callback) => {
  if (!db) {
    callback([]);
    return () => {};
  }

  const marathonsRef = getUserMarathonsRef(userId);
  const q = query(marathonsRef, orderBy('date', 'desc'));

  return onSnapshot(q, (snapshot) => {
    const marathons = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    callback(marathons);
  }, (error) => {
    console.error('Failed to subscribe to marathons:', error);
    callback([]);
  });
};

/**
 * マラソンを追加
 */
export const addMarathonToFirestore = async (userId, marathon) => {
  if (!db) throw new Error('Firebase is not configured');
  const marathonsRef = getUserMarathonsRef(userId);
  const docRef = await addDoc(marathonsRef, {
    ...marathon,
    createdAt: new Date().toISOString()
  });
  return docRef.id;
};

/**
 * マラソンを更新
 */
export const updateMarathonInFirestore = async (userId, marathonId, updates) => {
  if (!db) throw new Error('Firebase is not configured');
  const marathonRef = doc(db, 'users', userId, 'marathons', marathonId);
  await updateDoc(marathonRef, {
    ...updates,
    updatedAt: new Date().toISOString()
  });
};

/**
 * マラソンを削除
 */
export const deleteMarathonFromFirestore = async (userId, marathonId) => {
  if (!db) throw new Error('Firebase is not configured');
  const marathonRef = doc(db, 'users', userId, 'marathons', marathonId);
  await deleteDoc(marathonRef);
};

/**
 * すべてのマラソンを削除
 */
export const clearAllMarathonsInFirestore = async (userId) => {
  if (!db) throw new Error('Firebase is not configured');
  const marathonsRef = getUserMarathonsRef(userId);
  const snapshot = await getDocs(marathonsRef);

  const batch = writeBatch(db);
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
};

/**
 * マラソンデータを一括インポート
 */
export const importMarathonsToFirestore = async (userId, marathons, merge = false) => {
  if (!db) throw new Error('Firebase is not configured');

  // マージしない場合は既存データを削除
  if (!merge) {
    await clearAllMarathonsInFirestore(userId);
  }

  const marathonsRef = getUserMarathonsRef(userId);
  const batch = writeBatch(db);

  marathons.forEach((marathon) => {
    const docRef = doc(marathonsRef);
    batch.set(docRef, {
      ...marathon,
      id: undefined, // Firestoreが自動生成
      createdAt: marathon.createdAt || new Date().toISOString()
    });
  });

  await batch.commit();
};

// ====== ユーティリティ ======

/**
 * Firebaseが設定されているかチェック
 */
export { isFirebaseConfigured };

/**
 * 認証インスタンスをエクスポート
 */
export { auth, db };
