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
exports.getAIResponse = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const shared_1 = require("./shared");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const geminiKey = (0, params_1.defineSecret)('GEMINI_API_KEY');
async function callGemini(prompt, userMessage) {
    const apiKey = geminiKey.value();
    if (!apiKey) {
        throw new https_1.HttpsError('failed-precondition', 'GEMINI_API_KEY is not configured.', { code: 'missing-api-key' });
    }
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            systemInstruction: { parts: [{ text: prompt }] },
            contents: [{ role: 'user', parts: [{ text: userMessage }] }],
            generationConfig: { maxOutputTokens: 300, temperature: 0.7 },
        }),
    });
    if (!response.ok) {
        throw new https_1.HttpsError('internal', 'Gemini request failed.', { code: 'gemini_error', status: response.status });
    }
    const data = (await response.json());
    return data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? 'I could not generate a response right now.';
}
exports.getAIResponse = (0, https_1.onCall)({ secrets: [geminiKey], invoker: 'public' }, async (request) => {
    const message = (0, shared_1.requireString)(request.data?.message, 'message');
    const uid = (0, shared_1.requireString)(request.data?.uid, 'uid');
    if (!request.auth || request.auth.uid !== uid) {
        throw new https_1.HttpsError('permission-denied', 'You can only request AI responses for your own account.', {
            code: 'auth_mismatch',
        });
    }
    const sessionsSnapshot = await db
        .collection('sessions')
        .where('uid', '==', uid)
        .orderBy('startedAt', 'desc')
        .limit(10)
        .get();
    const timeline = sessionsSnapshot.docs.map((doc) => (0, shared_1.formatSessionSummary)(doc.data())).join('\n');
    const dateInIndia = new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' });
    const systemPrompt = [
        'You are Harmonia, a warm and encouraging AI wellness coach.',
        'Use user activity history for specific and personalized suggestions.',
        'Never provide medical advice and keep default responses concise.',
        'User recent activity:',
        timeline || 'No prior sessions found.',
        `Today\'s date: ${dateInIndia}`,
    ].join('\n\n');
    const reply = await callGemini(systemPrompt, message);
    await db.collection('chatHistory').doc(uid).collection('messages').add({
        role: 'assistant',
        content: reply,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { reply };
});
