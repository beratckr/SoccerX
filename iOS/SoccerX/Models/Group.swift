import Foundation
import FirebaseFirestore

struct Group: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    let creatorId: String
    var memberIds: [String]
    var pendingMemberIds: [String] = []
    var inviteCode: String
    var isPublic: Bool
    var isPremium: Bool = false
    var maxMembers: Int = 50
    var weeklyChallenge: WeeklyChallenge?
    var settings: GroupSettings
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    
    // Computed properties
    var isFull: Bool {
        memberIds.count >= maxMembers
    }
    
    var memberCount: Int {
        memberIds.count
    }
    
    // Initialize with defaults
    init(name: String, description: String?, creatorId: String) {
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.memberIds = [creatorId]
        self.inviteCode = Group.generateInviteCode()
        self.isPublic = false
        self.settings = GroupSettings()
    }
    
    // Generate unique invite code
    static func generateInviteCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

struct WeeklyChallenge: Codable {
    let id: String
    let type: ChallengeType
    let title: String
    let description: String
    let target: Double // Target value depends on type
    let startDate: Date
    let endDate: Date
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    enum ChallengeType: String, Codable {
        case totalDistance = "total_distance"
        case totalGames = "total_games"
        case avgMVPScore = "avg_mvp_score"
        case consistentPlayer = "consistent_player" // Play X days in a row
        case speedDemon = "speed_demon" // Achieve max speed
        case endurance = "endurance" // Single game duration
    }
}

struct GroupSettings: Codable {
    var autoApproveMembers: Bool = false
    var allowMemberInvites: Bool = true
    var shareGameDetails: Bool = true
    var notifyOnNewGames: Bool = true
    var showMemberLocations: Bool = false
    var minimumGamesPerWeek: Int = 0
    var kickInactiveDays: Int? // Auto-remove after X days of inactivity
}

// MARK: - Leaderboard Model
struct Leaderboard: Codable, Identifiable {
    @DocumentID var id: String? // Format: groupId_weekId
    let groupId: String
    let weekId: String // Format: "2024-W30"
    var rankings: [LeaderboardEntry]
    let startDate: Date
    let endDate: Date
    @ServerTimestamp var lastUpdated: Timestamp?
    
    // Computed properties
    var isCurrentWeek: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var weekDisplayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let userId: String
    var displayName: String
    var profileImageUrl: String?
    var totalDistance: Double
    var totalGames: Int
    var avgMVPScore: Double
    var bestMVPScore: Double
    var points: Double // Calculated based on group scoring system
    
    var id: String { userId }
    
    // Computed properties
    var totalDistanceFormatted: String {
        String(format: "%.1f km", totalDistance)
    }
    
    var avgMVPScoreFormatted: String {
        String(format: "%.0f", avgMVPScore)
    }
}

// MARK: - Group Member Model (for detailed member info)
struct GroupMember: Codable {
    let userId: String
    let displayName: String
    let profileImageUrl: String?
    let joinedAt: Date
    let role: MemberRole
    let stats: MemberStats
    
    enum MemberRole: String, Codable {
        case creator = "creator"
        case admin = "admin"
        case member = "member"
    }
}

struct MemberStats: Codable {
    let weeklyGames: Int
    let weeklyDistance: Double
    let weeklyMVPAverage: Double
    let allTimeGames: Int
    let allTimeDistance: Double
    let currentStreak: Int
}

// MARK: - Firestore Extensions
extension Group {
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "creatorId": creatorId,
            "memberIds": memberIds,
            "pendingMemberIds": pendingMemberIds,
            "inviteCode": inviteCode,
            "isPublic": isPublic,
            "isPremium": isPremium,
            "maxMembers": maxMembers,
            "settings": settings.toDictionary()
        ]
        
        if let description = description {
            data["description"] = description
        }
        
        if let weeklyChallenge = weeklyChallenge {
            data["weeklyChallenge"] = weeklyChallenge.toDictionary()
        }
        
        if createdAt == nil {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        return data
    }
}

extension WeeklyChallenge {
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "type": type.rawValue,
            "title": title,
            "description": description,
            "target": target,
            "startDate": startDate,
            "endDate": endDate
        ]
    }
}

extension GroupSettings {
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "autoApproveMembers": autoApproveMembers,
            "allowMemberInvites": allowMemberInvites,
            "shareGameDetails": shareGameDetails,
            "notifyOnNewGames": notifyOnNewGames,
            "showMemberLocations": showMemberLocations,
            "minimumGamesPerWeek": minimumGamesPerWeek
        ]
        
        if let kickInactiveDays = kickInactiveDays {
            data["kickInactiveDays"] = kickInactiveDays
        }
        
        return data
    }
}

extension Leaderboard {
    func toFirestore() -> [String: Any] {
        return [
            "groupId": groupId,
            "weekId": weekId,
            "rankings": rankings.map { $0.toDictionary() },
            "startDate": startDate,
            "endDate": endDate,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
    }
}

extension LeaderboardEntry {
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "displayName": displayName,
            "totalDistance": totalDistance,
            "totalGames": totalGames,
            "avgMVPScore": avgMVPScore,
            "bestMVPScore": bestMVPScore,
            "points": points
        ]
        
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        return data
    }
}