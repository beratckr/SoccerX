import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "../index";
import { Game, GameStatus, GameEventType } from "../types";

/**
 * Send notifications when game events occur
 */
export const onGameUpdated = functions.firestore
  .document("games/{gameId}")
  .onUpdate(async (change, context) => {
    const gameId = context.params.gameId;
    const beforeData = change.before.data() as Game;
    const afterData = change.after.data() as Game;

    try {
      // Get group members to send notifications to
      const groupDoc = await db.collection("groups").doc(afterData.groupId).get();
      if (!groupDoc.exists) return;

      const groupData = groupDoc.data();
      const members = groupData?.members || [];

      // Check if new events were added
      if (afterData.events.length > beforeData.events.length) {
        const newEvents = afterData.events.slice(beforeData.events.length);
        
        for (const event of newEvents) {
          let notificationTitle = "";
          let notificationBody = "";

          switch (event.type) {
            case GameEventType.GOAL:
              notificationTitle = "⚽ GOAL!";
              notificationBody = `${afterData.homeTeam} ${afterData.homeScore} - ${afterData.awayScore} ${afterData.awayTeam}`;
              break;
            case GameEventType.YELLOW_CARD:
              notificationTitle = "🟨 Yellow Card";
              notificationBody = `${event.teamSide === "home" ? afterData.homeTeam : afterData.awayTeam} - ${event.minute}'`;
              break;
            case GameEventType.RED_CARD:
              notificationTitle = "🟥 Red Card";
              notificationBody = `${event.teamSide === "home" ? afterData.homeTeam : afterData.awayTeam} - ${event.minute}'`;
              break;
            case GameEventType.HALFTIME:
              notificationTitle = "⏱️ Half Time";
              notificationBody = `${afterData.homeTeam} ${afterData.homeScore} - ${afterData.awayScore} ${afterData.awayTeam}`;
              break;
            case GameEventType.FULLTIME:
              notificationTitle = "🏁 Full Time";
              notificationBody = `Final: ${afterData.homeTeam} ${afterData.homeScore} - ${afterData.awayScore} ${afterData.awayTeam}`;
              break;
          }

          if (notificationTitle && notificationBody) {
            await sendNotificationToGroupMembers(
              members,
              notificationTitle,
              notificationBody,
              {
                gameId,
                eventType: event.type,
                groupId: afterData.groupId,
              }
            );
          }
        }
      }

      // Check if game status changed
      if (beforeData.status !== afterData.status) {
        let notificationTitle = "";
        let notificationBody = "";

        switch (afterData.status) {
          case GameStatus.LIVE:
            notificationTitle = "🟢 Game Started";
            notificationBody = `${afterData.homeTeam} vs ${afterData.awayTeam} is now live!`;
            break;
          case GameStatus.FINISHED:
            notificationTitle = "🏁 Game Finished";
            notificationBody = `Final: ${afterData.homeTeam} ${afterData.homeScore} - ${afterData.awayScore} ${afterData.awayTeam}`;
            break;
          case GameStatus.CANCELLED:
            notificationTitle = "❌ Game Cancelled";
            notificationBody = `${afterData.homeTeam} vs ${afterData.awayTeam} has been cancelled`;
            break;
        }

        if (notificationTitle && notificationBody) {
          await sendNotificationToGroupMembers(
            members,
            notificationTitle,
            notificationBody,
            {
              gameId,
              status: afterData.status,
              groupId: afterData.groupId,
            }
          );
        }
      }

    } catch (error) {
      functions.logger.error("Error in game update trigger:", error);
    }
  });

/**
 * Send notifications to all group members
 */
async function sendNotificationToGroupMembers(
  memberIds: string[],
  title: string,
  body: string,
  data: Record<string, string>
) {
  try {
    // Get FCM tokens for all members
    const tokenPromises = memberIds.map(async (memberId) => {
      const userDoc = await db.collection("users").doc(memberId).get();
      const userData = userDoc.data();
      return userData?.fcmToken;
    });

    const tokens = (await Promise.all(tokenPromises)).filter(Boolean);

    if (tokens.length === 0) {
      functions.logger.info("No FCM tokens found for group members");
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      data,
      tokens,
    };

    const response = await admin.messaging().sendMulticast(message);
    
    functions.logger.info(
      `Sent ${response.successCount} notifications, ${response.failureCount} failed`
    );

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && tokens[idx]) {
          invalidTokens.push(tokens[idx]);
        }
      });

      // Remove invalid tokens from user documents
      const cleanupPromises = memberIds.map(async (memberId) => {
        const userDoc = await db.collection("users").doc(memberId).get();
        const userData = userDoc.data();
        if (userData?.fcmToken && invalidTokens.includes(userData.fcmToken)) {
          await db.collection("users").doc(memberId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        }
      });

      await Promise.all(cleanupPromises);
    }

  } catch (error) {
    functions.logger.error("Error sending notifications:", error);
  }
}