import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "../index";

/**
 * Clean up user data when account is deleted
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  
  try {
    // Remove user from all groups they're a member of
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const userGroups = userData?.groups || [];

      // Remove user from each group's members array
      const groupUpdatePromises = userGroups.map(async (groupId: string) => {
        const groupRef = db.collection("groups").doc(groupId);
        const groupDoc = await groupRef.get();
        
        if (groupDoc.exists) {
          const groupData = groupDoc.data();
          
          // If user was the creator and there are other members, transfer ownership
          if (groupData?.createdBy === uid && groupData.members.length > 1) {
            const newOwner = groupData.members.find((member: string) => member !== uid);
            await groupRef.update({
              createdBy: newOwner,
              members: admin.firestore.FieldValue.arrayRemove(uid),
              updatedAt: new Date(),
            });
          } else if (groupData?.members.length === 1) {
            // If user was the only member, delete the group
            await groupRef.delete();
          } else {
            // Just remove user from group
            await groupRef.update({
              members: admin.firestore.FieldValue.arrayRemove(uid),
              updatedAt: new Date(),
            });
          }
        }
      });

      await Promise.all(groupUpdatePromises);
    }

    // Delete user document
    await db.collection("users").doc(uid).delete();

    functions.logger.info(`User cleanup completed for ${uid}`);
  } catch (error) {
    functions.logger.error(`Error cleaning up user ${uid}:`, error);
  }
});