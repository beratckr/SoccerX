# SoccerX App Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Technology Stack](#technology-stack)
3. [System Architecture](#system-architecture)
4. [App Structure](#app-structure)
5. [Data Flow](#data-flow)
6. [Key Features Implementation](#key-features-implementation)
7. [Database Schema](#database-schema)
8. [API Endpoints](#api-endpoints)
9. [Security & Privacy](#security-privacy)
10. [Performance Optimization](#performance-optimization)
11. [Testing Strategy](#testing-strategy)
12. [Deployment Guide](#deployment-guide)

## 1. Overview {#overview}

SoccerX is a comprehensive soccer performance tracking application consisting of:
- **iOS App**: Main application for viewing stats, managing groups, and social features
- **watchOS App**: Real-time game tracking during play
- **Firebase Backend**: Cloud infrastructure for data storage and real-time features
- **Analytics Engine**: MVP score calculation and performance metrics

### Key Metrics
- Target Users: 50,000+ weekend soccer players
- Expected Load: 10,000+ concurrent users during weekends
- Data Points: ~1,000 per game per user
- Storage: ~5MB per game (including GPS data)

## 2. Technology Stack {#technology-stack}

### Frontend
```yaml
iOS App:
  - Language: Swift 5.9+
  - UI Framework: SwiftUI
  - Minimum iOS: 17.0
  - Architecture: MVVM with Combine
  - Dependencies:
    - Charts (native SwiftUI)
    - StoreKit 2 (subscriptions)
    - WatchConnectivity

watchOS App:
  - Language: Swift 5.9+
  - UI Framework: SwiftUI
  - Minimum watchOS: 10.0
  - Key Frameworks:
    - HealthKit
    - CoreLocation
    - CoreMotion
```

### Backend
```yaml
Firebase Services:
  - Authentication: Sign in with Apple
  - Database: Firestore (NoSQL)
  - Storage: Cloud Storage (GPS data)
  - Functions: Node.js 18
  - Hosting: Static content
  - Analytics: Firebase Analytics
  - Messaging: FCM (push notifications)
```

### Third-Party Services
```yaml
Payment Processing:
  - Primary: StoreKit 2 (Apple IAP)
  - Fallback: RevenueCat (optional)

Analytics:
  - Firebase Analytics
  - Custom event tracking
  - Crashlytics
```

## 3. System Architecture {#system-architecture}

### High-Level Architecture
```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Apple Watch    │◀───▶│  iPhone App  │◀───▶│ Firebase Cloud  │
│   (Tracking)    │     │  (Display)   │     │   (Backend)     │
└─────────────────┘     └──────────────┘     └─────────────────┘
        │                       │                      │
        ▼                       ▼                      ▼
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   HealthKit     │     │  StoreKit 2  │     │   Firestore     │
│  CoreLocation   │     │   (IAP)      │     │   Functions     │
└─────────────────┘     └──────────────┘     └─────────────────┘
```

### Component Architecture
```
SoccerX/
├── iOS/
│   ├── Core/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Repositories/
│   │   └── Utilities/
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── Dashboard/
│   │   ├── GameTracking/
│   │   ├── History/
│   │   ├── Groups/
│   │   ├── Profile/
│   │   └── Premium/
│   └── Shared/
│       ├── UI/
│       ├── Extensions/
│       └── Resources/
├── watchOS/
│   ├── Tracking/
│   ├── UI/
│   └── Services/
└── Backend/
    ├── Functions/
    ├── Security/
    └── Scripts/
```

## 4. App Structure {#app-structure}

### iOS App Navigation Flow
```
Launch
  ├── Onboarding (First Launch)
  │   ├── Welcome
  │   ├── Sign in with Apple
  │   ├── Permissions (Health, Location, Notifications)
  │   └── Complete → Dashboard
  └── Dashboard (Returning User)
      ├── Start Game → Watch Connection
      ├── History
      │   ├── Calendar View
      │   └── Game Detail
      ├── Groups
      │   ├── My Groups
      │   ├── Group Detail
      │   └── Create/Join
      └── Profile
          ├── Stats
          ├── Achievements
          ├── Settings
          └── Premium
```

### watchOS App Flow
```
Home
  ├── Start Game
  │   ├── Pre-Game Countdown
  │   ├── Active Tracking
  │   │   ├── Main Stats
  │   │   ├── Heart Rate Detail
  │   │   ├── Speed Detail
  │   │   ├── Splits
  │   │   └── Calories
  │   ├── Paused State
  │   └── Game Complete
  ├── History (Quick View)
  └── Settings
```

## 5. Data Flow {#data-flow}

### Real-time Game Tracking
```swift
// 1. Watch collects data
Watch: HKWorkoutSession → Location + Heart Rate → Local Processing

// 2. Data aggregation (every 5 seconds)
struct GameDataPoint {
    timestamp: Date
    location: CLLocation
    heartRate: Int
    speed: Double
    distance: Double
}

// 3. Watch → iPhone sync
WatchConnectivity: 
  - Real-time during game (if connected)
  - Batch sync post-game
  - Queue up to 7 days offline

// 4. iPhone → Cloud sync
iPhone: Process → Compress → Upload to Firebase

// 5. Cloud processing
Firebase Functions: 
  - Calculate MVP score
  - Update leaderboards
  - Send notifications
```

### Data Synchronization Strategy
```yaml
Priority Levels:
  1. Critical: Game summary, final stats
  2. High: GPS route, heart rate data
  3. Medium: Detailed metrics, splits
  4. Low: Raw sensor data

Sync Rules:
  - WiFi: All data immediately
  - Cellular: Critical + High only
  - Offline: Queue all, sync when connected
  - Storage limit: 7 days or 50MB
```

## 6. Key Features Implementation {#key-features-implementation}

### MVP Score Calculation
```javascript
// Firebase Function
function calculateMVPScore(gameData) {
  const weights = {
    distance: 0.3,
    avgSpeed: 0.2,
    maxSpeed: 0.15,
    heartRateEfficiency: 0.2,
    consistency: 0.15
  };
  
  // Normalize each metric (0-100)
  const normalized = {
    distance: normalizeDistance(gameData.distance),
    avgSpeed: normalizeSpeed(gameData.avgSpeed),
    maxSpeed: normalizeMaxSpeed(gameData.maxSpeed),
    heartRateEfficiency: calculateHREfficiency(gameData),
    consistency: calculateConsistency(gameData.splits)
  };
  
  // Calculate weighted score
  return Object.keys(weights).reduce((score, metric) => {
    return score + (normalized[metric] * weights[metric]);
  }, 0);
}
```

### Group Leaderboard System
```swift
// Real-time leaderboard updates
class LeaderboardManager {
    func updateLeaderboard(for group: Group, game: Game) {
        // 1. Update user's weekly total
        let weeklyStats = calculateWeeklyStats(for: game.userId)
        
        // 2. Recalculate rankings
        let rankings = group.members
            .map { member in (member, getWeeklyStats(member.id)) }
            .sorted { $0.1.totalDistance > $1.1.totalDistance }
        
        // 3. Check for position changes
        notifyRankingChanges(rankings, group: group)
        
        // 4. Update Firebase
        updateFirestore(rankings, groupId: group.id)
    }
}
```

### Premium Features Gate
```swift
// Feature availability check
enum Feature {
    case heatmap
    case unlimitedHistory
    case advancedAnalytics
    case unlimitedGroups
    
    var isPremium: Bool {
        switch self {
        case .heatmap, .unlimitedHistory, .advancedAnalytics:
            return true
        case .unlimitedGroups:
            return false // First group free
        }
    }
}

// Usage in views
@ViewBuilder
func featureGatedView<Content: View>(
    feature: Feature,
    @ViewBuilder content: () -> Content
) -> some View {
    if subscriptionManager.hasAccess(to: feature) {
        content()
    } else {
        PremiumUpsellView(feature: feature)
    }
}
```

## 7. Database Schema {#database-schema}

### Firestore Collections
```javascript
// Users Collection
users/{userId} {
  email: string
  displayName: string
  avatarUrl?: string
  isPremium: boolean
  subscribedUntil?: timestamp
  createdAt: timestamp
  settings: {
    units: 'metric' | 'imperial'
    notifications: NotificationSettings
    privacy: PrivacySettings
  }
  stats: {
    totalGames: number
    totalDistance: number
    totalDuration: number
    lifetimeCalories: number
  }
}

// Games Collection
games/{gameId} {
  userId: string
  startTime: timestamp
  endTime: timestamp
  duration: number // seconds
  distance: number // meters
  maxSpeed: number // km/h
  avgSpeed: number // km/h
  avgHeartRate: number
  maxHeartRate: number
  calories: number
  mvpScore: number
  gpsRoute?: string // Cloud Storage reference
  groupIds: string[]
  weather?: WeatherData
  createdAt: timestamp
}

// Groups Collection
groups/{groupId} {
  name: string
  description: string
  creatorId: string
  memberIds: string[]
  isPublic: boolean
  location?: GeoPoint
  inviteCode: string
  weeklyChallenge: {
    type: 'distance' | 'speed' | 'consistency'
    startDate: timestamp
  }
  settings: {
    autoWeeklyChallenges: boolean
    memberLimit: number
  }
  createdAt: timestamp
}

// Leaderboards Collection (Weekly)
leaderboards/{groupId}_{weekId} {
  groupId: string
  weekId: string // YYYY-WW
  rankings: [{
    userId: string
    totalDistance: number
    gameCount: number
    avgMvpScore: number
    badges: string[]
    position: number
    previousPosition?: number
  }]
  updatedAt: timestamp
}

// Achievements Collection
achievements/{userId} {
  unlockedAchievements: [{
    id: string
    unlockedAt: timestamp
    gameId: string
  }]
  stats: {
    firstGame: timestamp
    longestDistance: number
    fastestSpeed: number
    longestStreak: number
  }
}
```

### Data Indexing Strategy
```yaml
Composite Indexes:
  - games: [userId, startTime DESC]
  - games: [userId, mvpScore DESC]
  - groups: [memberIds, isPublic]
  - leaderboards: [groupId, weekId]

Security Rules:
  - Users can only read/write their own data
  - Group data readable by members only
  - Leaderboards public within group
  - Premium features check subscription status
```

## 8. API Endpoints {#api-endpoints}

### Firebase Functions
```typescript
// Game Management
exports.processGameCompletion = functions.firestore
  .document('games/{gameId}')
  .onCreate(async (snap, context) => {
    const game = snap.data();
    
    // 1. Calculate MVP score
    const mvpScore = calculateMVPScore(game);
    
    // 2. Update user stats
    await updateUserStats(game.userId, game);
    
    // 3. Update group leaderboards
    for (const groupId of game.groupIds) {
      await updateGroupLeaderboard(groupId, game);
    }
    
    // 4. Check achievements
    const newAchievements = await checkAchievements(game);
    
    // 5. Send notifications
    if (newAchievements.length > 0) {
      await sendAchievementNotifications(game.userId, newAchievements);
    }
  });

// Subscription Management
exports.handleSubscriptionUpdate = functions.https
  .onCall(async (data, context) => {
    const { receipt } = data;
    const userId = context.auth.uid;
    
    // Validate with Apple
    const validation = await validateReceipt(receipt);
    
    if (validation.isValid) {
      await updateUserSubscription(userId, validation.expiresAt);
      return { success: true, expiresAt: validation.expiresAt };
    }
    
    throw new functions.https.HttpsError(
      'invalid-argument', 
      'Invalid receipt'
    );
  });

// Weekly Challenges
exports.weeklyLeaderboardReset = functions.pubsub
  .schedule('every monday 00:00')
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    // 1. Archive previous week
    await archiveWeeklyLeaderboards();
    
    // 2. Distribute badges
    await distributeWeeklyBadges();
    
    // 3. Reset leaderboards
    await resetLeaderboards();
    
    // 4. Generate new challenges
    await generateWeeklyChallenges();
    
    // 5. Send notifications
    await sendWeeklyRecapNotifications();
  });
```

## 9. Security & Privacy {#security-privacy}

### Data Security
```yaml
Encryption:
  - At Rest: Firebase automatic encryption
  - In Transit: TLS 1.3
  - Local Storage: iOS Keychain for sensitive data
  - GPS Data: Compressed and encrypted before upload

Authentication:
  - Primary: Sign in with Apple
  - Token Management: Firebase Auth
  - Session Duration: 30 days
  - Biometric Lock: Optional for app access

Privacy:
  - Location: Only during workouts
  - HealthKit: Read/Write workout data only
  - Data Retention: 1 year active, 30 days after deletion
  - GDPR Compliance: Export and delete options
```

### Security Rules Example
```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Games are private to user
    match /games/{gameId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
    
    // Groups readable by members
    match /groups/{groupId} {
      allow read: if request.auth.uid in resource.data.memberIds;
      allow update: if request.auth.uid in resource.data.memberIds
        && request.resource.data.memberIds.hasAll(resource.data.memberIds);
      allow create: if request.auth.uid == request.resource.data.creatorId;
    }
  }
}
```

## 10. Performance Optimization {#performance-optimization}

### Watch App Optimization
```swift
// Battery optimization during tracking
class WorkoutManager {
    func configureBatteryOptimization() {
        // Adaptive GPS accuracy
        if currentSpeed < 5 {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
        
        // Reduce sensor frequency during low activity
        if !isActivelyMoving {
            motionManager.deviceMotionUpdateInterval = 1.0
        } else {
            motionManager.deviceMotionUpdateInterval = 0.1
        }
    }
}
```

### Data Compression
```swift
// GPS route compression
extension [CLLocation] {
    func compressRoute() -> Data {
        // Douglas-Peucker algorithm for path simplification
        let simplified = douglasPeucker(points: self, epsilon: 5.0)
        
        // Delta encoding for coordinates
        let deltas = deltaEncode(simplified)
        
        // Compress with zlib
        return deltas.compressed(using: .zlib) ?? Data()
    }
}
```

### Caching Strategy
```yaml
Cache Layers:
  1. Memory Cache:
     - Current game data
     - Active group info
     - Recent activities
     
  2. Disk Cache:
     - Last 5 games
     - Group leaderboards
     - User profile
     
  3. CloudKit Sync:
     - Backup game data
     - Settings sync
     - Achievement progress
```

## 11. Testing Strategy {#testing-strategy}

### Unit Testing
```swift
// Example: MVP Score Calculation Test
class MVPScoreTests: XCTestCase {
    func testMVPScoreCalculation() {
        let gameData = GameData(
            distance: 5200, // meters
            avgSpeed: 8.5, // km/h
            maxSpeed: 24.5, // km/h
            avgHeartRate: 152,
            duration: 3600 // seconds
        )
        
        let score = MVPCalculator.calculate(from: gameData)
        
        XCTAssertEqual(score, 85, accuracy: 2)
        XCTAssert(score >= 0 && score <= 100)
    }
}
```

### Integration Testing
```yaml
Test Scenarios:
  - Watch → iPhone data sync
  - Offline game tracking and sync
  - Group creation and joining
  - Subscription purchase flow
  - Push notification delivery
  - Weekly leaderboard updates
```

### Performance Testing
```yaml
Benchmarks:
  - App Launch: < 2 seconds
  - Game Start: < 3 seconds (including GPS lock)
  - Sync Time: < 5 seconds for average game
  - Battery Usage: < 10% per 2-hour session
  - Memory Usage: < 100MB active tracking
```

## 12. Deployment Guide {#deployment-guide}

### Pre-Launch Checklist
```yaml
iOS App:
  ✓ TestFlight beta with 50 users
  ✓ App Store assets prepared
  ✓ Privacy policy and terms
  ✓ App Store review guidelines compliance
  ✓ Crash-free rate > 99.5%

watchOS App:
  ✓ Battery usage optimization verified
  ✓ Complication support
  ✓ Background workout handling
  ✓ Offline capability tested

Backend:
  ✓ Firebase project configured
  ✓ Security rules tested
  ✓ Cloud Functions deployed
  ✓ Backup strategy implemented
  ✓ Monitoring alerts configured
```

### Launch Strategy
```yaml
Phase 1 - Soft Launch (Week 1-2):
  - 50 local users (your soccer group)
  - Monitor performance metrics
  - Gather feedback
  - Fix critical issues

Phase 2 - Regional Launch (Week 3-4):
  - Open to Austin area
  - Local marketing campaign
  - Implement feedback
  - Scale testing

Phase 3 - Full Launch (Week 5+):
  - App Store featuring pitch
  - Social media campaign
  - Referral program activation
  - Premium features promotion
```

### Monitoring & Analytics
```yaml
Key Metrics:
  - Daily Active Users (DAU)
  - Weekly Retention Rate
  - Average Session Duration
  - Crash Rate
  - Subscription Conversion Rate
  - Server Response Times
  - User Feedback Scores

Monitoring Tools:
  - Firebase Analytics
  - Crashlytics
  - Cloud Monitoring
  - Custom dashboards
```

### Post-Launch Roadmap
```yaml
Month 1-2:
  - Bug fixes and stability
  - Performance optimization
  - User feedback implementation

Month 3-4:
  - Android app development
  - Web dashboard
  - Coach features
  - Team management

Month 5-6:
  - AI-powered insights
  - Video integration
  - Training programs
  - Social features expansion
```

## Conclusion

SoccerX is architected for scalability, performance, and user engagement. The modular design allows for easy feature additions while maintaining code quality. The focus on real-time tracking, social features, and data insights creates a compelling product for weekend soccer players.

For questions or contributions, please refer to the project's GitHub repository.