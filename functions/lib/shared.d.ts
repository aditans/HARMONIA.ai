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
export declare function isNonEmptyString(value: unknown): value is string;
export declare function requireString(value: unknown, fieldName: string): string;
export declare function requireNumber(value: unknown, fieldName: string): number;
export declare function formatSessionSummary(session: admin.firestore.DocumentData): string;
