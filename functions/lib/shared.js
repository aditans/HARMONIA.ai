"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isNonEmptyString = isNonEmptyString;
exports.requireString = requireString;
exports.requireNumber = requireNumber;
exports.formatSessionSummary = formatSessionSummary;
function isNonEmptyString(value) {
    return typeof value === 'string' && value.trim().length > 0;
}
function requireString(value, fieldName) {
    if (!isNonEmptyString(value)) {
        throw new Error(`INVALID_ARGUMENT: ${fieldName} must be a non-empty string`);
    }
    return value.trim();
}
function requireNumber(value, fieldName) {
    if (typeof value !== 'number' || Number.isNaN(value)) {
        throw new Error(`INVALID_ARGUMENT: ${fieldName} must be a number`);
    }
    return value;
}
function formatSessionSummary(session) {
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
