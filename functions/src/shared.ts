import * as admin from 'firebase-admin';

export type SessionType = 'exercise' | 'yoga' | 'focus';

export interface SessionDocument {
  uid: string;
  type: SessionType;
  startedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  endedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  durationSeconds: number;
  metrics: Record<string, unknown>;
}

export interface CallableErrorDetails {
  code: string;
  message: string;
}

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function requireString(value: unknown, fieldName: string): string {
  if (!isNonEmptyString(value)) {
    throw new Error(`INVALID_ARGUMENT: ${fieldName} must be a non-empty string`);
  }
  return value.trim();
}

export function requireNumber(value: unknown, fieldName: string): number {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    throw new Error(`INVALID_ARGUMENT: ${fieldName} must be a number`);
  }
  return value;
}

export function formatSessionSummary(session: admin.firestore.DocumentData): string {
  const type = session.type ?? 'session';
  const metrics = session.metrics ?? {};

  if (type === 'exercise') {
    return `Exercise: ${metrics.exercise ?? 'workout'} ${metrics.reps ?? 0} reps, ${metrics.sets ?? 0} sets, avg angle ${metrics.avgAngle ?? 0}`;
  }
  if (type === 'yoga') {
    return `Yoga: ${metrics.pose ?? 'pose'} hold ${metrics.holdDurationSec ?? 0}s, stability ${metrics.stabilityScore ?? 0}, accuracy ${metrics.accuracyScore ?? 0}`;
  }
  return `Focus: ${metrics.focusPercent ?? 0}% focus, ${metrics.distractionEvents ?? 0} distractions, ${metrics.pomodorosCompleted ?? 0} pomodoros`;
}
