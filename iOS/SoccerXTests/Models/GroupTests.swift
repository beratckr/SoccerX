import XCTest
@testable import SoccerX
import FirebaseFirestore

class GroupTests: XCTestCase {
    
    var sut: Group!
    
    override func setUp() {
        super.setUp()
        sut = Group(
            name: "Weekend Warriors",
            description: "Sunday soccer group",
            creatorId: "creator123"
        )
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testGroupInitialization() {
        XCTAssertEqual(sut.name, "Weekend Warriors")
        XCTAssertEqual(sut.description, "Sunday soccer group")
        XCTAssertEqual(sut.creatorId, "creator123")
        XCTAssertEqual(sut.memberIds, ["creator123"])
        XCTAssertEqual(sut.pendingMemberIds.count, 0)
        XCTAssertNotNil(sut.inviteCode)
        XCTAssertEqual(sut.inviteCode.count, 6)
        XCTAssertFalse(sut.isPublic)
        XCTAssertFalse(sut.isPremium)
        XCTAssertEqual(sut.maxMembers, 50)
        XCTAssertNil(sut.weeklyChallenge)
        XCTAssertNotNil(sut.settings)
        XCTAssertNil(sut.createdAt)
        XCTAssertNil(sut.updatedAt)
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsFull() {
        sut.maxMembers = 3
        sut.memberIds = ["creator123", "member2"]
        XCTAssertFalse(sut.isFull)
        
        sut.memberIds.append("member3")
        XCTAssertTrue(sut.isFull)
    }
    
    func testMemberCount() {
        XCTAssertEqual(sut.memberCount, 1)
        
        sut.memberIds.append("member2")
        sut.memberIds.append("member3")
        XCTAssertEqual(sut.memberCount, 3)
    }
    
    // MARK: - Invite Code Tests
    
    func testInviteCodeGeneration() {
        let code = Group.generateInviteCode()
        
        // Should be 6 characters
        XCTAssertEqual(code.count, 6)
        
        // Should only contain allowed characters (no confusing ones)
        let allowedCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        for char in code {
            XCTAssertTrue(allowedCharacters.contains(char))
        }
        
        // Should not contain confusing characters
        XCTAssertFalse(code.contains("0"))
        XCTAssertFalse(code.contains("O"))
        XCTAssertFalse(code.contains("I"))
        XCTAssertFalse(code.contains("1"))
    }
    
    func testInviteCodeUniqueness() {
        let codes = Set((0..<100).map { _ in Group.generateInviteCode() })
        
        // All codes should be unique (with high probability)
        XCTAssertGreaterThan(codes.count, 95) // Allow for small chance of collision
    }
    
    // MARK: - Member Management Tests
    
    func testAddMember() {
        sut.memberIds.append("member456")
        XCTAssertEqual(sut.memberIds.count, 2)
        XCTAssertTrue(sut.memberIds.contains("member456"))
    }
    
    func testRemoveMember() {
        sut.memberIds = ["creator123", "member456", "member789"]
        sut.memberIds.removeAll { $0 == "member456" }
        XCTAssertEqual(sut.memberIds.count, 2)
        XCTAssertFalse(sut.memberIds.contains("member456"))
    }
    
    func testPendingMembers() {
        sut.pendingMemberIds = ["pending1", "pending2"]
        XCTAssertEqual(sut.pendingMemberIds.count, 2)
    }
    
    // MARK: - Group Settings Tests
    
    func testDefaultSettings() {
        XCTAssertFalse(sut.settings.autoApproveMembers)
        XCTAssertTrue(sut.settings.allowMemberInvites)
        XCTAssertTrue(sut.settings.shareGameDetails)
        XCTAssertTrue(sut.settings.notifyOnNewGames)
        XCTAssertFalse(sut.settings.showMemberLocations)
        XCTAssertEqual(sut.settings.minimumGamesPerWeek, 0)
        XCTAssertNil(sut.settings.kickInactiveDays)
    }
    
    func testCustomSettings() {
        sut.settings.autoApproveMembers = true
        sut.settings.minimumGamesPerWeek = 3
        sut.settings.kickInactiveDays = 30
        
        XCTAssertTrue(sut.settings.autoApproveMembers)
        XCTAssertEqual(sut.settings.minimumGamesPerWeek, 3)
        XCTAssertEqual(sut.settings.kickInactiveDays, 30)
    }
    
    // MARK: - Weekly Challenge Tests
    
    func testWeeklyChallengeAssignment() {
        let challenge = WeeklyChallenge(
            id: "challenge123",
            type: .totalDistance,
            title: "Distance Champion",
            description: "Run the most distance this week",
            target: 50.0, // 50km target
            startDate: Date(),
            endDate: Date().addingTimeInterval(604800) // 7 days
        )
        
        sut.weeklyChallenge = challenge
        
        XCTAssertNotNil(sut.weeklyChallenge)
        XCTAssertEqual(sut.weeklyChallenge?.title, "Distance Champion")
        XCTAssertEqual(sut.weeklyChallenge?.type, .totalDistance)
        XCTAssertTrue(sut.weeklyChallenge?.isActive ?? false)
    }
    
    func testWeeklyChallengeTypes() {
        let challengeTypes: [WeeklyChallenge.ChallengeType] = [
            .totalDistance,
            .totalGames,
            .avgMVPScore,
            .consistentPlayer,
            .speedDemon,
            .endurance
        ]
        
        for type in challengeTypes {
            let challenge = WeeklyChallenge(
                id: "test",
                type: type,
                title: "Test",
                description: "Test",
                target: 10,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400)
            )
            XCTAssertNotNil(challenge)
        }
    }
    
    func testWeeklyChallengeIsActive() {
        // Active challenge
        let activeChallenge = WeeklyChallenge(
            id: "active",
            type: .totalGames,
            title: "Play More",
            description: "Play 5 games",
            target: 5,
            startDate: Date().addingTimeInterval(-86400), // Started yesterday
            endDate: Date().addingTimeInterval(86400) // Ends tomorrow
        )
        XCTAssertTrue(activeChallenge.isActive)
        
        // Expired challenge
        let expiredChallenge = WeeklyChallenge(
            id: "expired",
            type: .totalGames,
            title: "Old Challenge",
            description: "Expired",
            target: 5,
            startDate: Date().addingTimeInterval(-604800), // 7 days ago
            endDate: Date().addingTimeInterval(-86400) // Ended yesterday
        )
        XCTAssertFalse(expiredChallenge.isActive)
    }
    
    // MARK: - Premium Features Tests
    
    func testPremiumGroupFeatures() {
        sut.isPremium = true
        sut.maxMembers = 100 // Premium groups can have more members
        
        XCTAssertTrue(sut.isPremium)
        XCTAssertEqual(sut.maxMembers, 100)
    }
    
    // MARK: - Firestore Conversion Tests
    
    func testToFirestoreWithCompleteData() {
        sut.description = "Sunday soccer group"
        sut.isPublic = true
        sut.pendingMemberIds = ["pending1", "pending2"]
        sut.isPremium = true
        sut.maxMembers = 100
        
        let firestoreData = sut.toFirestore()
        
        XCTAssertEqual(firestoreData["name"] as? String, "Weekend Warriors")
        XCTAssertEqual(firestoreData["description"] as? String, "Sunday soccer group")
        XCTAssertEqual(firestoreData["creatorId"] as? String, "creator123")
        XCTAssertEqual(firestoreData["memberIds"] as? [String], ["creator123"])
        XCTAssertEqual(firestoreData["pendingMemberIds"] as? [String], ["pending1", "pending2"])
        XCTAssertNotNil(firestoreData["inviteCode"] as? String)
        XCTAssertEqual(firestoreData["isPublic"] as? Bool, true)
        XCTAssertEqual(firestoreData["isPremium"] as? Bool, true)
        XCTAssertEqual(firestoreData["maxMembers"] as? Int, 100)
        XCTAssertNotNil(firestoreData["settings"])
        XCTAssertNotNil(firestoreData["updatedAt"])
    }
    
    func testToFirestoreWithoutOptionalFields() {
        sut.description = nil
        sut.weeklyChallenge = nil
        
        let firestoreData = sut.toFirestore()
        
        XCTAssertNil(firestoreData["description"])
        XCTAssertNil(firestoreData["weeklyChallenge"])
        XCTAssertNotNil(firestoreData["settings"])
    }
    
    // MARK: - Edge Cases
    
    func testGroupWithEmptyName() {
        let group = Group(name: "", description: "Test", creatorId: "123")
        XCTAssertEqual(group.name, "")
    }
    
    func testGroupWithVeryLongDescription() {
        let longDescription = String(repeating: "A", count: 500)
        sut.description = longDescription
        XCTAssertEqual(sut.description?.count, 500)
    }
    
    func testGroupWithManyMembers() {
        sut.memberIds = (1...100).map { "member\($0)" }
        XCTAssertEqual(sut.memberIds.count, 100)
        
        sut.maxMembers = 50
        XCTAssertTrue(sut.isFull)
    }
    
    // MARK: - Business Logic Tests
    
    func testCreatorIsAlwaysMember() {
        XCTAssertTrue(sut.memberIds.contains(sut.creatorId))
    }
    
    func testGroupInitializedWithInviteCode() {
        XCTAssertNotNil(sut.inviteCode)
        XCTAssertFalse(sut.inviteCode.isEmpty)
    }
}

// MARK: - Leaderboard Tests

class LeaderboardTests: XCTestCase {
    
    var sut: Leaderboard!
    
    override func setUp() {
        super.setUp()
        sut = Leaderboard(
            groupId: "group123",
            weekId: "2024-W30",
            rankings: [],
            startDate: Date(),
            endDate: Date().addingTimeInterval(604800)
        )
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testLeaderboardInitialization() {
        XCTAssertEqual(sut.groupId, "group123")
        XCTAssertEqual(sut.weekId, "2024-W30")
        XCTAssertEqual(sut.rankings.count, 0)
        XCTAssertNotNil(sut.startDate)
        XCTAssertNotNil(sut.endDate)
    }
    
    func testIsCurrentWeek() {
        // Current week
        sut.startDate = Date().addingTimeInterval(-86400) // Started yesterday
        sut.endDate = Date().addingTimeInterval(86400) // Ends tomorrow
        XCTAssertTrue(sut.isCurrentWeek)
        
        // Past week
        sut.startDate = Date().addingTimeInterval(-604800) // 7 days ago
        sut.endDate = Date().addingTimeInterval(-86400) // Ended yesterday
        XCTAssertFalse(sut.isCurrentWeek)
    }
    
    func testWeekDisplayName() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        sut.startDate = formatter.date(from: "2024-07-15")!
        sut.endDate = formatter.date(from: "2024-07-21")!
        
        let displayName = sut.weekDisplayName
        XCTAssertTrue(displayName.contains("Jul"))
        XCTAssertTrue(displayName.contains("15"))
        XCTAssertTrue(displayName.contains("21"))
    }
    
    func testLeaderboardEntry() {
        let entry = LeaderboardEntry(
            userId: "user123",
            displayName: "John Doe",
            profileImageUrl: "https://example.com/profile.jpg",
            totalDistance: 45.5,
            totalGames: 5,
            avgMVPScore: 87.3,
            bestMVPScore: 95.0,
            points: 435.5
        )
        
        XCTAssertEqual(entry.id, "user123")
        XCTAssertEqual(entry.totalDistanceFormatted, "45.5 km")
        XCTAssertEqual(entry.avgMVPScoreFormatted, "87")
    }
}