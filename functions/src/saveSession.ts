import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { SessionDocument, requireNumber, requireString } from './shared';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function validateSessionInput(raw: unknown): SessionDocument {
  if (typeof raw !== 'object' || raw === null) {
    throw new HttpsError('invalid-argument', 'Session payload must be an object.', { code: 'invalid_payload' });
  }

  const payload = raw as Record<string, unknown>;
  const uid = requireString(payload.uid, 'uid');
  const type = requireString(payload.type, 'type') as SessionDocument['type'];
  const durationSeconds = requireNumber(payload.durationSeconds, 'durationSeconds');
  const metrics = typeof payload.metrics === 'object' && payload.metrics !== null ? (payload.metrics as Record<string, unknown>) : {};

  if (!['exercise', 'yoga', 'focus'].includes(type)) {
    throw new HttpsError('invalid-argument', 'type must be exercise, yoga, or focus.', { code: 'invalid_type' });
  }

  return {
    uid,
    type,
    durationSeconds,
    metrics,
    startedAt: payload.startedAt as admin.firestore.Timestamp | admin.firestore.FieldValue | undefined,
    endedAt: payload.endedAt as admin.firestore.Timestamp | admin.firestore.FieldValue | undefined,
  };
}

export const saveSession = onCall({ invoker: 'public' }, async (request) => {
  const session = validateSessionInput(request.data);
  if (!request.auth || request.auth.uid !== session.uid) {
    throw new HttpsError('permission-denied', 'You can only save sessions for your own account.', {
      code: 'auth_mismatch',
    });
  }

  const sessionRef = db.collection('sessions').doc();
  const userRef = db.collection('users').doc(session.uid);

  await db.runTransaction(async (transaction) => {
    transaction.set(sessionRef, {
      ...session,
      startedAt: session.startedAt ?? FieldValue.serverTimestamp(),
      endedAt: session.endedAt ?? FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.set(
      userRef,
      {
        totalSessions: FieldValue.increment(1),
      },
      { merge: true },
    );
  });

  return { sessionId: sessionRef.id };
});
