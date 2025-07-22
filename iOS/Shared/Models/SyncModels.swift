import Foundation

// MARK: - GameDataPoint Definition
import CoreLocation

struct GameDataPoint {
    let timestamp: Date
    let location: CLLocationCoordinate2D?
    let speed: Double
    let heartRate: Double
    let accuracy: Double
}

// MARK: - Game Sync Models

struct GameSyncData: Codable, Identifiable {
    let id: UUID
    let gameId: UUID
    let userId: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let distance: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartRate: Double
    let maxHeartRate: Double
    let calories: Double
    let mvpScore: Double?
    let events: [SyncGameEvent]
    let dataPoints: [CompressedDataPoint]
    let syncStatus: SyncStatus
    let lastModified: Date
    
    init(
        id: UUID = UUID(),
        gameId: UUID,
        userId: String,
        startTime: Date,
        endTime: Date? = nil,
        duration: TimeInterval = 0,
        distance: Double = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        averageHeartRate: Double = 0,
        maxHeartRate: Double = 0,
        calories: Double = 0,
        mvpScore: Double? = nil,
        events: [SyncGameEvent] = [],
        dataPoints: [CompressedDataPoint] = [],
        syncStatus: SyncStatus = .pending,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.gameId = gameId
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
        self.mvpScore = mvpScore
        self.events = events
        self.dataPoints = dataPoints
        self.syncStatus = syncStatus
        self.lastModified = lastModified
    }
}

struct SyncGameEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let data: [String: String]
    
    enum EventType: String, Codable, CaseIterable {
        case gameStart = "game_start"
        case gameEnd = "game_end"
        case pause = "pause"
        case resume = "resume"
        case milestone = "milestone"
        case heartRateZone = "heart_rate_zone"
        case speedThreshold = "speed_threshold"
    }
}

struct CompressedDataPoint: Codable {
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
    let speed: Double
    let heartRate: Double
    let accuracy: Double
    
    // Compressed representation of GameDataPoint
    init(from gameDataPoint: GameDataPoint) {
        self.timestamp = gameDataPoint.timestamp
        self.latitude = gameDataPoint.location?.latitude
        self.longitude = gameDataPoint.location?.longitude
        self.speed = gameDataPoint.speed
        self.heartRate = gameDataPoint.heartRate
        self.accuracy = gameDataPoint.accuracy
    }
}

// MARK: - Sync Status and Priority

enum SyncStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    case conflict = "conflict"
}

enum SyncPriority: String, Codable, CaseIterable, Comparable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var numericValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        return lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Sync Queue Item

struct SyncQueueItem: Codable, Identifiable {
    let id: UUID
    let messageType: String // Store as String for Codable
    let priority: SyncPriority
    let payload: Data
    let createdAt: Date
    let expiresAt: Date
    var retryCount: Int
    var lastAttempt: Date?
    var syncStatus: SyncStatus
    
    // Computed property to get the actual MessageType
    var messageTypeEnum: SharedWatchConnectivityManager.MessageType? {
        SharedWatchConnectivityManager.MessageType(rawValue: messageType)
    }
    
    init(
        messageType: SharedWatchConnectivityManager.MessageType,
        priority: SyncPriority,
        payload: Data,
        retryCount: Int = 0
    ) {
        self.id = UUID()
        self.messageType = messageType.rawValue
        self.priority = priority
        self.payload = payload
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval.sevenDays)
        self.retryCount = retryCount
        self.syncStatus = .pending
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var shouldRetry: Bool {
        return retryCount < 3 && !isExpired && syncStatus == .failed
    }
}

// MARK: - User Profile Sync

struct UserProfileSync: Codable {
    let userId: String
    let displayName: String?
    let email: String?
    let profileImageUrl: String?
    let preferences: UserPreferences
    let statistics: UserStatistics
    let lastUpdated: Date
}

struct UserPreferences: Codable {
    let biometricLockEnabled: Bool
    let notificationsEnabled: Bool
    let autoSyncEnabled: Bool
    let dataCompressionEnabled: Bool
    let batteryOptimizationEnabled: Bool
    let goalRemindersEnabled: Bool
    let weeklyReportsEnabled: Bool
}

struct UserStatistics: Codable {
    let totalGames: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let totalCalories: Double
    let averageMVPScore: Double
    let bestMVPScore: Double
    let currentStreak: Int
    let longestStreak: Int
    let lastGameDate: Date?
}

// MARK: - Group Sync Models

struct GroupSync: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let creatorId: String
    let memberIds: [String]
    let inviteCode: String
    let isPublic: Bool
    let memberLimit: Int
    let weeklyChallenge: SyncWeeklyChallenge?
    let leaderboard: [SyncLeaderboardEntry]
    let lastUpdated: Date
}

struct SyncWeeklyChallenge: Codable {
    let id: UUID
    let groupId: UUID
    let startDate: Date
    let endDate: Date
    let type: ChallengeType
    let targetValue: Double
    let participants: [String]
    let leaderboard: [ChallengeEntry]
    let isActive: Bool
    
    enum ChallengeType: String, Codable, CaseIterable {
        case totalDistance = "total_distance"
        case totalGames = "total_games"
        case averageMVPScore = "average_mvp_score"
        case longestGame = "longest_game"
        case bestSpeedRun = "best_speed_run"
    }
}

struct SyncLeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let score: Double
    let rank: Int
    let previousRank: Int?
    let gamesPlayed: Int
    let lastActive: Date
}

struct ChallengeEntry: Codable, Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let value: Double
    let rank: Int
    let achievedAt: Date
}

// MARK: - Sync Metadata

struct SyncMetadata: Codable {
    let deviceId: String
    let platform: Platform
    let appVersion: String
    let lastSyncTime: Date
    let pendingItemsCount: Int
    let totalDataSize: Int64
    let compressionRatio: Double?
    
    enum Platform: String, Codable, CaseIterable {
        case iOS = "iOS"
        case watchOS = "watchOS"
    }
}

// MARK: - Time Extensions

extension TimeInterval {
    static let sevenDays: TimeInterval = 7 * 24 * 60 * 60
    static let oneHour: TimeInterval = 60 * 60
    static let fiveMinutes: TimeInterval = 5 * 60
}

// MARK: - Batch Transfer

struct BatchTransfer: Codable {
    let batchId: UUID
    let items: [SyncQueueItem]
    let totalSize: Int
    let compressionEnabled: Bool
    let checksum: String
    let createdAt: Date
    
    init(items: [SyncQueueItem], compressionEnabled: Bool = true) {
        self.batchId = UUID()
        self.items = items
        self.compressionEnabled = compressionEnabled
        self.createdAt = Date()
        
        // Calculate total size
        self.totalSize = items.reduce(0) { $0 + $1.payload.count }
        
        // Simple checksum calculation
        let combinedData = items.map { $0.id.uuidString }.joined()
        self.checksum = String(combinedData.hashValue)
    }
}

// MARK: - Connection Quality

enum ConnectionQuality: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case none = "none"
    
    var maxBatchSize: Int {
        switch self {
        case .excellent: return 10
        case .good: return 7
        case .fair: return 5
        case .poor: return 3
        case .none: return 1
        }
    }
    
    var recommendedDelay: TimeInterval {
        switch self {
        case .excellent: return 0.5
        case .good: return 1.0
        case .fair: return 2.0
        case .poor: return 5.0
        case .none: return 10.0
        }
    }
}