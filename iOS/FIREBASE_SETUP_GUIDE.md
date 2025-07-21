# Firebase Setup Guide for SoccerX

## Issue
You're getting "No such module 'FirebaseMessaging'" error because the Firebase packages aren't properly linked to your target.

## Solution

### Step 1: Open the Workspace (Not Project)
**IMPORTANT**: You must open `SoccerX.xcworkspace`, NOT `SoccerX.xcodeproj`

```bash
# From terminal:
open SoccerX.xcworkspace

# Or in Xcode:
# File → Open → Select SoccerX.xcworkspace
```

### Step 2: Clean Build Folder
In Xcode:
1. Product → Clean Build Folder (⇧⌘K)

### Step 3: Verify Package Dependencies
1. In Xcode, select the project in the navigator
2. Select the "SoccerX" project (not target) at the top
3. Click on "Package Dependencies" tab
4. You should see "firebase-ios-sdk" listed
5. If not, click the "+" button and add: `https://github.com/firebase/firebase-ios-sdk`

### Step 4: Link Firebase to Target
1. Select the "SoccerX" target
2. Go to "General" tab
3. Scroll to "Frameworks, Libraries, and Embedded Content"
4. If Firebase packages aren't there, click "+" and add:
   - FirebaseAuth
   - FirebaseFirestore  
   - FirebaseFirestoreSwift
   - FirebaseFunctions
   - FirebaseStorage
   - FirebaseMessaging

### Step 5: Build
1. Product → Build (⌘B)

## Alternative Command Line Build
```bash
# Make sure you're in the iOS directory
cd /Users/furkan/SoccerX/iOS

# Build using workspace
xcodebuild -workspace SoccerX.xcworkspace -scheme SoccerX -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## If Still Having Issues
1. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/SoccerX-*
   ```

2. Reset package caches:
   - In Xcode: File → Packages → Reset Package Caches

3. Re-resolve packages:
   - In Xcode: File → Packages → Resolve Package Versions

## Important Notes
- Always use the `.xcworkspace` file when you have Swift Package Manager dependencies
- The `.xcodeproj` file alone doesn't include the package resolution
- Firebase setup requires all related modules to be explicitly linked to your target