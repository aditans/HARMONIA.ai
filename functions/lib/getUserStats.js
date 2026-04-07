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
exports.getUserStats = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const shared_1 = require("./shared");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
function weekKey(date) {
    const value = date instanceof Date ? date : date.toDate();
    return value.toISOString().slice(0, 10);
}
exports.getUserStats = (0, https_1.onCall)({ invoker: 'public' }, async (request) => {
    const uid = (0, shared_1.requireString)(request.data?.uid, 'uid');
    if (!request.auth || request.auth.uid !== uid) {
        throw new https_1.HttpsError('permission-denied', 'You can only read stats for your own account.', {
            code: 'auth_mismatch',
        });
    }
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError('not-found', 'User profile not found.', { code: 'user_missing' });
    }
    const sessionsSnapshot = await db.collection('sessions').where('uid', '==', uid).get();
    let totalWorkoutMinutes = 0;
    let totalFocusMinutes = 0;
    const weeklyBreakdown = {};
    sessionsSnapshot.forEach((doc) => {
        const data = doc.data();
        const durationMinutes = (typeof data.durationSeconds === 'number' ? data.durationSeconds : 0) / 60;
        const startedAt = data.startedAt;
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
