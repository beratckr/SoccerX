import * as functions from "firebase-functions";
import { GeoPoint } from "../types";

/**
 * GPS route compression utilities using Douglas-Peucker algorithm
 */

export interface CompressedGPSRoute {
  originalPoints: number;
  compressedPoints: number;
  compressionRatio: number;
  compressedRoute: GeoPoint[];
}

/**
 * Compress GPS route using Douglas-Peucker algorithm
 * @param route Array of GPS points
 * @param epsilon Tolerance in meters (default: 5 meters)
 * @returns Compressed route information
 */
export function compressGPSRoute(route: GeoPoint[], epsilon: number = 5): CompressedGPSRoute {
  if (route.length <= 2) {
    return {
      originalPoints: route.length,
      compressedPoints: route.length,
      compressionRatio: 0,
      compressedRoute: route,
    };
  }

  const compressed = douglasPeucker(route, epsilon);
  const compressionRatio = 1 - (compressed.length / route.length);

  functions.logger.debug(`GPS compression: ${route.length} → ${compressed.length} points (${(compressionRatio * 100).toFixed(1)}% reduction)`);

  return {
    originalPoints: route.length,
    compressedPoints: compressed.length,
    compressionRatio,
    compressedRoute: compressed,
  };
}

/**
 * Douglas-Peucker line simplification algorithm
 * @param points Array of GPS points
 * @param epsilon Tolerance in meters
 * @returns Simplified array of points
 */
function douglasPeucker(points: GeoPoint[], epsilon: number): GeoPoint[] {
  if (points.length <= 2) {
    return points;
  }

  // Find the point with the maximum distance from the line between first and last points
  let maxDistance = 0;
  let maxIndex = 0;
  const startPoint = points[0];
  const endPoint = points[points.length - 1];

  for (let i = 1; i < points.length - 1; i++) {
    const distance = perpendicularDistance(points[i], startPoint, endPoint);
    if (distance > maxDistance) {
      maxDistance = distance;
      maxIndex = i;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (maxDistance > epsilon) {
    // Recursive call for both parts
    const firstPart = douglasPeucker(points.slice(0, maxIndex + 1), epsilon);
    const secondPart = douglasPeucker(points.slice(maxIndex), epsilon);

    // Combine results (remove duplicate point at junction)
    return firstPart.slice(0, -1).concat(secondPart);
  } else {
    // If max distance is less than epsilon, return only endpoints
    return [startPoint, endPoint];
  }
}

/**
 * Calculate perpendicular distance from a point to a line segment
 * @param point The point to measure distance from
 * @param lineStart Start point of the line
 * @param lineEnd End point of the line
 * @returns Distance in meters
 */
function perpendicularDistance(point: GeoPoint, lineStart: GeoPoint, lineEnd: GeoPoint): number {
  // Convert to projected coordinates for more accurate distance calculation
  const x0 = point.longitude;
  const y0 = point.latitude;
  const x1 = lineStart.longitude;
  const y1 = lineStart.latitude;
  const x2 = lineEnd.longitude;
  const y2 = lineEnd.latitude;

  // Calculate perpendicular distance using the formula:
  // |((y2-y1)*x0 - (x2-x1)*y0 + x2*y1 - y2*x1)| / sqrt((y2-y1)^2 + (x2-x1)^2)
  const numerator = Math.abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1);
  const denominator = Math.sqrt(Math.pow(y2 - y1, 2) + Math.pow(x2 - x1, 2));

  if (denominator === 0) {
    // Line start and end are the same point, return distance to that point
    return haversineDistance(point, lineStart);
  }

  // Convert the perpendicular distance to meters
  const distanceInDegrees = numerator / denominator;
  
  // Approximate conversion: 1 degree ≈ 111,000 meters at the equator
  // This is a simplification; for more accuracy, use proper projection
  const metersPerDegree = 111000 * Math.cos(point.latitude * Math.PI / 180);
  
  return distanceInDegrees * metersPerDegree;
}

/**
 * Calculate distance between two GPS points using Haversine formula
 * @param point1 First GPS point
 * @param point2 Second GPS point
 * @returns Distance in meters
 */
export function haversineDistance(point1: GeoPoint, point2: GeoPoint): number {
  const R = 6371000; // Earth's radius in meters
  const lat1Rad = point1.latitude * Math.PI / 180;
  const lat2Rad = point2.latitude * Math.PI / 180;
  const deltaLatRad = (point2.latitude - point1.latitude) * Math.PI / 180;
  const deltaLngRad = (point2.longitude - point1.longitude) * Math.PI / 180;

  const a = Math.sin(deltaLatRad / 2) * Math.sin(deltaLatRad / 2) +
    Math.cos(lat1Rad) * Math.cos(lat2Rad) *
    Math.sin(deltaLngRad / 2) * Math.sin(deltaLngRad / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  
  return R * c;
}

/**
 * Calculate total route distance
 * @param route Array of GPS points
 * @returns Total distance in meters
 */
export function calculateRouteDistance(route: GeoPoint[]): number {
  if (route.length < 2) return 0;

  let totalDistance = 0;
  for (let i = 1; i < route.length; i++) {
    totalDistance += haversineDistance(route[i - 1], route[i]);
  }

  return totalDistance;
}

/**
 * Validate GPS route for basic integrity
 * @param route Array of GPS points
 * @returns Validation result
 */
export function validateGPSRoute(route: GeoPoint[]): {
  isValid: boolean;
  issues: string[];
} {
  const issues: string[] = [];

  if (!route || route.length === 0) {
    issues.push("Route is empty");
    return { isValid: false, issues };
  }

  if (route.length < 2) {
    issues.push("Route must have at least 2 points");
  }

  // Check for invalid coordinates
  for (let i = 0; i < route.length; i++) {
    const point = route[i];
    if (!point || typeof point.latitude !== "number" || typeof point.longitude !== "number") {
      issues.push(`Invalid point at index ${i}: missing or invalid coordinates`);
      continue;
    }

    if (Math.abs(point.latitude) > 90) {
      issues.push(`Invalid latitude at index ${i}: ${point.latitude} (must be between -90 and 90)`);
    }

    if (Math.abs(point.longitude) > 180) {
      issues.push(`Invalid longitude at index ${i}: ${point.longitude} (must be between -180 and 180)`);
    }
  }

  // Check for extremely long jumps (> 1km between consecutive points)
  for (let i = 1; i < route.length; i++) {
    const distance = haversineDistance(route[i - 1], route[i]);
    if (distance > 1000) { // 1km
      issues.push(`Suspicious jump at index ${i}: ${distance.toFixed(0)}m between consecutive points`);
    }
  }

  return {
    isValid: issues.length === 0,
    issues,
  };
}