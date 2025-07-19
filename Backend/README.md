# SoccerX Backend

Firebase Functions backend for the SoccerX soccer tracking application.

## Overview

This backend provides serverless functions, real-time database, authentication, and file storage for the SoccerX iOS and Apple Watch apps. Built with TypeScript and Firebase.

## Technology Stack

- **Runtime**: Node.js 18
- **Language**: TypeScript
- **Platform**: Firebase Functions
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth  
- **Storage**: Firebase Storage
- **Notifications**: Firebase Cloud Messaging

## Project Structure

```
Backend/
├── functions/
│   ├── src/
│   │   ├── services/          # Business logic services
│   │   │   ├── userService.ts # User management 
│   │   │   ├── gameService.ts # Game tracking
│   │   │   └── groupService.ts # Group management
│   │   ├── triggers/          # Database triggers
│   │   │   ├── userTriggers.ts # User lifecycle events
│   │   │   └── gameTriggers.ts # Game event notifications
│   │   ├── types/             # TypeScript type definitions
│   │   │   └── index.ts       # Shared interfaces
│   │   ├── utils/             # Utility functions
│   │   │   └── validation.ts  # Input validation
│   │   └── index.ts           # Main export file
│   ├── package.json           # Dependencies and scripts
│   └── tsconfig.json          # TypeScript configuration
├── firebase.json              # Firebase project configuration
├── firestore.rules           # Database security rules
├── firestore.indexes.json    # Database indexes
└── storage.rules             # File storage security rules
```

## Available Services

### User Management
- **User profile creation** (automatic on signup)
- **Profile updates** (display name, profile image)
- **Account deletion cleanup**

### Group Management  
- **Create groups** with invite codes
- **Join groups** using invite codes
- **Leave groups** with ownership transfer
- **Update group details** (creator only)

### Game Management
- **Create games** within groups
- **Live score updates** during matches
- **Add game events** (goals, cards, substitutions)
- **Real-time game state** synchronization

### Real-time Features
- **Live notifications** for game events
- **Score updates** pushed to all group members
- **Game status changes** (started, finished, cancelled)

## API Functions

### User Functions
- `createUserProfile` - Auto-trigger on user creation
- `getUserProfile` - Get current user's profile
- `updateUserProfile` - Update profile information

### Group Functions  
- `createGroup` - Create new group with optional privacy
- `joinGroup` - Join group using invite code
- `getUserGroups` - Get user's groups
- `leaveGroup` - Leave group (with ownership transfer)
- `updateGroup` - Update group details (creator only)

### Game Functions
- `createGame` - Create new game in group
- `updateGame` - Update game score/status
- `addGameEvent` - Add game events (goals, cards)
- `getGroupGames` - Get games for a group

## Development Setup

### Prerequisites
- Node.js 18+
- Firebase CLI
- Firebase project

### Installation

1. **Install dependencies**:
```bash
cd functions
npm install
```

2. **Set up Firebase project**:
```bash
firebase login
firebase init
```

3. **Start emulators**:
```bash
npm run serve
```

### Development Commands

```bash
# Build TypeScript
npm run build

# Start Firebase emulators
npm run serve

# Deploy to Firebase
npm run deploy

# View function logs
npm run logs

# Run tests
npm test
```

## Database Schema

### Users Collection
```typescript
{
  uid: string;
  email: string;
  displayName: string;
  profileImageUrl?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isPremium: boolean;
  groups: string[]; // Group IDs
}
```

### Groups Collection
```typescript
{
  id: string;
  name: string;
  description?: string;
  createdBy: string; // User UID
  members: string[]; // User UIDs
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isPrivate: boolean;
  inviteCode?: string;
}
```

### Games Collection
```typescript
{
  id: string;
  groupId: string;
  homeTeam: string;
  awayTeam: string;
  homeScore: number;
  awayScore: number;
  status: "scheduled" | "live" | "paused" | "finished" | "cancelled";
  startTime: Timestamp;
  endTime?: Timestamp;
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  events: GameEvent[];
}
```

## Security Rules

### Firestore Rules
- Users can read/write their own data
- Group members can read group data
- Group creators can modify group settings
- Game access restricted to group members

### Storage Rules
- Profile images: user-only write, public read
- Group/game media: group members write, public read
- File size limits: 5MB (profiles), 10MB (groups), 20MB (games)

## Real-time Notifications

The backend automatically sends push notifications for:
- ⚽ **Goals** - Score updates with team names
- 🟨🟥 **Cards** - Yellow/red card events
- 🟢 **Game start** - When games go live
- 🏁 **Game end** - Final scores
- ❌ **Cancellations** - Game cancellations

## Environment Variables

Required for local development and deployment:

```bash
# No environment variables needed for basic functionality
# Firebase project configuration handled through Firebase CLI
```

## Testing

```bash
# Run all tests
npm test

# Run with emulators
firebase emulators:exec "npm test"
```

## Deployment

```bash
# Deploy all functions
npm run deploy

# Deploy specific function
firebase deploy --only functions:createGame
```

## Error Handling

All functions return standardized responses:

```typescript
{
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}
```

## Rate Limiting

Basic rate limiting implemented:
- 100 requests per minute per user (default)
- Configurable per function
- Returns `resource-exhausted` error when exceeded

## Monitoring

- Function execution logs available via Firebase Console
- Error tracking and performance monitoring enabled
- Real-time function metrics and alerts

## Next Steps

1. Install dependencies: `npm install`
2. Start emulators: `npm run serve`
3. Create Firebase project and deploy
4. Connect iOS app with Firebase SDK