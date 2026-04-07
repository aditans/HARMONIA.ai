# Button Click Flow Debugging

## Expected Flow
1. User sees "Start" button
2. User clicks button → onStartPausePressed callback triggered
3. _toggleStartPause(state) is called with state.isRunning=false
4. _startCountdown() is called
5. setState sets _countdown = 3
6. Timer.periodic fires every 1 second:
   - Tick 1: _countdown = 2
   - Tick 2: _countdown = 1  
   - Tick 3: _countdown <= 1, so startSession() is called
7. startSession() updates controller state to isRunning=true
8. ref.watch triggers rebuild with new state
9. Button changes to "Pause"
10. Overlay displays countdown: 3, 2, 1, 0

## Common Failure Points
- [ ] Button callback not connected
- [ ] _toggleStartPause not executing
- [ ] _startCountdown not executing  
- [ ] Timer not firing
- [ ] setState not working
- [ ] startSession not updating state
- [ ] ref.watch not detecting state change
- [ ] Build not being called with new state

## What We Know From Logs
- "Yoga camera ready" ✓
- "Focus camera ready" ✓  
- **"Exercise camera ready" ✗ MISSING**

This suggests ExerciseScreen may not be the current screen when user clicks.
