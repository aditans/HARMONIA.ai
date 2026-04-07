import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { formatSessionSummary, requireString } from './shared';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const geminiKey = defineSecret('GEMINI_API_KEY');

async function callGemini(prompt: string, userMessage: string) {
  const apiKey = geminiKey.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'GEMINI_API_KEY is not configured.', { code: 'missing-api-key' });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: prompt }] },
        contents: [{ role: 'user', parts: [{ text: userMessage }] }],
        generationConfig: { maxOutputTokens: 300, temperature: 0.7 },
      }),
    },
  );

  if (!response.ok) {
    throw new HttpsError('internal', 'Gemini request failed.', { code: 'gemini_error', status: response.status });
  }

  const data = (await response.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };

  return data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? 'I could not generate a response right now.';
}

export const getAIResponse = onCall({ secrets: [geminiKey], invoker: 'public' }, async (request) => {
  const message = requireString(request.data?.message, 'message');
  const uid = requireString(request.data?.uid, 'uid');

  if (!request.auth || request.auth.uid !== uid) {
    throw new HttpsError('permission-denied', 'You can only request AI responses for your own account.', {
      code: 'auth_mismatch',
    });
  }

  const sessionsSnapshot = await db
    .collection('sessions')
    .where('uid', '==', uid)
    .orderBy('startedAt', 'desc')
    .limit(10)
    .get();

  const timeline = sessionsSnapshot.docs.map((doc) => formatSessionSummary(doc.data())).join('\n');
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
