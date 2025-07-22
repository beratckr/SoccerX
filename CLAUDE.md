# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SoccerX is a soccer tracking application with iOS native app and Apple Watch companion app, backed by a serverless Firebase backend. The project has a complete backend implementation and iOS/watchOS apps with core features implemented.

## Project Structure

This is a multi-platform project with three main components:

### iOS Application (`iOS/SoccerX/`)
- **Architecture**: MVVM pattern with SwiftUI
- **Main App Modules**:
  - `Views/` - UI components organized by feature (Dashboard, GameTracking, Groups, History, etc.)
  - `ViewModels/` - Business logic and state management  
  - `Models/` - Data models
  - `Services/` - API clients and external service integrations
  - `Utils/Extensions/` - Helper utilities and Swift extensions
  - `Resources/` - Assets, fonts, and app resources

### Apple Watch App (`iOS/SoccerXWatch/`)
- **Purpose**: Companion app for game tracking during matches
- **Modules**:
  - `Views/Home/` - Watch home screen
  - `Views/Tracking/` - Live game tracking interface
  - `Views/Details/` - Game details and statistics
  - `Services/` - Watch-specific services
  - `Models/` - Watch app data models

### Shared Components (`iOS/Shared/`)
- Cross-platform models, utilities, and extensions used by both iOS and watchOS apps

### Backend (`Backend/functions/`)
- **Technology**: Firebase Functions with TypeScript
- **Database**: Cloud Firestore (NoSQL)
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage
- **Structure**:
  - `src/services/` - Business logic services (user, game, group management)
  - `src/triggers/` - Event-driven functions (notifications, cleanup)
  - `src/types/` - TypeScript type definitions and interfaces
  - `src/utils/` - Utility functions and validation
  - `tests/` - Unit and integration tests

## Development Commands

### Backend (Firebase Functions)
```bash
cd Backend/functions
npm install                    # Install dependencies
npm run build                  # Compile TypeScript
npm run serve                  # Build and start Firebase emulators
npm run shell                  # Build and start Firebase functions shell
npm run deploy                 # Deploy to Firebase
npm run logs                   # View Firebase function logs
npm test                       # Run Jest tests
```

### Firebase Emulator Suite
```bash
cd Backend
firebase emulators:start       # Start all emulators
firebase emulators:start --only functions,firestore  # Start specific emulators
./start-emulators.sh           # Convenience script with proper environment

# Emulator ports:
# - Auth: 9099
# - Functions: 5001
# - Firestore: 8080
# - Storage: 9199
# - UI: 4000
```

### iOS Development
```bash
cd iOS
./build.sh                # Build iOS app for simulator
./resolve-dependencies.sh # Resolve Swift Package Manager dependencies

# Direct Xcode commands:
xcodebuild -workspace SoccerX.xcworkspace -scheme SoccerX clean build
xcodebuild -workspace SoccerX.xcworkspace -scheme SoccerX -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run specific test:
xcodebuild test -workspace SoccerX.xcworkspace -scheme SoccerX -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SoccerXTests/GroupManagerTests
```

## UI/UX Design Reference

The project includes comprehensive UI mockups in `Documentation/UI_mockups/`:
- Dashboard interface
- Game tracking screens  
- Group management
- User profile and settings
- Apple Watch interfaces
- Onboarding flow
- Premium features

These HTML mockups demonstrate the intended user experience and should be referenced when implementing the actual SwiftUI views.

## Configuration Structure

- `Config/Development/` - Development environment configuration
- `Config/Production/` - Production environment configuration  
- `Scripts/` - Build and deployment scripts (to be added)

## Technology Stack

### Chosen Technologies
- **Backend**: Firebase (Functions, Firestore, Auth, Storage, Messaging)
- **iOS Development**: SwiftUI + Combine (no Core Data - using Firebase)
- **Apple Watch**: SwiftUI + WatchConnectivity + HealthKit
- **Language**: TypeScript (backend), Swift 5.9+ (iOS)
- **Real-time**: Firestore real-time listeners
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Authentication**: Sign in with Apple + Firebase Auth
- **Minimum Versions**: iOS 17.0, watchOS 10.0

### Backend Implementation Status ✅
- Firebase Functions with TypeScript configured
- Complete API services for users, games, and groups
- Real-time triggers for notifications
- Firestore security rules and indexes
- Firebase emulator setup for local development

## Key Implementation Notes

- **Backend Complete**: Firebase Functions backend fully implemented with TypeScript
- **iOS/watchOS Implemented**: Both apps created with core features (auth, groups, tracking)
- **Real-time features**: Live game tracking with Firestore listeners
- **Design system**: Dark theme with custom components (badges, cards, animations)
- **Multi-platform**: Shared models and WatchConnectivity for iPhone-Watch sync
- **Offline support**: Queue system for up to 7 days of offline data
- **Architecture**: MVVM with repositories and service layer

## High-Level Architecture

### Data Flow and Synchronization
1. **Game Tracking Flow**: Watch App → iPhone App → Firebase Backend → Group Members
2. **Authentication**: Sign in with Apple → Firebase Auth → User Profile Creation
3. **Real-time Updates**: Firestore Listeners → Combine Publishers → SwiftUI Views
4. **Offline Queue**: Local storage → Priority-based sync → Batch upload when online

### Key Service Interactions
- **GroupManager**: Handles group creation, invites, member management, and statistics
- **LeaderboardManager**: Calculates rankings, fetches game stats, manages timeframes
- **AuthenticationService**: Manages Sign in with Apple and Firebase Auth integration
- **WatchConnectivityService**: Bidirectional communication between iPhone and Watch

### Repository Pattern Implementation
- `BaseRepository<T>`: Generic CRUD operations with Firestore
- Model repositories inherit and add specific queries
- All repositories return Combine publishers for reactive updates
- Error handling through `RepositoryError` enum

## Testing

### Backend Testing
- Run tests: `npm test` in Backend/functions
- Framework: Jest with TypeScript

### iOS Testing
- Test plan: `SoccerXTestPlan.xctestplan`
- Categories: Models, Services, ViewModels, Bug Detection
- Configuration: Code coverage and thread sanitizer enabled
- Environment: Uses Firebase emulator when FIREBASE_EMULATOR env is set

## Common Development Tasks

### Adding a New Feature
1. **Backend**: Add service method in `Backend/functions/src/services/`
2. **iOS Model**: Create/update model in `iOS/SoccerX/Models/`
3. **Repository**: Add repository method in `iOS/SoccerX/Repositories/`
4. **Service/Manager**: Update relevant service in `iOS/SoccerX/Services/`
5. **ViewModel**: Create/update ViewModel in `iOS/SoccerX/ViewModels/`
6. **View**: Implement UI in `iOS/SoccerX/Views/`

### Running with Firebase Emulator
```bash
# Terminal 1: Start emulators
cd Backend && firebase emulators:start

# Terminal 2: Run iOS app with emulator
export FIREBASE_EMULATOR=true
open iOS/SoccerX.xcworkspace
# Run in Xcode with environment variable set
```

### Debugging Watch Connectivity
1. Run both iPhone and Watch simulators
2. Check `WatchConnectivityService` logs in console
3. Use `activationState` and `isReachable` properties
4. Test with Manual Testing Guide in `iOS/SoccerXWatch/MANUAL_TESTING_GUIDE.md`

## Firebase Configuration

### Required Environment Setup
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Use existing project: `firebase use soccerx-app`
4. GoogleService-Info.plist already included in iOS project

### Backend Services Available
- **Authentication**: User signup/login with email/password and social providers
- **User Management**: Profile creation, updates, group membership
- **Group Management**: Create/join groups, invite codes, member management  
- **Game Management**: Create games, live score updates, event tracking
- **Real-time Notifications**: Auto-notifications for goals, cards, game status
- **File Storage**: Profile images, group media, game photos/videos

### Critical Instructions for Claude Code

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (\*.md) or README files
- ALWAYS check task complexity from taskmaster. If tasks complexity is ≥7 ultrathink
- NEVER commit files unless explicitly requested by the User
- **For detailed architecture and specifications, read**: `ai_context.md`
- **For comprehensive technical documentation including**:
  - Complete database schema and data models
  - MVP score calculation algorithm
  - Performance requirements and benchmarks
  - Synchronization architecture details
  - Security rules and authentication flow
  - Deployment strategy and phases