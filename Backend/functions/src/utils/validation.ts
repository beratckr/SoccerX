import * as functions from "firebase-functions";

/**
 * Validate email format
 */
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Validate team name (non-empty, reasonable length)
 */
export function isValidTeamName(name: string): boolean {
  return typeof name === "string" && name.trim().length > 0 && name.trim().length <= 50;
}

/**
 * Validate group name (non-empty, reasonable length)
 */
export function isValidGroupName(name: string): boolean {
  return typeof name === "string" && name.trim().length > 0 && name.trim().length <= 100;
}

/**
 * Validate invite code format
 */
export function isValidInviteCode(code: string): boolean {
  return typeof code === "string" && /^[A-Z0-9]{6}$/.test(code);
}

/**
 * Validate game minute (0-120, allowing for extra time)
 */
export function isValidGameMinute(minute: number): boolean {
  return typeof minute === "number" && minute >= 0 && minute <= 120;
}

/**
 * Validate score (non-negative integer)
 */
export function isValidScore(score: number): boolean {
  return typeof score === "number" && score >= 0 && Number.isInteger(score);
}

/**
 * Sanitize string input (trim and limit length)
 */
export function sanitizeString(input: string, maxLength: number = 1000): string {
  if (typeof input !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Input must be a string"
    );
  }
  
  return input.trim().substring(0, maxLength);
}

/**
 * Validate ISO timestamp string
 */
export function isValidTimestamp(timestamp: string): boolean {
  if (typeof timestamp !== "string") return false;
  
  const date = new Date(timestamp);
  return !isNaN(date.getTime());
}

/**
 * Check if user has permission to modify a resource
 */
export function checkUserPermission(
  userId: string,
  resourceOwnerId: string,
  allowedUsers: string[] = []
): void {
  if (userId !== resourceOwnerId && !allowedUsers.includes(userId)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "User does not have permission to modify this resource"
    );
  }
}

/**
 * Rate limiting helper (basic implementation)
 */
export class RateLimiter {
  private static requests = new Map<string, number[]>();

  static isRateLimited(userId: string, maxRequests: number = 100, windowMs: number = 60000): boolean {
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Get user's request timestamps
    let userRequests = this.requests.get(userId) || [];
    
    // Remove old requests outside the window
    userRequests = userRequests.filter(timestamp => timestamp > windowStart);
    
    // Check if user has exceeded the limit
    if (userRequests.length >= maxRequests) {
      return true;
    }
    
    // Add current request
    userRequests.push(now);
    this.requests.set(userId, userRequests);
    
    return false;
  }

  static checkRateLimit(userId: string, maxRequests: number = 100, windowMs: number = 60000): void {
    if (this.isRateLimited(userId, maxRequests, windowMs)) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many requests. Please try again later."
      );
    }
  }
}