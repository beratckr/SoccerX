import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "../index";
import { Group, CreateGroupRequest, JoinGroupRequest, ApiResponse } from "../types";

/**
 * Generate a random invite code
 */
function generateInviteCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

/**
 * Create a new group
 */
export const createGroup = functions.https.onCall(async (data: CreateGroupRequest, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { name, description, isPrivate } = data;
  const uid = context.auth.uid;

  try {
    const groupDoc = db.collection("groups").doc();
    const group: Group = {
      id: groupDoc.id,
      name,
      description,
      createdBy: uid,
      members: [uid], // Creator is automatically a member
      createdAt: new Date() as any,
      updatedAt: new Date() as any,
      isPrivate,
      inviteCode: isPrivate ? generateInviteCode() : undefined,
    };

    await groupDoc.set(group);

    // Add group to user's groups array
    await db.collection("users").doc(uid).update({
      groups: admin.firestore.FieldValue.arrayUnion(groupDoc.id),
    });

    const response: ApiResponse<Group> = {
      success: true,
      data: group,
      message: "Group created successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error creating group:", error);
    
    const response: ApiResponse<Group> = {
      success: false,
      error: "Failed to create group",
    };

    return response;
  }
});

/**
 * Join a group using invite code
 */
export const joinGroup = functions.https.onCall(async (data: JoinGroupRequest, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { inviteCode } = data;
  const uid = context.auth.uid;

  try {
    // Find group by invite code
    const groupSnapshot = await db.collection("groups")
      .where("inviteCode", "==", inviteCode)
      .limit(1)
      .get();

    if (groupSnapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Invalid invite code"
      );
    }

    const groupDoc = groupSnapshot.docs[0];
    const groupData = groupDoc.data() as Group;

    // Check if user is already a member
    if (groupData.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "already-exists",
        "User is already a member of this group"
      );
    }

    // Add user to group members
    await groupDoc.ref.update({
      members: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: new Date(),
    });

    // Add group to user's groups array
    await db.collection("users").doc(uid).update({
      groups: admin.firestore.FieldValue.arrayUnion(groupDoc.id),
    });

    const response: ApiResponse<Group> = {
      success: true,
      data: { ...groupData, members: [...groupData.members, uid] } as Group,
      message: "Successfully joined the group",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error joining group:", error);
    
    const response: ApiResponse<Group> = {
      success: false,
      error: "Failed to join group",
    };

    return response;
  }
});

/**
 * Get user's groups
 */
export const getUserGroups = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const uid = context.auth.uid;

  try {
    // Get groups where user is a member
    const groupsSnapshot = await db.collection("groups")
      .where("members", "array-contains", uid)
      .orderBy("updatedAt", "desc")
      .get();

    const groups = groupsSnapshot.docs.map(doc => doc.data() as Group);

    const response: ApiResponse<Group[]> = {
      success: true,
      data: groups,
    };

    return response;
  } catch (error) {
    functions.logger.error("Error getting user groups:", error);
    
    const response: ApiResponse<Group[]> = {
      success: false,
      error: "Failed to get groups",
    };

    return response;
  }
});

/**
 * Leave a group
 */
export const leaveGroup = functions.https.onCall(async (data: { groupId: string }, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { groupId } = data;
  const uid = context.auth.uid;

  try {
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Group not found");
    }

    const groupData = groupDoc.data() as Group;

    // Check if user is a member
    if (!groupData.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User is not a member of this group"
      );
    }

    // If user is the creator and there are other members, transfer ownership
    if (groupData.createdBy === uid && groupData.members.length > 1) {
      const newOwner = groupData.members.find(member => member !== uid);
      await groupDoc.ref.update({
        createdBy: newOwner,
        members: admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: new Date(),
      });
    } else if (groupData.members.length === 1) {
      // If user is the only member, delete the group
      await groupDoc.ref.delete();
    } else {
      // Remove user from group members
      await groupDoc.ref.update({
        members: admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: new Date(),
      });
    }

    // Remove group from user's groups array
    await db.collection("users").doc(uid).update({
      groups: admin.firestore.FieldValue.arrayRemove(groupId),
    });

    const response: ApiResponse<null> = {
      success: true,
      message: "Successfully left the group",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error leaving group:", error);
    
    const response: ApiResponse<null> = {
      success: false,
      error: "Failed to leave group",
    };

    return response;
  }
});

/**
 * Update group details
 */
export const updateGroup = functions.https.onCall(async (data: {
  groupId: string;
  name?: string;
  description?: string;
}, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated", 
      "User must be authenticated"
    );
  }

  const { groupId, name, description } = data;
  const uid = context.auth.uid;

  try {
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Group not found");
    }

    const groupData = groupDoc.data() as Group;

    // Only the creator can update group details
    if (groupData.createdBy !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only the group creator can update group details"
      );
    }

    const updateData: Partial<Group> = {
      updatedAt: new Date() as any,
    };

    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;

    await groupDoc.ref.update(updateData);

    const response: ApiResponse<null> = {
      success: true,
      message: "Group updated successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error updating group:", error);
    
    const response: ApiResponse<null> = {
      success: false,
      error: "Failed to update group",
    };

    return response;
  }
});