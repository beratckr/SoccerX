import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Export the Firestore database reference
export const db = admin.firestore();

// Health check function
export const healthCheck = functions.https.onRequest((request, response) => {
  functions.logger.info("Health check requested", {structuredData: true});
  response.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "SoccerX Backend Functions",
  });
});

// User management functions
export * from "./services/userService";

// Game management functions  
export * from "./services/gameService";

// Group management functions
export * from "./services/groupService";

// Trigger functions
export * from "./triggers/userTriggers";
export * from "./triggers/gameTriggers";