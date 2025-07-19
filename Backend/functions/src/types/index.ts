// User Types
export interface User {
  uid: string;
  email: string;
  displayName: string;
  profileImageUrl?: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  isPremium: boolean;
  groups: string[]; // Array of group IDs
}

// Group Types
export interface Group {
  id: string;
  name: string;
  description?: string;
  createdBy: string; // User UID
  members: string[]; // Array of user UIDs
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  isPrivate: boolean;
  inviteCode?: string;
}

// Game Types
export interface Game {
  id: string;
  groupId: string;
  homeTeam: string;
  awayTeam: string;
  homeScore: number;
  awayScore: number;
  status: GameStatus;
  startTime: FirebaseFirestore.Timestamp;
  endTime?: FirebaseFirestore.Timestamp;
  createdBy: string; // User UID
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  events: GameEvent[];
}

export enum GameStatus {
  SCHEDULED = "scheduled",
  LIVE = "live", 
  PAUSED = "paused",
  FINISHED = "finished",
  CANCELLED = "cancelled"
}

// Game Event Types
export interface GameEvent {
  id: string;
  gameId: string;
  type: GameEventType;
  timestamp: FirebaseFirestore.Timestamp;
  minute: number;
  playerId?: string;
  teamSide: "home" | "away";
  description?: string;
  metadata?: Record<string, any>;
}

export enum GameEventType {
  GOAL = "goal",
  YELLOW_CARD = "yellow_card", 
  RED_CARD = "red_card",
  SUBSTITUTION = "substitution",
  PENALTY = "penalty",
  CORNER = "corner",
  OFFSIDE = "offside",
  FOUL = "foul",
  KICKOFF = "kickoff",
  HALFTIME = "halftime",
  FULLTIME = "fulltime"
}

// Player Types
export interface Player {
  id: string;
  name: string;
  jerseyNumber?: number;
  position?: string;
  teamSide: "home" | "away";
  gameId: string;
}

// Statistics Types
export interface GameStats {
  gameId: string;
  possession: {
    home: number;
    away: number;
  };
  shots: {
    home: number;
    away: number;
  };
  corners: {
    home: number;
    away: number;
  };
  fouls: {
    home: number; 
    away: number;
  };
  cards: {
    home: {
      yellow: number;
      red: number;
    };
    away: {
      yellow: number;
      red: number;
    };
  };
}

// API Response Types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// Request Types
export interface CreateGameRequest {
  groupId: string;
  homeTeam: string;
  awayTeam: string;
  startTime: string; // ISO timestamp
}

export interface UpdateGameRequest {
  homeScore?: number;
  awayScore?: number;
  status?: GameStatus;
}

export interface CreateGroupRequest {
  name: string;
  description?: string;
  isPrivate: boolean;
}

export interface JoinGroupRequest {
  inviteCode: string;
}