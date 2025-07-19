# Sign in with Apple Setup Guide

This guide walks you through completing the Sign in with Apple implementation for SoccerX.

## ✅ Implementation Status

### Completed
- [x] Firebase Functions backend with Apple ID token verification
- [x] iOS Xcode project with proper entitlements
- [x] SwiftUI authentication UI components
- [x] Authentication service and view models
- [x] Firebase iOS SDK integration

### Remaining Setup Required

## 1. Apple Developer Configuration

### Enable Sign in with Apple Capability
1. Go to [Apple Developer Console](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** and find your App ID (`com.soccerx.app`)
4. Enable **Sign In with Apple** capability
5. Configure the capability settings

### Create App ID (if not exists)
```bash
# Bundle ID: com.soccerx.app
# Description: SoccerX Soccer Tracking App
# Platform: iOS, tvOS, watchOS
# Capabilities: Sign In with Apple
```

## 2. Firebase Console Configuration

### Enable Apple Sign-In Provider
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your SoccerX project
3. Navigate to **Authentication > Sign-in method**
4. Click on **Apple** provider
5. Enable the provider
6. Add your **Services ID** (bundle identifier): `com.soccerx.app`
7. Add **Apple Team ID** from your Apple Developer account
8. Add **Key ID** and **Private Key** (see below)

### Generate Apple Services Key
1. In Apple Developer Console, go to **Keys**
2. Create a new key with **Sign in with Apple** enabled
3. Download the `.p8` key file
4. Note the **Key ID**
5. Upload this key to Firebase Apple provider configuration

## 3. Update Firebase Configuration

### Replace GoogleService-Info.plist
1. In Firebase Console, go to **Project Settings**
2. Download the `GoogleService-Info.plist` for iOS
3. Replace the placeholder file at `iOS/SoccerX/GoogleService-Info.plist`

### Update Bundle ID in Firebase Functions
In `Backend/functions/src/services/userService.ts`, update line 136:
```typescript
// Change from:
audience: "com.soccerx.app", // Your app's bundle ID

// To your actual bundle ID if different
audience: "YOUR_ACTUAL_BUNDLE_ID",
```

## 4. Xcode Project Setup

### Open Project in Xcode
```bash
cd iOS
open SoccerX.xcodeproj
```

### Add Firebase Dependencies
1. In Xcode, go to **File > Add Package Dependencies**
2. Add Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`
3. Select these products:
   - FirebaseAuth
   - FirebaseFirestore  
   - FirebaseFunctions
   - FirebaseStorage
   - FirebaseMessaging

### Configure Signing & Capabilities
1. Select your app target
2. Go to **Signing & Capabilities**
3. Set your **Team** and **Bundle Identifier**
4. Verify **Sign In with Apple** capability is present

### Update Development Team
In `project.pbxproj`, update the `DEVELOPMENT_TEAM` setting:
```
DEVELOPMENT_TEAM = "YOUR_TEAM_ID";
```

## 5. Deploy Firebase Functions

```bash
cd Backend/functions
npm run build
firebase deploy --only functions
```

## 6. Test Implementation

### Prerequisites
- Physical iOS device (Sign in with Apple requires device, not simulator)
- Apple ID signed into the device
- Valid Apple Developer account

### Testing Steps
1. Build and run the app on device
2. Tap "Sign in with Apple" button
3. Complete Apple ID authentication
4. Verify user is created in Firebase Auth console
5. Check Firestore for user document creation

## 7. Environment Configuration

### Development Environment
- Use Firebase emulators for local testing
- Set up separate Firebase project for development

### Production Environment
- Use production Firebase project
- Enable production Apple Sign-In certificates
- Test with App Store Connect builds

## File Structure Created

```
iOS/
├── SoccerX.xcodeproj/           # Xcode project file
├── SoccerX/
│   ├── App/
│   │   └── SoccerXApp.swift     # Main app entry point
│   ├── Views/
│   │   ├── ContentView.swift    # Root view with auth check
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift  # Sign in screen
│   │   └── Dashboard/
│   │       └── DashboardView.swift   # Main app screen
│   ├── Services/
│   │   └── AuthenticationService.swift  # Apple Sign-In logic
│   ├── Resources/
│   │   └── Assets.xcassets/     # App assets
│   ├── GoogleService-Info.plist # Firebase configuration
│   └── SoccerX.entitlements    # Apple Sign-In entitlement
```

## Backend Functions Available

- `authenticateWithApple`: Verifies Apple ID token and creates Firebase custom token
- `createUserProfile`: Auto-creates user profile in Firestore
- `getUserProfile`: Retrieves user profile data
- `updateUserProfile`: Updates user profile information

## Security Notes

- Apple ID tokens are verified server-side using `apple-signin-auth` library
- Firebase custom tokens are generated with proper claims
- User data is stored securely in Firestore with proper security rules
- Bundle ID validation prevents token replay attacks

## Next Steps

1. Complete Apple Developer and Firebase console setup
2. Replace placeholder GoogleService-Info.plist
3. Set development team in Xcode
4. Deploy Firebase functions
5. Test on physical iOS device
6. Implement remaining app features (dashboard, game tracking, etc.)

## Troubleshooting

### Common Issues
- **Invalid bundle ID**: Ensure bundle ID matches across Apple Developer, Firebase, and Xcode
- **Missing entitlements**: Verify Sign in with Apple capability is enabled
- **Token verification fails**: Check Apple Team ID and Key ID in Firebase configuration
- **Simulator issues**: Sign in with Apple requires physical device for testing

### Debug Steps
1. Check Firebase Functions logs for authentication errors
2. Verify Apple ID token format and expiration
3. Test Firebase custom token creation
4. Check Firestore security rules for user document access