import * as functions from "firebase-functions";
import { WeatherData, GeoPoint } from "../types";

/**
 * Weather integration utilities for fetching weather data at game time/location
 */

interface OpenWeatherMapResponse {
  main: {
    temp: number;
    humidity: number;
  };
  wind: {
    speed: number;
  };
  weather: Array<{
    main: string;
    description: string;
  }>;
  uvi?: number;
}

/**
 * Fetch weather data for a specific location and time
 * @param location GPS coordinates of the game
 * @param timestamp Game timestamp
 * @returns Weather data with performance modifier
 */
export async function fetchWeatherData(location: GeoPoint, timestamp: Date): Promise<WeatherData | null> {
  try {
    // In a real implementation, you would use OpenWeatherMap API
    // For now, return simulated weather data based on location and season
    
    const month = timestamp.getMonth() + 1; // 1-12
    const simulatedWeather = generateSimulatedWeather(location, month);
    
    functions.logger.info(`Generated weather data for location (${location.latitude}, ${location.longitude}) at ${timestamp.toISOString()}`);
    
    return simulatedWeather;
    
  } catch (error) {
    functions.logger.error("Error fetching weather data:", error);
    return null;
  }
}

/**
 * Generate simulated weather data based on location and season
 * This would be replaced with actual API calls in production
 */
function generateSimulatedWeather(location: GeoPoint, month: number): WeatherData {
  // Determine season based on month and hemisphere
  const isNorthernHemisphere = location.latitude > 0;
  const isWinter = isNorthernHemisphere ? 
    (month >= 12 || month <= 2) : 
    (month >= 6 && month <= 8);
  const isSummer = isNorthernHemisphere ? 
    (month >= 6 && month <= 8) : 
    (month >= 12 || month <= 2);

  // Generate temperature based on season and latitude
  let baseTemp: number;
  if (isWinter) {
    baseTemp = Math.max(-5, 15 - Math.abs(location.latitude) * 0.5);
  } else if (isSummer) {
    baseTemp = Math.min(35, 25 + Math.abs(location.latitude) * 0.3);
  } else {
    baseTemp = 15 + Math.abs(location.latitude) * 0.2;
  }

  // Add some randomness
  const temperature = baseTemp + (Math.random() - 0.5) * 10;
  
  // Generate other weather parameters
  const humidity = 40 + Math.random() * 40; // 40-80%
  const windSpeed = Math.random() * 25; // 0-25 km/h
  
  // Determine weather condition
  const conditions = ["clear", "partly_cloudy", "cloudy", "light_rain", "rain"];
  const weights = [0.3, 0.25, 0.25, 0.15, 0.05]; // Bias towards better weather
  const condition = weightedRandomChoice(conditions, weights);
  
  // Calculate performance modifier
  const performanceModifier = calculatePerformanceModifier(temperature, humidity, windSpeed, condition);
  
  return {
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity),
    windSpeed: Math.round(windSpeed * 10) / 10,
    condition,
    uvIndex: condition.includes("clear") ? Math.floor(Math.random() * 8) + 1 : undefined,
    performanceModifier,
  };
}

/**
 * Calculate performance modifier based on weather conditions
 */
function calculatePerformanceModifier(
  temperature: number, 
  humidity: number, 
  windSpeed: number, 
  condition: string
): number {
  let modifier = 1.0;
  
  // Temperature impact
  if (temperature < 5) {
    modifier -= 0.1; // Cold penalty
  } else if (temperature > 30) {
    modifier -= 0.15; // Heat penalty
  } else if (temperature >= 15 && temperature <= 25) {
    modifier += 0.05; // Optimal temperature bonus
  }
  
  // Humidity impact
  if (humidity > 80) {
    modifier -= 0.05; // High humidity penalty
  }
  
  // Wind impact
  if (windSpeed > 20) {
    modifier -= 0.05; // Strong wind penalty
  }
  
  // Weather condition impact
  switch (condition) {
    case "clear":
      modifier += 0.05;
      break;
    case "light_rain":
      // No penalty for light rain (can be refreshing)
      break;
    case "rain":
      modifier -= 0.1;
      break;
    case "storm":
      modifier -= 0.2;
      break;
    default:
      // partly_cloudy, cloudy - no impact
      break;
  }
  
  // Ensure modifier stays within reasonable bounds
  return Math.max(0.7, Math.min(1.3, modifier));
}

/**
 * Weighted random choice helper function
 */
function weightedRandomChoice(items: string[], weights: number[]): string {
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
  let random = Math.random() * totalWeight;
  
  for (let i = 0; i < items.length; i++) {
    random -= weights[i];
    if (random <= 0) {
      return items[i];
    }
  }
  
  return items[items.length - 1]; // Fallback
}

/**
 * Real OpenWeatherMap API integration (commented out for now)
 * Uncomment and configure when ready to use actual weather data
 */
/*
export async function fetchOpenWeatherMapData(location: GeoPoint, apiKey: string): Promise<WeatherData | null> {
  try {
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${location.latitude}&lon=${location.longitude}&appid=${apiKey}&units=metric`;
    
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Weather API error: ${response.status}`);
    }
    
    const data: OpenWeatherMapResponse = await response.json();
    
    return {
      temperature: data.main.temp,
      humidity: data.main.humidity,
      windSpeed: data.wind.speed * 3.6, // Convert m/s to km/h
      condition: mapOpenWeatherCondition(data.weather[0].main),
      uvIndex: data.uvi,
      performanceModifier: calculatePerformanceModifier(
        data.main.temp,
        data.main.humidity,
        data.wind.speed * 3.6,
        mapOpenWeatherCondition(data.weather[0].main)
      ),
    };
    
  } catch (error) {
    functions.logger.error("Error fetching OpenWeatherMap data:", error);
    return null;
  }
}

function mapOpenWeatherCondition(condition: string): string {
  const mapping: Record<string, string> = {
    "Clear": "clear",
    "Clouds": "cloudy",
    "Rain": "rain",
    "Drizzle": "light_rain",
    "Thunderstorm": "storm",
    "Snow": "snow",
    "Mist": "foggy",
    "Fog": "foggy",
  };
  
  return mapping[condition] || "unknown";
}
*/