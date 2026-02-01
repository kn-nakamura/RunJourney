/**
 * useMarathons.js
 *
 * マラソンデータの管理と操作を行うカスタムフック
 * Firebase認証時はFirestore、未認証時はLocalStorageを使用
 */

import { useState, useMemo, useEffect, useCallback } from 'react';
import { useLocalStorage } from './useLocalStorage';
import { STORAGE_KEYS } from '../constants/config';
import { addBestFlags, calculatePBs, calculateSBs } from '../utils/calculations';
import {
  isFirebaseConfigured,
  subscribeToMarathons,
  addMarathonToFirestore,
  updateMarathonInFirestore,
  deleteMarathonFromFirestore,
  clearAllMarathonsInFirestore,
  importMarathonsToFirestore
} from '../services/firebase';

/**
 * マラソンデータ管理フック
 * @param {Object|null} user - 認証ユーザー（nullの場合はLocalStorage使用）
 * @returns {Object} マラソン管理機能
 */
export const useMarathons = (user = null) => {
  const [localMarathons, setLocalMarathons] = useLocalStorage(
    STORAGE_KEYS.MARATHONS,
    []
  );
  const [firebaseMarathons, setFirebaseMarathons] = useState([]);
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [loading, setLoading] = useState(false);

  // Firebase使用するかどうか
  const useFirebase = user && isFirebaseConfigured();

  // 実際に使用するマラソンデータ
  const marathons = useFirebase ? firebaseMarathons : localMarathons;

  // Firestoreのリアルタイム購読
  useEffect(() => {
    if (!useFirebase) {
      setFirebaseMarathons([]);
      return;
    }

    setLoading(true);
    const unsubscribe = subscribeToMarathons(user.uid, (data) => {
      setFirebaseMarathons(data);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [user, useFirebase]);

  /**
   * 新しいマラソンを追加
   * @param {Object} marathon - マラソンデータ
   */
  const addMarathon = useCallback(async (marathon) => {
    if (useFirebase) {
      try {
        await addMarathonToFirestore(user.uid, marathon);
      } catch (error) {
        console.error('Failed to add marathon to Firestore:', error);
        throw error;
      }
    } else {
      const newMarathon = {
        ...marathon,
        id: `marathon-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        createdAt: new Date().toISOString(),
      };
      setLocalMarathons([...localMarathons, newMarathon]);
    }
  }, [useFirebase, user, localMarathons, setLocalMarathons]);

  /**
   * マラソンを更新
   * @param {string} id - マラソンID
   * @param {Object} updates - 更新データ
   */
  const updateMarathon = useCallback(async (id, updates) => {
    if (useFirebase) {
      try {
        await updateMarathonInFirestore(user.uid, id, updates);
      } catch (error) {
        console.error('Failed to update marathon in Firestore:', error);
        throw error;
      }
    } else {
      setLocalMarathons(
        localMarathons.map((m) =>
          m.id === id ? { ...m, ...updates, updatedAt: new Date().toISOString() } : m
        )
      );
    }
  }, [useFirebase, user, localMarathons, setLocalMarathons]);

  /**
   * マラソンを削除
   * @param {string} id - マラソンID
   */
  const deleteMarathon = useCallback(async (id) => {
    if (useFirebase) {
      try {
        await deleteMarathonFromFirestore(user.uid, id);
      } catch (error) {
        console.error('Failed to delete marathon from Firestore:', error);
        throw error;
      }
    } else {
      setLocalMarathons(localMarathons.filter((m) => m.id !== id));
    }
  }, [useFirebase, user, localMarathons, setLocalMarathons]);

  /**
   * すべてのマラソンを削除
   */
  const clearAllMarathons = useCallback(async () => {
    if (useFirebase) {
      try {
        await clearAllMarathonsInFirestore(user.uid);
      } catch (error) {
        console.error('Failed to clear all marathons from Firestore:', error);
        throw error;
      }
    } else {
      setLocalMarathons([]);
    }
  }, [useFirebase, user, setLocalMarathons]);

  /**
   * マラソンデータをインポート
   * @param {Array} importedMarathons - インポートするマラソンデータ
   * @param {boolean} merge - 既存データとマージするか
   */
  const importMarathons = useCallback(async (importedMarathons, merge = false) => {
    if (useFirebase) {
      try {
        await importMarathonsToFirestore(user.uid, importedMarathons, merge);
      } catch (error) {
        console.error('Failed to import marathons to Firestore:', error);
        throw error;
      }
    } else {
      if (merge) {
        // マージ: 既存データに追加
        const newMarathons = importedMarathons.map((m) => ({
          ...m,
          id: m.id || `marathon-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        }));
        setLocalMarathons((prev) => [...prev, ...newMarathons]);
      } else {
        // 上書き: すべて置き換え
        const marathonsWithIds = importedMarathons.map((m) => ({
          ...m,
          id: m.id || `marathon-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        }));
        setLocalMarathons(marathonsWithIds);
      }
    }
  }, [useFirebase, user, setLocalMarathons]);

  /**
   * LocalStorageからFirestoreへデータを移行
   */
  const migrateToFirebase = useCallback(async () => {
    if (!useFirebase || localMarathons.length === 0) return;

    try {
      await importMarathonsToFirestore(user.uid, localMarathons, true);
      setLocalMarathons([]); // ローカルデータをクリア
    } catch (error) {
      console.error('Failed to migrate data to Firebase:', error);
      throw error;
    }
  }, [useFirebase, user, localMarathons, setLocalMarathons]);

  // PB/SBフラグ付きマラソンデータ
  const marathonsWithFlags = useMemo(
    () => addBestFlags(marathons, selectedYear),
    [marathons, selectedYear]
  );

  // PB計算
  const pbs = useMemo(() => calculatePBs(marathons), [marathons]);

  // SB計算
  const sbs = useMemo(
    () => calculateSBs(marathons, selectedYear),
    [marathons, selectedYear]
  );

  return {
    marathons: marathonsWithFlags,
    rawMarathons: marathons,
    addMarathon,
    updateMarathon,
    deleteMarathon,
    clearAllMarathons,
    importMarathons,
    migrateToFirebase,
    pbs,
    sbs,
    selectedYear,
    setSelectedYear,
    loading,
    useFirebase,
    hasLocalData: localMarathons.length > 0
  };
};
