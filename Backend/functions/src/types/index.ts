import { Timestamp } from "firebase-admin/firestore";

// User types
export interface User {
  uid: string;
  email: string;
  displayName: string;
  profileImageUrl?: string;
  stats: UserStats;
  achievements: string[]; // Achievement IDs
  groupIds: string[];
  isPremium: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface UserStats {
  totalGames: number;
  totalDistance: number; // in kilometers
  totalDuration: number; // in seconds
  averageMVPScore: number;
  highestMVPScore: number;
  currentStreak: number;
  longestStreak: number;
  totalCalories: number;
  favoritePlayTime?: string; // e.g., "evening", "morning"
  lastGameDate?: Timestamp;
}

// Game types
export interface Game {
  userId: string;
  groupIds: string[];
  homeTeam: string;
  awayTeam: string;
  homeScore: number;
  awayScore: number;
  status: GameStatus;
  startTime: Timestamp;
  endTime?: Timestamp;
  duration: number; // in seconds
  distance: number; // in kilometers
  avgSpeed: number; // in km/h
  maxSpeed: number; // in km/h
  mvpScore?: number;
  scoreBreakdown?: MVPScoreBreakdown;
  gpsRouteUrl?: string; // Cloud Storage URL
  heartRateData?: HeartRateData;
  events: GameEvent[];
  weather?: WeatherData;
  isCompleted: boolean;
  processedAt?: Timestamp;
}

export interface MVPScoreBreakdown {
  distanceScore: number;
  avgSpeedScore: number;
  maxSpeedScore: number;
  heartRateEfficiencyScore: number;
  consistencyScore: number;
  totalScore: number;
  weatherBonus?: number;
}

export interface HeartRateData {
  average: number;
  max: number;
  min: number;
  zones: HeartRateZones;
  efficiency: number;
}

export interface HeartRateZones {
  resting: number; // % of time
  warmup: number;
  aerobic: number;
  anaerobic: number;
  maximum: number;
}

export interface GameEvent {
  id: string;
  type: GameEventType;
  timestamp: Date;
  minute?: number;
  teamSide?: "home" | "away";
  location?: GeoPoint;
  metadata?: Record<string, string>;
}

export interface WeatherData {
  temperature: number; // Celsius
  humidity: number; // Percentage
  windSpeed: number; // km/h
  condition: string; // e.g., "clear", "rain", "cloudy"
  uvIndex?: number;
  performanceModifier: number;
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export enum EventType {
  START = "start",
  PAUSE = "pause",
  RESUME = "resume",
  END = "end",
  GOAL = "goal",
  ASSIST = "assist",
  SAVE = "save",
  FOUL = "foul",
  YELLOW_CARD = "yellow_card",
  RED_CARD = "red_card",
  SUBSTITUTION = "substitution",
  INJURY = "injury",
  HYDRATION = "hydration"
}

// Group types
export interface Group {
  name: string;
  description?: string;
  creatorId: string;
  memberIds: string[];
  pendingMemberIds: string[];
  inviteCode: string;
  isPublic: boolean;
  isPremium: boolean;
  maxMembers: number;
  weeklyChallenge?: WeeklyChallenge;
  settings: GroupSettings;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface WeeklyChallenge {
  id: string;
  type: ChallengeType;
  title: string;
  description: string;
  target: number; // Target value depends on type
  startDate: Date;
  endDate: Date;
}

export enum ChallengeType {
  TOTAL_DISTANCE = "total_distance",
  TOTAL_GAMES = "total_games",
  AVG_MVP_SCORE = "avg_mvp_score",
  CONSISTENT_PLAYER = "consistent_player",
  SPEED_DEMON = "speed_demon",
  ENDURANCE = "endurance"
}

export interface GroupSettings {
  autoApproveMembers: boolean;
  allowMemberInvites: boolean;
  shareGameDetails: boolean;
  notifyOnNewGames: boolean;
  showMemberLocations: boolean;
  minimumGamesPerWeek: number;
  kickInactiveDays?: number; // Auto-remove after X days of inactivity
}

// Leaderboard types
export interface Leaderboard {
  groupId: string;
  weekId: string; // Format: "2024-W30"
  rankings: LeaderboardEntry[];
  startDate: Date;
  endDate: Date;
  lastUpdated: Timestamp;
}

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  profileImageUrl?: string;
  totalDistance: number;
  totalGames: number;
  avgMVPScore: number;
  bestMVPScore: number;
  points: number; // Calculated based on group scoring system
}

// Achievement types
export interface Achievement {
  id: string;
  category: AchievementCategory;
  title: string;
  description: string;
  iconName: string;
  requirement: AchievementRequirement;
  points: number;
  tier: AchievementTier;
  isSecret: boolean;
}

export enum AchievementCategory {
  DISTANCE = "distance",
  SPEED = "speed",
  CONSISTENCY = "consistency",
  SOCIAL = "social",
  MVP_SCORE = "mvp_score",
  SPECIAL = "special",
  MILESTONE = "milestone"
}

export enum AchievementTier {
  BRONZE = 1,
  SILVER = 2,
  GOLD = 3,
  PLATINUM = 4
}

export interface AchievementRequirement {
  type: RequirementType;
  value: number;
  timeframe?: Timeframe;
}

export enum RequirementType {
  TOTAL_DISTANCE = "total_distance",
  SINGLE_GAME_DISTANCE = "single_game_distance",
  TOTAL_GAMES = "total_games",
  CONSECUTIVE_GAMES = "consecutive_games",
  AVG_MVP_SCORE = "avg_mvp_score",
  SINGLE_MVP_SCORE = "single_mvp_score",
  MAX_SPEED = "max_speed",
  GROUPS_JOINED = "groups_joined",
  GAMES_WITH_FRIENDS = "games_with_friends",
  WEEKLY_STREAK = "weekly_streak",
  PERFECT_WEEK = "perfect_week",
  EARLY_BIRD = "early_bird",
  NIGHT_OWL = "night_owl"
}

export enum Timeframe {
  ALL_TIME = "all_time",
  WEEKLY = "weekly",
  MONTHLY = "monthly",
  DAILY = "daily"
}

export interface UserAchievement {
  userId: string;
  unlockedAchievements: UnlockedAchievement[];
  achievementProgress: Record<string, AchievementProgress>;
  totalPoints: number;
  lastUpdated: Timestamp;
}

export interface UnlockedAchievement {
  achievementId: string;
  unlockedAt: Date;
  gameId?: string; // Game that triggered the achievement
}

export interface AchievementProgress {
  achievementId: string;
  currentValue: number;
  targetValue: number;
  lastUpdated: Date;
}

// Response types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// Cloud Function trigger data types
export interface GameCompletionData {
  gameId: string;
  userId: string;
  finalStats: {
    duration: number;
    distance: number;
    avgSpeed: number;
    maxSpeed: number;
    heartRateData?: HeartRateData;
    gpsPoints: GeoPoint[];
  };
}

export interface LeaderboardUpdateData {
  groupId: string;
  weekId: string;
  userId: string;
  gameStats: {
    distance: number;
    duration: number;
    mvpScore: number;
  };
}

// Request types for API endpoints
export interface CreateGameRequest {
  groupIds?: string[];
  homeTeam: string;
  awayTeam: string;
  startTime?: string; // ISO timestamp
}

export interface UpdateGameRequest {
  duration?: number;
  distance?: number;
  avgSpeed?: number;
  maxSpeed?: number;
  homeScore?: number;
  awayScore?: number;
  status?: GameStatus;
  isCompleted?: boolean;
  events?: GameEvent[];
}

export interface CreateGroupRequest {
  name: string;
  description?: string;
  isPublic: boolean;
  isPrivate?: boolean;
  maxMembers?: number;
}

export interface JoinGroupRequest {
  inviteCode: string;
}

export interface UpdateUserStatsRequest {
  totalGames?: number;
  totalDistance?: number;
  totalDuration?: number;
  averageMVPScore?: number;
  highestMVPScore?: number;
  currentStreak?: number;
  longestStreak?: number;
}

// Game status and event types
export enum GameStatus {
  SCHEDULED = "scheduled",
  LIVE = "live", 
  FINISHED = "finished",
  CANCELLED = "cancelled"
}

export enum GameEventType {
  GOAL = "goal",
  YELLOW_CARD = "yellow_card", 
  RED_CARD = "red_card",
  HALFTIME = "halftime",
  FULLTIME = "fulltime"
}