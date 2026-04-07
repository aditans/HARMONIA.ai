import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { requireString } from './shared';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function weekKey(date: admin.firestore.Timestamp | Date): string {
  const value = date instanceof Date ? date : date.toDate();
  return value.toISOString().slice(0, 10);
}

export const getUserStats = onCall({ invoker: 'public' }, async (request) => {
  const uid = requireString(request.data?.uid, 'uid');
  if (!request.auth || request.auth.uid !== uid) {
    throw new HttpsError('permission-denied', 'You can only read stats for your own account.', {
      code: 'auth_mismatch',
    });
  }

  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError('not-found', 'User profile not found.', { code: 'user_missing' });
  }

  const sessionsSnapshot = await db.collection('sessions').where('uid', '==', uid).get();

  let totalWorkoutMinutes = 0;
  let totalFocusMinutes = 0;
  const weeklyBreakdown: Record<string, { workoutMinutes: number; focusMinutes: number }> = {};

  sessionsSnapshot.forEach((doc) => {
    const data = doc.data();
    const durationMinutes = (typeof data.durationSeconds === 'number' ? data.durationSeconds : 0) / 60;
    const startedAt = data.startedAt as admin.firestore.Timestamp | undefined;
    const bucket = weekKey(startedAt ?? new Date());

    if (!weeklyBreakdown[bucket]) {
      weeklyBreakdown[bucket] = { workoutMinutes: 0, focusMinutes: 0 };
    }

    if (data.type === 'exercise' || data.type === 'yoga') {
      totalWorkoutMinutes += durationMinutes;
      weeklyBreakdown[bucket].workoutMinutes += durationMinutes;
    }

    if (data.type === 'focus') {
      totalFocusMinutes += durationMinutes;
      weeklyBreakdown[bucket].focusMinutes += durationMinutes;
    }
  });

  const userData = userDoc.data();
  return {
    totalWorkoutMinutes: Math.round(totalWorkoutMinutes),
    totalFocusMinutes: Math.round(totalFocusMinutes),
    streakDays: userData?.streakDays ?? 0,
    weeklyBreakdown,
  };
});
