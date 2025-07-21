# watchOS Game Tracking Engine - Manual Testing Guide

## Prerequisites for Testing

### 1. Development Setup
```bash
# Ensure Xcode project builds successfully
cd /Users/furkan/SoccerX/iOS
xcodebuild -scheme SoccerXWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

### 2. Required Test Devices
- **Physical Apple Watch** (Series 4+ recommended)
- **iPhone paired with Apple Watch**
- **Xcode with watchOS simulator** (for basic UI testing)

### 3. Test Environment Setup
- Enable Developer Mode on Apple Watch
- Install app via Xcode to physical device
- Ensure HealthKit permissions are available

## Manual Testing Checklist

### Phase 1: Permission and Setup Testing

#### ✅ Test 1.1: HealthKit Permission Flow
**Steps:**
1. Launch SoccerXWatch app on Apple Watch
2. Verify permission request screen appears
3. Tap "Enable Tracking" button
4. Confirm HealthKit permission dialog appears
5. Accept all permissions
6. Verify app transitions to home screen

**Expected Results:**
- ✅ Permission screen displays correctly
- ✅ HealthKit permissions granted
- ✅ Core Motion access granted
- ✅ Location permission granted
- ✅ App navigates to main interface

#### ✅ Test 1.2: Permission Denied Scenarios
**Steps:**
1. Reset app permissions in Settings
2. Launch app and deny HealthKit permissions
3. Verify error handling and user guidance

**Expected Results:**
- ✅ Clear error message shown
- ✅ Instructions to enable in Settings
- ✅ App remains functional with limited features

### Phase 2: Core Workout Functionality

#### ✅ Test 2.1: Workout Session Lifecycle
**Steps:**
1. Open tracking view
2. Start countdown (test different durations: 3s, 5s, 10s)
3. Let countdown complete and verify workout starts
4. Verify workout session begins in HealthKit
5. Pause workout after 2 minutes
6. Resume workout
7. End workout after 5+ minutes

**Expected Results:**
- ✅ Countdown displays correctly
- ✅ Workout session starts automatically
- ✅ Heart rate data appears within 30 seconds
- ✅ Pause/resume works without data loss
- ✅ Workout saves to HealthKit app

#### ✅ Test 2.2: Real-time Data Collection
**Steps:**
1. Start workout and move around
2. Check heart rate updates (should update every 1-5 seconds)
3. Walk/run to test speed calculation
4. Verify distance accumulation
5. Check GPS signal strength indicator

**Expected Results:**
- ✅ Heart rate updates regularly
- ✅ Speed reflects actual movement
- ✅ Distance increases accurately
- ✅ GPS signal strength changes with location

### Phase 3: Adaptive GPS and Battery Optimization

#### ✅ Test 3.1: GPS Accuracy Adaptation
**Test Scenario A: Stationary**
1. Start workout while standing still
2. Wait 30 seconds
3. Check GPS accuracy mode (should be Low/Medium)

**Test Scenario B: Active Movement**
1. Start running/jogging
2. Maintain speed > 2 m/s for 1 minute
3. Check GPS accuracy mode (should be High)

**Test Scenario C: Mixed Activity**
1. Alternate between walking and running
2. Observe GPS accuracy changes
3. Verify 10-second delay before switching

**Expected Results:**
- ✅ GPS accuracy adapts based on speed
- ✅ Higher accuracy during active movement
- ✅ Lower accuracy during stationary periods
- ✅ Smooth transitions between modes

#### ✅ Test 3.2: Battery Optimization
**Steps:**
1. Start with Apple Watch at 50-75% battery
2. Begin tracking session
3. Monitor battery optimization indicators
4. Test force optimization feature
5. Verify estimated remaining time updates

**Expected Results:**
- ✅ Battery level displays accurately
- ✅ Optimization recommendations appear at <25%
- ✅ Sensor frequencies adjust based on battery
- ✅ Estimated time calculation is reasonable

### Phase 4: User Interface Testing

#### ✅ Test 4.1: Main Tracking Interface
**Steps:**
1. Navigate through all tracking tabs using Digital Crown
2. Verify data displays on each tab:
   - Main: Time, distance, speed, heart rate, calories
   - Heart Rate: Current, zones, average
   - Speed: Current, average, max, pace categories
   - Splits: 10-minute intervals (after 10+ minutes)
   - Calories: Total, burn rate, projections

**Expected Results:**
- ✅ All tabs accessible via Digital Crown
- ✅ Data updates in real-time
- ✅ UI responsive and readable
- ✅ No UI glitches or freezing

#### ✅ Test 4.2: Status Indicators
**Steps:**
1. Check GPS signal strength indicator
2. Verify battery level display
3. Confirm activity level indicator
4. Test various signal conditions (indoor/outdoor)

**Expected Results:**
- ✅ GPS indicator reflects actual signal quality
- ✅ Battery indicator matches device battery
- ✅ Activity level changes with movement
- ✅ Colors and icons display correctly

### Phase 5: Data Persistence and Edge Cases

#### ✅ Test 5.1: Local Data Storage
**Steps:**
1. Complete a 5+ minute workout
2. Force quit the app
3. Restart app and check if data persisted
4. Verify game session saved locally

**Expected Results:**
- ✅ Workout data persists app restart
- ✅ No data loss during crashes
- ✅ Game session stored with correct metadata

#### ✅ Test 5.2: Edge Case Scenarios
**Test A: Poor GPS Signal**
1. Start workout indoors (poor GPS)
2. Move to outdoor area (good GPS)
3. Verify app handles transition smoothly

**Test B: Heart Rate Monitor Issues**
1. Ensure watch is loose on wrist
2. Start workout with poor heart rate contact
3. Tighten watch and verify heart rate recovery

**Test C: Low Battery Scenarios**
1. Test with Apple Watch at <20% battery
2. Verify battery optimization activates
3. Check if tracking continues with reduced features

**Expected Results:**
- ✅ Graceful handling of signal loss
- ✅ Recovery when conditions improve
- ✅ No app crashes or data corruption

### Phase 6: Performance and Memory Testing

#### ✅ Test 6.1: Long Session Testing
**Steps:**
1. Run 30+ minute tracking session
2. Monitor app responsiveness
3. Check memory usage doesn't grow excessively
4. Verify data aggregation works over time

**Expected Results:**
- ✅ App remains responsive after 30+ minutes
- ✅ No memory leaks or excessive usage
- ✅ Data continues aggregating properly
- ✅ No performance degradation

#### ✅ Test 6.2: Data Compression Testing
**Steps:**
1. Complete workout with extensive GPS data
2. Check compressed data size vs uncompressed
3. Verify data integrity after compression

**Expected Results:**
- ✅ 60-80% compression ratio achieved
- ✅ Data integrity maintained
- ✅ No corruption in compressed data

## Testing Results Documentation

### Test Session Template
```
Date: ___________
Tester: ___________
Apple Watch Model: ___________
watchOS Version: ___________

Test Results:
[ ] Phase 1: Permission and Setup - PASS/FAIL
[ ] Phase 2: Core Workout Functionality - PASS/FAIL  
[ ] Phase 3: Adaptive GPS and Battery - PASS/FAIL
[ ] Phase 4: User Interface - PASS/FAIL
[ ] Phase 5: Data Persistence - PASS/FAIL
[ ] Phase 6: Performance - PASS/FAIL

Issues Found:
1. ___________
2. ___________
3. ___________

Notes:
___________
```

## Quick Validation Commands

### Build and Run Tests
```bash
# Build for watchOS Simulator
xcodebuild -scheme SoccerXWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Build for physical device
xcodebuild -scheme SoccerXWatch -destination 'platform=watchOS,name=Your Apple Watch' build

# Check for build errors
xcodebuild -scheme SoccerXWatch clean build | grep -i error
```

### Health Data Verification
1. Open HealthKit app on iPhone
2. Navigate to Browse > Activity > Workouts
3. Verify SoccerX workouts appear with correct data

### Storage Verification
```swift
// Add this debug code to check local storage
Task {
    let sessions = await LocalStorageManager.shared.getUnsyncedSessions()
    print("Stored sessions: \(sessions.count)")
    print("Storage used: \(LocalStorageManager.shared.storageUsed) bytes")
}
```

## Success Criteria

The implementation is considered correct when:
- ✅ All 6 test phases pass without critical failures
- ✅ Workouts save correctly to HealthKit
- ✅ GPS tracking accuracy adapts properly
- ✅ Battery optimization functions as expected
- ✅ UI remains responsive during 30+ minute sessions
- ✅ Data persists across app launches
- ✅ No memory leaks or crashes observed

## Next Steps After Testing
Once manual testing is complete and all major issues are resolved:
1. Document any bugs found and fixes needed
2. Update implementation based on test results  
3. Proceed to Task 4: Watch-iPhone Data Synchronization
4. Plan integration testing between watch and phone apps