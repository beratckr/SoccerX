import XCTest
@testable import SoccerX
import FirebaseFirestore

class UserTests: XCTestCase {
    
    var sut: User!
    
    override func setUp() {
        super.setUp()
        sut = User(uid: "test123", email: "test@example.com", displayName: "Test User")
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testUserInitialization() {
        XCTAssertEqual(sut.uid, "test123")
        XCTAssertEqual(sut.email, "test@example.com")
        XCTAssertEqual(sut.displayName, "Test User")
        XCTAssertNil(sut.profileImageUrl)
        XCTAssertNil(sut.fcmToken)
        XCTAssertEqual(sut.stats.totalGames, 0)
        XCTAssertEqual(sut.achievements.count, 0)
        XCTAssertEqual(sut.groupIds.count, 0)
        XCTAssertFalse(sut.isPremium)
    }
    
    // MARK: - Computed Properties Tests
    
    func testInitialsWithFullName() {
        sut.displayName = "John Doe"
        XCTAssertEqual(sut.initials, "JD")
    }
    
    func testInitialsWithSingleName() {
        sut.displayName = "John"
        XCTAssertEqual(sut.initials, "JO")
    }
    
    func testInitialsWithEmptyName() {
        sut.displayName = ""
        XCTAssertEqual(sut.initials, "")
    }
    
    // MARK: - Firestore Conversion Tests
    
    func testToFirestoreWithAllFields() {
        sut.profileImageUrl = "https://example.com/image.jpg"
        sut.fcmToken = "fcm_token_123"
        sut.achievements = ["achievement1", "achievement2"]
        sut.groupIds = ["group1", "group2"]
        sut.isPremium = true
        
        let firestoreData = sut.toFirestore()
        
        XCTAssertEqual(firestoreData["uid"] as? String, "test123")
        XCTAssertEqual(firestoreData["email"] as? String, "test@example.com")
        XCTAssertEqual(firestoreData["displayName"] as? String, "Test User")
        XCTAssertEqual(firestoreData["profileImageUrl"] as? String, "https://example.com/image.jpg")
        XCTAssertEqual(firestoreData["fcmToken"] as? String, "fcm_token_123")
        XCTAssertEqual(firestoreData["achievements"] as? [String], ["achievement1", "achievement2"])
        XCTAssertEqual(firestoreData["groupIds"] as? [String], ["group1", "group2"])
        XCTAssertEqual(firestoreData["isPremium"] as? Bool, true)
        XCTAssertNotNil(firestoreData["stats"])
        XCTAssertNotNil(firestoreData["updatedAt"])
    }
    
    func testToFirestoreWithoutOptionalFields() {
        let firestoreData = sut.toFirestore()
        
        XCTAssertNil(firestoreData["profileImageUrl"])
        XCTAssertNil(firestoreData["fcmToken"])
    }
    
    // MARK: - UserStats Tests
    
    func testUserStatsFormatting() {
        var stats = UserStats()
        stats.totalDistance = 15.567
        stats.totalDuration = 7890 // 2h 11m 30s
        stats.averageMVPScore = 87.654
        
        XCTAssertEqual(stats.totalDistanceFormatted, "15.6 km")
        XCTAssertEqual(stats.totalDurationFormatted, "2h 11m")
        XCTAssertEqual(stats.averageMVPScoreFormatted, "88")
    }
    
    func testUserStatsToDictionary() {
        var stats = UserStats()
        stats.totalGames = 10
        stats.totalDistance = 45.5
        stats.favoritePlayTime = "evening"
        
        let dict = stats.toDictionary()
        
        XCTAssertEqual(dict["totalGames"] as? Int, 10)
        XCTAssertEqual(dict["totalDistance"] as? Double, 45.5)
        XCTAssertEqual(dict["favoritePlayTime"] as? String, "evening")
    }
    
    // MARK: - Edge Cases
    
    func testUserWithSpecialCharactersInName() {
        sut.displayName = "José María Ñoño"
        let firestoreData = sut.toFirestore()
        XCTAssertEqual(firestoreData["displayName"] as? String, "José María Ñoño")
    }
    
    func testUserWithLongEmail() {
        sut.email = "verylongemailaddressthatexceedsnormalexpectations@extremelylongdomainname.com"
        let firestoreData = sut.toFirestore()
        XCTAssertEqual(firestoreData["email"] as? String, sut.email)
    }
    
    // MARK: - Equatable Tests
    
    func testUsersAreEqual() {
        let user1 = User(uid: "123", email: "test@test.com", displayName: "Test")
        let user2 = User(uid: "123", email: "test@test.com", displayName: "Test")
        XCTAssertEqual(user1, user2)
    }
    
    func testUsersAreNotEqualWithDifferentUID() {
        let user1 = User(uid: "123", email: "test@test.com", displayName: "Test")
        let user2 = User(uid: "456", email: "test@test.com", displayName: "Test")
        XCTAssertNotEqual(user1, user2)
    }
}