"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.saveSession = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const shared_1 = require("./shared");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
function validateSessionInput(raw) {
    if (typeof raw !== 'object' || raw === null) {
        throw new https_1.HttpsError('invalid-argument', 'Session payload must be an object.', { code: 'invalid_payload' });
    }
    const payload = raw;
    const uid = (0, shared_1.requireString)(payload.uid, 'uid');
    const type = (0, shared_1.requireString)(payload.type, 'type');
    const durationSeconds = (0, shared_1.requireNumber)(payload.durationSeconds, 'durationSeconds');
    const metrics = typeof payload.metrics === 'object' && payload.metrics !== null ? payload.metrics : {};
    if (!['exercise', 'yoga', 'focus'].includes(type)) {
        throw new https_1.HttpsError('invalid-argument', 'type must be exercise, yoga, or focus.', { code: 'invalid_type' });
    }
    return {
        uid,
        type,
        durationSeconds,
        metrics,
        startedAt: payload.startedAt,
        endedAt: payload.endedAt,
    };
}
exports.saveSession = (0, https_1.onCall)({ invoker: 'public' }, async (request) => {
    const session = validateSessionInput(request.data);
    if (!request.auth || request.auth.uid !== session.uid) {
        throw new https_1.HttpsError('permission-denied', 'You can only save sessions for your own account.', {
            code: 'auth_mismatch',
        });
    }
    const sessionRef = db.collection('sessions').doc();
    const userRef = db.collection('users').doc(session.uid);
    await db.runTransaction(async (transaction) => {
        transaction.set(sessionRef, {
            ...session,
            startedAt: session.startedAt ?? firestore_1.FieldValue.serverTimestamp(),
            endedAt: session.endedAt ?? firestore_1.FieldValue.serverTimestamp(),
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
        transaction.set(userRef, {
            totalSessions: firestore_1.FieldValue.increment(1),
        }, { merge: true });
    });
    return { sessionId: sessionRef.id };
});
