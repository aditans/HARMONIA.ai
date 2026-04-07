export declare const getUserStats: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    totalWorkoutMinutes: number;
    totalFocusMinutes: number;
    streakDays: any;
    weeklyBreakdown: Record<string, {
        workoutMinutes: number;
        focusMinutes: number;
    }>;
}>, unknown>;
