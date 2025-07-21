import Foundation
import FirebaseFirestore

struct Achievement: Codable, Identifiable {
    let id: String
    let category: AchievementCategory
    let title: String
    let description: String
    let iconName: String
    let requirement: AchievementRequirement
    let points: Int
    let tier: AchievementTier
    var isSecret: Bool = false
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case distance = "distance"
        case speed = "speed"
        case consistency = "consistency"
        case social = "social"
        case mvpScore = "mvp_score"
        case special = "special"
        case milestone = "milestone"
    }
    
    enum AchievementTier: Int, Codable {
        case bronze = 1
        case silver = 2
        case gold = 3
        case platinum = 4
        
        var color: String {
            switch self {
            case .bronze: return "#CD7F32"
            case .silver: return "#C0C0C0"
            case .gold: return "#FFD700"
            case .platinum: return "#E5E4E2"
            }
        }
    }
}

struct AchievementRequirement: Codable {
    let type: RequirementType
    let value: Double
    let timeframe: Timeframe?
    
    enum RequirementType: String, Codable {
        case totalDistance = "total_distance"
        case singleGameDistance = "single_game_distance"
        case totalGames = "total_games"
        case consecutiveGames = "consecutive_games"
        case avgMVPScore = "avg_mvp_score"
        case singleMVPScore = "single_mvp_score"
        case maxSpeed = "max_speed"
        case groupsJoined = "groups_joined"
        case gamesWithFriends = "games_with_friends"
        case weeklyStreak = "weekly_streak"
        case perfectWeek = "perfect_week" // 7 games in 7 days
        case earlyBird = "early_bird" // Games before 7 AM
        case nightOwl = "night_owl" // Games after 10 PM
    }
    
    enum Timeframe: String, Codable {
        case allTime = "all_time"
        case weekly = "weekly"
        case monthly = "monthly"
        case daily = "daily"
    }
}

// User's achievement progress
struct UserAchievement: Codable, Identifiable {
    @DocumentID var id: String? // Same as userId
    let userId: String
    var unlockedAchievements: [UnlockedAchievement]
    var achievementProgress: [String: AchievementProgress] // achievementId -> progress
    var totalPoints: Int
    @ServerTimestamp var lastUpdated: Timestamp?
    
    // Computed properties
    var unlockedCount: Int {
        unlockedAchievements.count
    }
    
    var unlockedAchievementIds: Set<String> {
        Set(unlockedAchievements.map { $0.achievementId })
    }
}

struct UnlockedAchievement: Codable {
    let achievementId: String
    let unlockedAt: Date
    let gameId: String? // Game that triggered the achievement
}

struct AchievementProgress: Codable {
    let achievementId: String
    var currentValue: Double
    let targetValue: Double
    var lastUpdated: Date
    
    // Computed properties
    var progressPercentage: Double {
        min((currentValue / targetValue) * 100, 100)
    }
    
    var isCompleted: Bool {
        currentValue >= targetValue
    }
}

// MARK: - Predefined Achievements
extension Achievement {
    static let allAchievements: [Achievement] = [
        // Distance Achievements
        Achievement(
            id: "first_km",
            category: .distance,
            title: "First Steps",
            description: "Complete your first kilometer",
            iconName: "figure.walk",
            requirement: AchievementRequirement(type: .totalDistance, value: 1, timeframe: nil),
            points: 10,
            tier: .bronze
        ),
        Achievement(
            id: "marathon_runner",
            category: .distance,
            title: "Marathon Runner",
            description: "Run 42.2km total distance",
            iconName: "figure.run",
            requirement: AchievementRequirement(type: .totalDistance, value: 42.2, timeframe: nil),
            points: 50,
            tier: .gold
        ),
        Achievement(
            id: "century_club",
            category: .distance,
            title: "Century Club",
            description: "Run 100km total distance",
            iconName: "flag.checkered",
            requirement: AchievementRequirement(type: .totalDistance, value: 100, timeframe: nil),
            points: 100,
            tier: .platinum
        ),
        
        // Speed Achievements
        Achievement(
            id: "speed_demon",
            category: .speed,
            title: "Speed Demon",
            description: "Reach 25 km/h max speed",
            iconName: "speedometer",
            requirement: AchievementRequirement(type: .maxSpeed, value: 25, timeframe: nil),
            points: 30,
            tier: .silver
        ),
        Achievement(
            id: "lightning_bolt",
            category: .speed,
            title: "Lightning Bolt",
            description: "Reach 30 km/h max speed",
            iconName: "bolt.fill",
            requirement: AchievementRequirement(type: .maxSpeed, value: 30, timeframe: nil),
            points: 50,
            tier: .gold
        ),
        
        // Consistency Achievements
        Achievement(
            id: "weekend_warrior",
            category: .consistency,
            title: "Weekend Warrior",
            description: "Play 2 games in a weekend",
            iconName: "calendar",
            requirement: AchievementRequirement(type: .consecutiveGames, value: 2, timeframe: .weekly),
            points: 20,
            tier: .bronze
        ),
        Achievement(
            id: "perfect_week",
            category: .consistency,
            title: "Perfect Week",
            description: "Play 7 games in 7 days",
            iconName: "star.fill",
            requirement: AchievementRequirement(type: .perfectWeek, value: 7, timeframe: .weekly),
            points: 70,
            tier: .gold
        ),
        Achievement(
            id: "iron_man",
            category: .consistency,
            title: "Iron Man",
            description: "30-day consecutive game streak",
            iconName: "flame.fill",
            requirement: AchievementRequirement(type: .consecutiveGames, value: 30, timeframe: nil),
            points: 150,
            tier: .platinum
        ),
        
        // MVP Score Achievements
        Achievement(
            id: "mvp_rookie",
            category: .mvpScore,
            title: "MVP Rookie",
            description: "Score 80+ MVP points in a game",
            iconName: "medal",
            requirement: AchievementRequirement(type: .singleMVPScore, value: 80, timeframe: nil),
            points: 25,
            tier: .bronze
        ),
        Achievement(
            id: "mvp_master",
            category: .mvpScore,
            title: "MVP Master",
            description: "Score 95+ MVP points in a game",
            iconName: "trophy.fill",
            requirement: AchievementRequirement(type: .singleMVPScore, value: 95, timeframe: nil),
            points: 100,
            tier: .platinum
        ),
        
        // Social Achievements
        Achievement(
            id: "team_player",
            category: .social,
            title: "Team Player",
            description: "Join your first group",
            iconName: "person.3.fill",
            requirement: AchievementRequirement(type: .groupsJoined, value: 1, timeframe: nil),
            points: 15,
            tier: .bronze
        ),
        Achievement(
            id: "social_butterfly",
            category: .social,
            title: "Social Butterfly",
            description: "Join 5 different groups",
            iconName: "person.3.sequence.fill",
            requirement: AchievementRequirement(type: .groupsJoined, value: 5, timeframe: nil),
            points: 40,
            tier: .silver
        ),
        
        // Special Achievements
        Achievement(
            id: "early_bird",
            category: .special,
            title: "Early Bird",
            description: "Complete 10 games before 7 AM",
            iconName: "sunrise.fill",
            requirement: AchievementRequirement(type: .earlyBird, value: 10, timeframe: nil),
            points: 30,
            tier: .silver,
            isSecret: true
        ),
        Achievement(
            id: "night_owl",
            category: .special,
            title: "Night Owl",
            description: "Complete 10 games after 10 PM",
            iconName: "moon.stars.fill",
            requirement: AchievementRequirement(type: .nightOwl, value: 10, timeframe: nil),
            points: 30,
            tier: .silver,
            isSecret: true
        )
    ]
    
    static func achievement(by id: String) -> Achievement? {
        allAchievements.first { $0.id == id }
    }
}

// MARK: - Firestore Extensions
extension UserAchievement {
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "unlockedAchievements": unlockedAchievements.map { $0.toDictionary() },
            "achievementProgress": achievementProgress.mapValues { $0.toDictionary() },
            "totalPoints": totalPoints,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
    }
}

extension UnlockedAchievement {
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "achievementId": achievementId,
            "unlockedAt": unlockedAt
        ]
        
        if let gameId = gameId {
            data["gameId"] = gameId
        }
        
        return data
    }
}

extension AchievementProgress {
    func toDictionary() -> [String: Any] {
        return [
            "achievementId": achievementId,
            "currentValue": currentValue,
            "targetValue": targetValue,
            "lastUpdated": lastUpdated
        ]
    }
}