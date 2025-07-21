import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "../index";
import { Game, GameStatus, GameEventType, MVPScoreBreakdown, HeartRateData, WeatherData, GeoPoint } from "../types";
import { compressGPSRoute, validateGPSRoute } from "../utils/gpsCompression";
import { fetchWeatherData } from "../utils/weatherIntegration";

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
      // Get group members to send notifications to (use first group if multiple)
      if (!afterData.groupIds || afterData.groupIds.length === 0) return;
      
      const groupDoc = await db.collection("groups").doc(afterData.groupIds[0]).get();
      if (!groupDoc.exists) return;

      const groupData = groupDoc.data();
      const members = groupData?.memberIds || [];

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
                groupId: afterData.groupIds[0],
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
              groupId: afterData.groupIds[0],
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

/**
 * Process completed games to calculate MVP score and update statistics
 */
export const processGameCompletion = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes
    memory: "1GB",
  })
  .firestore
  .document("games/{gameId}")
  .onCreate(async (snapshot, context) => {
    const gameId = context.params.gameId;
    const gameData = snapshot.data() as Game;

    try {
      functions.logger.info(`Processing game completion for gameId: ${gameId}`);

      // Only process completed games
      if (!gameData.isCompleted || gameData.processedAt) {
        functions.logger.info(`Game ${gameId} is not completed or already processed`);
        return;
      }

      // Process GPS route and weather data if available
      let compressedRouteUrl: string | undefined;
      let weatherData: WeatherData | null = null;

      // Compress and store GPS route if available
      if (gameData.gpsRouteUrl) {
        try {
          // In a real implementation, you would fetch the GPS data from the URL
          // For now, assume we have the GPS points array
          const gpsPoints: GeoPoint[] = []; // This would be fetched from storage
          
          if (gpsPoints.length > 0) {
            const validation = validateGPSRoute(gpsPoints);
            if (validation.isValid) {
              const compressed = compressGPSRoute(gpsPoints, 5); // 5-meter tolerance
              functions.logger.info(`GPS route compressed: ${compressed.originalPoints} → ${compressed.compressedPoints} points (${(compressed.compressionRatio * 100).toFixed(1)}% reduction)`);
              
              // Store compressed route to Cloud Storage
              compressedRouteUrl = await storeCompressedRoute(gameId, compressed.compressedRoute);
            } else {
              functions.logger.warn(`GPS route validation failed: ${validation.issues.join(", ")}`);
            }
          }
        } catch (error) {
          functions.logger.error("Error processing GPS route:", error);
        }
      }

      // Fetch weather data if we have location information
      if (gameData.gpsRouteUrl) {
        try {
          // Use the first GPS point as the game location
          // In a real implementation, you might use the center point or venue location
          const gameLocation: GeoPoint = { latitude: 40.7128, longitude: -74.0060 }; // Example: NYC
          weatherData = await fetchWeatherData(gameLocation, gameData.startTime.toDate());
          
          if (weatherData) {
            functions.logger.info(`Weather data retrieved: ${weatherData.temperature}°C, ${weatherData.condition}, modifier: ${weatherData.performanceModifier}`);
          }
        } catch (error) {
          functions.logger.error("Error fetching weather data:", error);
        }
      }

      // Calculate MVP score with weather data
      const mvpResult = await calculateMVPScore({ ...gameData, weather: weatherData || undefined });

      // Update game document with MVP score, weather data, and mark as processed
      const updateData: any = {
        mvpScore: mvpResult.totalScore,
        scoreBreakdown: mvpResult,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (weatherData) {
        updateData.weather = weatherData;
      }

      if (compressedRouteUrl) {
        updateData.gpsRouteUrl = compressedRouteUrl;
      }

      await snapshot.ref.update(updateData);

      functions.logger.info(`MVP score calculated for game ${gameId}: ${mvpResult.totalScore}`);

      // Trigger cascading updates (these will be implemented in later subtasks)
      await Promise.all([
        updateUserStatistics(gameData.userId, gameData, mvpResult.totalScore),
        updateGroupLeaderboards(gameData, mvpResult.totalScore),
      ]);

      functions.logger.info(`Game ${gameId} processing completed successfully`);

    } catch (error) {
      functions.logger.error(`Error processing game completion for ${gameId}:`, error);
      
      // Mark game as failed processing for debugging
      await snapshot.ref.update({
        processingError: error instanceof Error ? error.message : String(error),
        processingFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error; // Re-throw to ensure Cloud Functions logs the error
    }
  });

/**
 * Calculate MVP score with all components
 */
async function calculateMVPScore(gameData: Game): Promise<MVPScoreBreakdown> {
  try {
    functions.logger.debug(`Calculating MVP score for game with distance: ${gameData.distance}km, duration: ${gameData.duration}s`);

    // Normalize individual metrics (0-100 scale)
    const distanceScore = normalizeDistance(gameData.distance);
    const avgSpeedScore = normalizeAverageSpeed(gameData.avgSpeed);
    const maxSpeedScore = normalizeMaxSpeed(gameData.maxSpeed);
    const heartRateEfficiencyScore = normalizeHeartRateEfficiency(gameData.heartRateData);
    const consistencyScore = await normalizeConsistency(gameData);

    // Apply weights to calculate total score
    const weights = {
      distance: 0.3,
      avgSpeed: 0.2,
      maxSpeed: 0.15,
      heartRateEfficiency: 0.2,
      consistency: 0.15,
    };

    let totalScore = 
      distanceScore * weights.distance +
      avgSpeedScore * weights.avgSpeed +
      maxSpeedScore * weights.maxSpeed +
      heartRateEfficiencyScore * weights.heartRateEfficiency +
      consistencyScore * weights.consistency;

    // Apply weather modifier if available
    let weatherBonus = 0;
    if (gameData.weather) {
      weatherBonus = calculateWeatherModifier(gameData.weather);
      totalScore += weatherBonus;
    }

    // Cap score at 100, floor at 0
    totalScore = Math.max(0, Math.min(100, totalScore));

    const breakdown: MVPScoreBreakdown = {
      distanceScore,
      avgSpeedScore,
      maxSpeedScore,
      heartRateEfficiencyScore,
      consistencyScore,
      totalScore,
      weatherBonus: weatherBonus !== 0 ? weatherBonus : undefined,
    };

    functions.logger.info(`MVP score breakdown: ${JSON.stringify(breakdown)}`);
    
    return breakdown;

  } catch (error) {
    functions.logger.error("Error calculating MVP score:", error);
    throw new Error(`MVP calculation failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Normalize distance metric to 0-100 scale
 */
function normalizeDistance(distance: number): number {
  if (distance <= 0) return 0;
  
  // Use logarithmic scale for distance (0-15km range)
  // Most recreational games are 5-10km, professional can be 10-13km
  const maxDistance = 15; // km
  const score = (Math.log(distance + 1) / Math.log(maxDistance + 1)) * 100;
  
  return Math.max(0, Math.min(100, score));
}

/**
 * Normalize average speed to 0-100 scale
 */
function normalizeAverageSpeed(avgSpeed: number): number {
  if (avgSpeed <= 0) return 0;
  
  // Linear scale for average speed (0-25 km/h)
  // Professional players average 7-12 km/h during games
  const maxSpeed = 25; // km/h
  const score = (avgSpeed / maxSpeed) * 100;
  
  return Math.max(0, Math.min(100, score));
}

/**
 * Normalize maximum speed to 0-100 scale
 */
function normalizeMaxSpeed(maxSpeed: number): number {
  if (maxSpeed <= 0) return 0;
  
  // Linear scale for max speed (0-35 km/h)
  // Elite players can reach 30+ km/h in sprints
  const maxThreshold = 35; // km/h
  const score = (maxSpeed / maxThreshold) * 100;
  
  return Math.max(0, Math.min(100, score));
}

/**
 * Normalize heart rate efficiency to 0-100 scale
 */
function normalizeHeartRateEfficiency(heartRateData?: HeartRateData): number {
  if (!heartRateData || !heartRateData.efficiency) {
    return 50; // Neutral score if no heart rate data
  }
  
  // Heart rate efficiency is already a percentage, so just ensure it's within bounds
  return Math.max(0, Math.min(100, heartRateData.efficiency));
}

/**
 * Normalize consistency score based on performance variation
 */
async function normalizeConsistency(gameData: Game): Promise<number> {
  try {
    // For now, return a baseline consistency score
    // In the future, this would analyze split times and GPS data for consistency
    
    // Base consistency on game duration vs distance ratio
    if (gameData.duration <= 0 || gameData.distance <= 0) {
      return 50; // Neutral score
    }
    
    const pace = gameData.duration / 60 / gameData.distance; // minutes per km
    
    // Professional soccer pace is typically 8-12 minutes per km including breaks
    const optimalPaceMin = 8;
    const optimalPaceMax = 12;
    
    let consistencyScore;
    if (pace >= optimalPaceMin && pace <= optimalPaceMax) {
      consistencyScore = 100; // Perfect pace consistency
    } else if (pace < optimalPaceMin) {
      // Too fast (unrealistic pace)
      consistencyScore = Math.max(0, 100 - (optimalPaceMin - pace) * 10);
    } else {
      // Too slow
      consistencyScore = Math.max(0, 100 - (pace - optimalPaceMax) * 5);
    }
    
    return Math.max(0, Math.min(100, consistencyScore));
    
  } catch (error) {
    functions.logger.warn("Error calculating consistency score:", error);
    return 50; // Return neutral score on error
  }
}

/**
 * Calculate weather impact modifier
 */
function calculateWeatherModifier(weather: WeatherData): number {
  let modifier = 0;
  
  // Temperature impact (-5 to +5 points)
  const optimalTempMin = 15; // °C
  const optimalTempMax = 25; // °C
  
  if (weather.temperature < optimalTempMin) {
    // Cold penalty
    modifier -= Math.min(5, (optimalTempMin - weather.temperature) * 0.5);
  } else if (weather.temperature > optimalTempMax) {
    // Heat penalty
    modifier -= Math.min(5, (weather.temperature - optimalTempMax) * 0.3);
  }
  
  // Wind impact (-3 to 0 points)
  if (weather.windSpeed > 20) { // km/h
    modifier -= Math.min(3, (weather.windSpeed - 20) * 0.1);
  }
  
  // Rain bonus (+2 points for playing in challenging conditions)
  if (weather.condition.includes("rain") || weather.condition.includes("storm")) {
    modifier += 2;
  }
  
  return Math.max(-10, Math.min(10, modifier)); // Cap at ±10 points
}

/**
 * Update user statistics after game completion
 */
async function updateUserStatistics(userId: string, gameData: Game, mvpScore: number): Promise<void> {
  try {
    const userRef = db.collection("users").doc(userId);
    
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) {
        throw new Error(`User ${userId} not found`);
      }
      
      const userData = userDoc.data();
      const currentStats = userData?.stats || {};
      
      // Calculate updated statistics
      const newTotalGames = (currentStats.totalGames || 0) + 1;
      const newTotalDistance = (currentStats.totalDistance || 0) + gameData.distance;
      const newTotalDuration = (currentStats.totalDuration || 0) + gameData.duration;
      const newAverageMVPScore = ((currentStats.averageMVPScore || 0) * (newTotalGames - 1) + mvpScore) / newTotalGames;
      const newHighestMVPScore = Math.max(currentStats.highestMVPScore || 0, mvpScore);
      
      // Update streak logic (simplified - would need more complex logic for actual streaks)
      const newCurrentStreak = (currentStats.currentStreak || 0) + 1;
      const newLongestStreak = Math.max(currentStats.longestStreak || 0, newCurrentStreak);
      
      const updatedStats = {
        ...currentStats,
        totalGames: newTotalGames,
        totalDistance: newTotalDistance,
        totalDuration: newTotalDuration,
        averageMVPScore: newAverageMVPScore,
        highestMVPScore: newHighestMVPScore,
        currentStreak: newCurrentStreak,
        longestStreak: newLongestStreak,
        lastGameDate: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      transaction.update(userRef, {
        stats: updatedStats,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    functions.logger.info(`User statistics updated for ${userId}`);
    
  } catch (error) {
    functions.logger.error(`Error updating user statistics for ${userId}:`, error);
    throw error;
  }
}

/**
 * Update group leaderboards after game completion
 */
async function updateGroupLeaderboards(gameData: Game, mvpScore: number): Promise<void> {
  try {
    // Get current week ID
    const now = new Date();
    const weekId = getWeekId(now);
    
    // Update leaderboards for all groups the user belongs to
    const updatePromises = gameData.groupIds.map(async (groupId) => {
      const leaderboardId = `${groupId}_${weekId}`;
      const leaderboardRef = db.collection("leaderboards").doc(leaderboardId);
      
      await db.runTransaction(async (transaction) => {
        const leaderboardDoc = await transaction.get(leaderboardRef);
        
        if (!leaderboardDoc.exists) {
          // Create new leaderboard for this week
          const newLeaderboard = {
            groupId,
            weekId,
            rankings: [{
              userId: gameData.userId,
              totalDistance: gameData.distance,
              totalGames: 1,
              avgMVPScore: mvpScore,
              bestMVPScore: mvpScore,
              points: calculateLeaderboardPoints(gameData.distance, mvpScore),
            }],
            startDate: getWeekStart(now),
            endDate: getWeekEnd(now),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          transaction.set(leaderboardRef, newLeaderboard);
        } else {
          // Update existing leaderboard
          const leaderboardData = leaderboardDoc.data();
          const rankings = leaderboardData?.rankings || [];
          
          const userIndex = rankings.findIndex((entry: any) => entry.userId === gameData.userId);
          
          if (userIndex >= 0) {
            // Update existing user entry
            const currentEntry = rankings[userIndex];
            const newTotalGames = currentEntry.totalGames + 1;
            const newAvgMVPScore = ((currentEntry.avgMVPScore * currentEntry.totalGames) + mvpScore) / newTotalGames;
            
            rankings[userIndex] = {
              ...currentEntry,
              totalDistance: currentEntry.totalDistance + gameData.distance,
              totalGames: newTotalGames,
              avgMVPScore: newAvgMVPScore,
              bestMVPScore: Math.max(currentEntry.bestMVPScore, mvpScore),
              points: calculateLeaderboardPoints(currentEntry.totalDistance + gameData.distance, newAvgMVPScore),
            };
          } else {
            // Add new user entry
            rankings.push({
              userId: gameData.userId,
              totalDistance: gameData.distance,
              totalGames: 1,
              avgMVPScore: mvpScore,
              bestMVPScore: mvpScore,
              points: calculateLeaderboardPoints(gameData.distance, mvpScore),
            });
          }
          
          // Sort rankings by points (descending)
          rankings.sort((a: any, b: any) => b.points - a.points);
          
          transaction.update(leaderboardRef, {
            rankings,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });
    });
    
    await Promise.all(updatePromises);
    functions.logger.info(`Leaderboards updated for groups: ${gameData.groupIds.join(", ")}`);
    
  } catch (error) {
    functions.logger.error("Error updating group leaderboards:", error);
    throw error;
  }
}

/**
 * Calculate leaderboard points based on distance and MVP score
 */
function calculateLeaderboardPoints(distance: number, avgMVPScore: number): number {
  // Simple points calculation: distance (km) * 10 + MVP score
  return Math.round(distance * 10 + avgMVPScore);
}

/**
 * Get week ID in format YYYY-WXX
 */
function getWeekId(date: Date): string {
  const year = date.getFullYear();
  const firstDayOfYear = new Date(year, 0, 1);
  const dayOfYear = Math.floor((date.getTime() - firstDayOfYear.getTime()) / (24 * 60 * 60 * 1000)) + 1;
  const weekNumber = Math.ceil(dayOfYear / 7);
  
  return `${year}-W${weekNumber.toString().padStart(2, "0")}`;
}

/**
 * Get start of week (Monday)
 */
function getWeekStart(date: Date): Date {
  const day = date.getDay();
  const diff = date.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
  return new Date(date.setDate(diff));
}

/**
 * Get end of week (Sunday)
 */
function getWeekEnd(date: Date): Date {
  const weekStart = getWeekStart(new Date(date));
  return new Date(weekStart.getTime() + 6 * 24 * 60 * 60 * 1000);
}

/**
 * Store compressed GPS route to Cloud Storage
 */
async function storeCompressedRoute(gameId: string, compressedRoute: GeoPoint[]): Promise<string> {
  try {
    const bucket = admin.storage().bucket();
    const fileName = `games/${gameId}/gps_routes/compressed_route.json`;
    const file = bucket.file(fileName);
    
    const routeData = {
      points: compressedRoute,
      compressedAt: new Date().toISOString(),
      pointCount: compressedRoute.length,
    };
    
    await file.save(JSON.stringify(routeData), {
      metadata: {
        contentType: "application/json",
        cacheControl: "public, max-age=31536000", // 1 year cache
      },
    });
    
    // Make file publicly readable
    await file.makePublic();
    
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
    functions.logger.info(`Compressed GPS route stored at: ${publicUrl}`);
    
    return publicUrl;
    
  } catch (error) {
    functions.logger.error("Error storing compressed GPS route:", error);
    throw new Error(`Failed to store compressed route: ${error instanceof Error ? error.message : String(error)}`);
  }
}