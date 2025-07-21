# Fix Firebase Module Import Error in Xcode

Follow these steps in Xcode to resolve the "No such module 'FirebaseAuth'" error:

## Method 1: Add Firebase via Package Dependencies (Recommended)

1. Open `SoccerX.xcodeproj` in Xcode
2. Select the project "SoccerX" in the navigator (top blue icon)
3. Select the "SoccerX" target
4. Go to the "General" tab
5. Scroll down to "Frameworks, Libraries, and Embedded Content"
6. Click the "+" button
7. Select "Add Other..." → "Add Package Dependency..."
8. If Firebase packages appear in the list, select and add:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseFirestoreSwift
   - FirebaseFunctions
   - FirebaseStorage
   - FirebaseMessaging

## Method 2: Reset Package Cache

1. In Xcode, go to File → Packages → Reset Package Caches
2. Wait for packages to re-resolve
3. Clean build folder: Product → Clean Build Folder (⇧⌘K)
4. Build again: Product → Build (⌘B)

## Method 3: Manual Package Resolution

1. Close Xcode
2. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/SoccerX-*
   ```
3. Open Xcode
4. Go to File → Packages → Resolve Package Versions
5. Wait for resolution to complete
6. Build the project

## Verification

After following any of the above methods, verify that:
1. The error "No such module 'FirebaseAuth'" is gone
2. You can see Firebase packages in the Project Navigator under "Package Dependencies"
3. The build succeeds

## Note

The Firebase SDK is already in your Package.resolved file (version 12.0.0), so the issue is just that Xcode needs to properly link these frameworks to your target.