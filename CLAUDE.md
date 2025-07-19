# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SoccerX is a soccer tracking application with iOS native app and Apple Watch companion app, backed by a serverless backend. The project is currently in the initial setup phase with folder structure created but no source code implemented yet.

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
npm run serve                  # Start Firebase emulators
npm run deploy                 # Deploy to Firebase
npm test                       # Run tests
```

### Firebase Emulator Suite
```bash
cd Backend
firebase emulators:start       # Start all emulators
firebase emulators:start --only functions,firestore  # Start specific emulators
```

### iOS Development
⚠️ **To be set up**: Xcode project needs to be initialized
```bash
# After Xcode project is created:
xcodebuild -scheme SoccerX -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild test -scheme SoccerX -destination 'platform=iOS Simulator,name=iPhone 15'
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
- **iOS Development**: SwiftUI + Combine + Core Data
- **Apple Watch**: WatchKit + WatchConnectivity
- **Language**: TypeScript (backend), Swift (iOS)
- **Real-time**: Firestore real-time listeners
- **Push Notifications**: Firebase Cloud Messaging (FCM)

### Backend Implementation Status ✅
- Firebase Functions with TypeScript configured
- Complete API services for users, games, and groups
- Real-time triggers for notifications
- Firestore security rules and indexes
- Firebase emulator setup for local development

## Key Implementation Notes

- **Backend Complete**: Firebase Functions backend fully implemented with TypeScript
- **iOS project pending**: Xcode project needs to be initialized  
- **Real-time features**: Live game tracking with Firestore listeners
- **Design system**: UI mockups show dark theme with modern iOS design patterns
- **Multi-platform**: Shared models between iOS and watchOS through Firebase SDK
- **Offline support**: Firestore provides automatic offline sync

## Next Development Steps

1. **Initialize Xcode project** with iOS and watchOS targets
2. **Install Firebase iOS SDK** and configure authentication
3. **Create Swift data models** that match TypeScript backend types
4. **Implement authentication flow** using Firebase Auth
5. **Set up real-time listeners** for live game updates
6. **Implement core UI screens** based on mockup designs
7. **Add Apple Watch companion app** for game tracking
8. **Set up push notifications** with FCM
9. **Test end-to-end flow** with Firebase emulators

## Firebase Configuration

### Required Environment Setup
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Create Firebase project: `firebase projects:create soccerx-app`
4. Initialize project: `firebase init` (select Functions, Firestore, Storage)

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
- **For commands and development setup, read** : `ai_context.md`