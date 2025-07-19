import * as functions from "firebase-functions";
import { db } from "../index";
import { 
  Game, 
  GameEvent, 
  GameStatus, 
  GameEventType,
  CreateGameRequest, 
  UpdateGameRequest,
  ApiResponse 
} from "../types";

/**
 * Create a new game
 */
export const createGame = functions.https.onCall(async (data: CreateGameRequest, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { groupId, homeTeam, awayTeam, startTime } = data;
  const uid = context.auth.uid;

  try {
    // Verify user is member of the group
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Group not found");
    }

    const groupData = groupDoc.data();
    if (!groupData?.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied", 
        "User is not a member of this group"
      );
    }

    const gameDoc = db.collection("games").doc();
    const game: Game = {
      id: gameDoc.id,
      groupId,
      homeTeam,
      awayTeam,
      homeScore: 0,
      awayScore: 0,
      status: GameStatus.SCHEDULED,
      startTime: new Date(startTime) as any,
      createdBy: uid,
      createdAt: new Date() as any,
      updatedAt: new Date() as any,
      events: [],
    };

    await gameDoc.set(game);

    const response: ApiResponse<Game> = {
      success: true,
      data: game,
      message: "Game created successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error creating game:", error);
    
    const response: ApiResponse<Game> = {
      success: false,
      error: "Failed to create game",
    };

    return response;
  }
});

/**
 * Update game (score, status, etc.)
 */
export const updateGame = functions.https.onCall(async (data: { gameId: string } & UpdateGameRequest, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { gameId, homeScore, awayScore, status } = data;
  const uid = context.auth.uid;

  try {
    const gameDoc = await db.collection("games").doc(gameId).get();
    if (!gameDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Game not found");
    }

    const gameData = gameDoc.data() as Game;

    // Verify user is member of the group
    const groupDoc = await db.collection("groups").doc(gameData.groupId).get();
    const groupData = groupDoc.data();
    if (!groupData?.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User is not a member of this group"
      );
    }

    const updateData: Partial<Game> = {
      updatedAt: new Date() as any,
    };

    if (homeScore !== undefined) updateData.homeScore = homeScore;
    if (awayScore !== undefined) updateData.awayScore = awayScore;
    if (status !== undefined) {
      updateData.status = status;
      if (status === GameStatus.FINISHED) {
        updateData.endTime = new Date() as any;
      }
    }

    await db.collection("games").doc(gameId).update(updateData);

    const response: ApiResponse<null> = {
      success: true,
      message: "Game updated successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error updating game:", error);
    
    const response: ApiResponse<null> = {
      success: false,
      error: "Failed to update game",
    };

    return response;
  }
});

/**
 * Add game event (goal, card, etc.)
 */
export const addGameEvent = functions.https.onCall(async (data: {
  gameId: string;
  type: GameEventType;
  minute: number;
  teamSide: "home" | "away";
  playerId?: string;
  description?: string;
}, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { gameId, type, minute, teamSide, playerId, description } = data;
  const uid = context.auth.uid;

  try {
    const gameDoc = await db.collection("games").doc(gameId).get();
    if (!gameDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Game not found");
    }

    const gameData = gameDoc.data() as Game;

    // Verify user is member of the group
    const groupDoc = await db.collection("groups").doc(gameData.groupId).get();
    const groupData = groupDoc.data();
    if (!groupData?.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User is not a member of this group"
      );
    }

    const eventId = `${gameId}_${Date.now()}`;
    const gameEvent: GameEvent = {
      id: eventId,
      gameId,
      type,
      timestamp: new Date() as any,
      minute,
      teamSide,
      playerId,
      description,
    };

    // Update the game's events array
    const updatedEvents = [...gameData.events, gameEvent];
    
    // Update score if it's a goal
    const updateData: Partial<Game> = {
      events: updatedEvents,
      updatedAt: new Date() as any,
    };

    if (type === GameEventType.GOAL) {
      if (teamSide === "home") {
        updateData.homeScore = gameData.homeScore + 1;
      } else {
        updateData.awayScore = gameData.awayScore + 1;
      }
    }

    await db.collection("games").doc(gameId).update(updateData);

    const response: ApiResponse<GameEvent> = {
      success: true,
      data: gameEvent,
      message: "Game event added successfully",
    };

    return response;
  } catch (error) {
    functions.logger.error("Error adding game event:", error);
    
    const response: ApiResponse<GameEvent> = {
      success: false,
      error: "Failed to add game event",
    };

    return response;
  }
});

/**
 * Get games for a group
 */
export const getGroupGames = functions.https.onCall(async (data: { groupId: string }, context) => {
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
    // Verify user is member of the group
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Group not found");
    }

    const groupData = groupDoc.data();
    if (!groupData?.members.includes(uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User is not a member of this group"
      );
    }

    const gamesSnapshot = await db.collection("games")
      .where("groupId", "==", groupId)
      .orderBy("startTime", "desc")
      .get();

    const games = gamesSnapshot.docs.map(doc => doc.data() as Game);

    const response: ApiResponse<Game[]> = {
      success: true,
      data: games,
    };

    return response;
  } catch (error) {
    functions.logger.error("Error getting group games:", error);
    
    const response: ApiResponse<Game[]> = {
      success: false,
      error: "Failed to get games",
    };

    return response;
  }
});