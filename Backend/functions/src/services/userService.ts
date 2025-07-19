import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import appleSignin from "apple-signin-auth";
import { db } from "../index";
import { User, ApiResponse } from "../types";

/**
 * Create or update user profile
 */
export const createUserProfile = functions.auth.user().onCreate(async (user) => {
  const userDoc: Partial<User> = {
    uid: user.uid,
    email: user.email || "",
    displayName: user.displayName || "",
    profileImageUrl: user.photoURL || undefined,
    createdAt: new Date() as any,
    updatedAt: new Date() as any,
    isPremium: false,
    groups: [],
  };

  try {
    await db.collection("users").doc(user.uid).set(userDoc);
    functions.logger.info(`User profile created for ${user.uid}`);
  } catch (error) {
    functions.logger.error("Error creating user profile:", error);
  }
});

/**
 * Get user profile
 */
export const getUserProfile = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const uid = context.auth.uid;

  try {
    const userDoc = await db.collection("users").doc(uid).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", 
        "User profile not found"
      );
    }

    const response: ApiResponse<User> = {
      success: true,
      data: userDoc.data() as User,
    };

    return response;
  } catch (error) {
    functions.logger.error("Error getting user profile:", error);
    
    const response: ApiResponse<User> = {
      success: false,
      error: "Failed to get user profile",
    };

    return response;
  }
});

/**
 * Update user profile
 */
export const updateUserProfile = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const uid = context.auth.uid;
  const { displayName, profileImageUrl } = data;

  try {
    const updateData: Partial<User> = {
      updatedAt: new Date() as any,
    };

    if (displayName !== undefined) {
      updateData.displayName = displayName;
    }

    if (profileImageUrl !== undefined) {
      updateData.profileImageUrl = profileImageUrl;
    }

    await db.collection("users").doc(uid).update(updateData);

    const response: ApiResponse<null> = {
      success: true,
      message: "Profile updated successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error updating user profile:", error);
    
    const response: ApiResponse<null> = {
      success: false,
      error: "Failed to update profile",
    };

    return response;
  }
});

/**
 * Authenticate user with Apple Sign-In
 */
export const authenticateWithApple = functions.https.onCall(async (data, context) => {
  const { identityToken, authorizationCode, user } = data;

  if (!identityToken || !authorizationCode) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Identity token and authorization code are required"
    );
  }

  try {
    // Verify the Apple identity token
    const appleIdTokenClaims = await appleSignin.verifyIdToken(identityToken, {
      audience: "com.soccerx.app", // Your app's bundle ID
      ignoreExpiration: false,
    });

    // Create Firebase custom token
    const firebaseToken = await admin.auth().createCustomToken(appleIdTokenClaims.sub, {
      provider: "apple.com",
      email: appleIdTokenClaims.email,
      email_verified: appleIdTokenClaims.email_verified === "true",
    });

    // Check if user document exists, create if not
    const userRef = db.collection("users").doc(appleIdTokenClaims.sub);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      const newUser: Partial<User> = {
        uid: appleIdTokenClaims.sub,
        email: appleIdTokenClaims.email || "",
        displayName: user?.firstName && user?.lastName 
          ? `${user.firstName} ${user.lastName}` 
          : appleIdTokenClaims.email?.split("@")[0] || "",
        profileImageUrl: undefined,
        createdAt: new Date() as any,
        updatedAt: new Date() as any,
        isPremium: false,
        groups: [],
      };

      await userRef.set(newUser);
      functions.logger.info(`Apple user profile created for ${appleIdTokenClaims.sub}`);
    }

    const response: ApiResponse<{ firebaseToken: string }> = {
      success: true,
      data: { firebaseToken },
      message: "Apple authentication successful",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error authenticating with Apple:", error);
    
    const response: ApiResponse<null> = {
      success: false,
      error: "Apple authentication failed",
    };

    return response;
  }
});