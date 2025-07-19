import * as functions from "firebase-functions";
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