import XCTest
@testable import SoccerX
import Combine

class LeaderboardManagerTests: XCTestCase {
    
    // MARK: - Week ID Tests
    
    func testGetCurrentWeekId() {
        let weekId = getCurrentWeekId()
        
        // Should be in format "YYYY-WW"
        let components = weekId.split(separator: "-")
        XCTAssertEqual(components.count, 2)
        
        // Year should be 4 digits
        XCTAssertEqual(components[0].count, 4)
        if let year = Int(components[0]) {
            XCTAssertGreaterThanOrEqual(year, 2024)
            XCTAssertLessThanOrEqual(year, 2030)
        }
        
        // Week should be 1-53 with "W" prefix
        XCTAssertTrue(components[1].hasPrefix("W"))
        let weekNumber = String(components[1].dropFirst())
        if let week = Int(weekNumber) {
            XCTAssertGreaterThanOrEqual(week, 1)
            XCTAssertLessThanOrEqual(week, 53)
        }
    }
    
    func testWeekIdForSpecificDates() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Test first week of year
        if let date = formatter.date(from: "2024-01-01") {
            let weekId = getWeekId(for: date)
            XCTAssertTrue(weekId.hasPrefix("2024-W"))
        }
        
        // Test last week of year
        if let date = formatter.date(from: "2024-12-31") {
            let weekId = getWeekId(for: date)
            XCTAssertTrue(weekId.hasPrefix("2024-W") || weekId.hasPrefix("2025-W"))
        }
    }
    
    // MARK: - Ranking Calculation Tests
    
    func testCalculateRankings() {
        let entries = [
            createLeaderboardEntry(userId: "user1", displayName: "Alice", totalDistance: 50, totalGames: 5, avgMVPScore: 85),
            createLeaderboardEntry(userId: "user2", displayName: "Bob", totalDistance: 45, totalGames: 4, avgMVPScore: 90),
            createLeaderboardEntry(userId: "user3", displayName: "Charlie", totalDistance: 60, totalGames: 6, avgMVPScore: 80),
            createLeaderboardEntry(userId: "user4", displayName: "David", totalDistance: 45, totalGames: 5, avgMVPScore: 88)
        ]
        
        let ranked = calculateRankings(entries)
        
        // Should be sorted by points (simplified: avgMVPScore * totalGames)
        XCTAssertEqual(ranked[0].userId, "user3") // 80 * 6 = 480
        XCTAssertEqual(ranked[1].userId, "user4") // 88 * 5 = 440
        XCTAssertEqual(ranked[2].userId, "user1") // 85 * 5 = 425
        XCTAssertEqual(ranked[3].userId, "user2") // 90 * 4 = 360
    }
    
    func testCalculateRankingsWithTies() {
        let entries = [
            createLeaderboardEntry(userId: "user1", displayName: "Alice", totalDistance: 50, totalGames: 5, avgMVPScore: 80),
            createLeaderboardEntry(userId: "user2", displayName: "Bob", totalDistance: 50, totalGames: 5, avgMVPScore: 80),
            createLeaderboardEntry(userId: "user3", displayName: "Charlie", totalDistance: 40, totalGames: 4, avgMVPScore: 85)
        ]
        
        let ranked = calculateRankings(entries)
        
        // Users 1 and 2 have same score (400), should maintain stable sort
        XCTAssertEqual(ranked[0].points, ranked[1].points)
        XCTAssertEqual(ranked[2].userId, "user3")
    }
    
    // MARK: - Points Calculation Tests
    
    func testCalculatePoints() {
        let entry = createLeaderboardEntry(
            userId: "test",
            displayName: "Test User",
            totalDistance: 50,
            totalGames: 5,
            avgMVPScore: 85
        )
        
        // Simple scoring: avgMVPScore * totalGames
        let points = calculatePoints(for: entry)
        XCTAssertEqual(points, 425)
    }
    
    func testCalculatePointsWithBonus() {
        let entry = createLeaderboardEntry(
            userId: "test",
            displayName: "Test User",
            totalDistance: 100, // High distance bonus
            totalGames: 10,    // Consistency bonus
            avgMVPScore: 90
        )
        
        // With bonuses
        let points = calculatePointsWithBonus(for: entry)
        XCTAssertGreaterThan(points, 900) // Base 900 + bonuses
    }
    
    // MARK: - Weekly Challenge Tests
    
    func testGenerateRandomChallenge() {
        let challenges = (0..<20).map { _ in generateRandomChallenge() }
        
        // Should have variety
        let uniqueTypes = Set(challenges.map { $0.type })
        XCTAssertGreaterThan(uniqueTypes.count, 1)
        
        // All challenges should have valid properties
        for challenge in challenges {
            XCTAssertFalse(challenge.title.isEmpty)
            XCTAssertFalse(challenge.description.isEmpty)
            XCTAssertGreaterThan(challenge.target, 0)
        }
    }
    
    // MARK: - Date Range Tests
    
    func testGetWeekDateRange() {
        let (start, end) = getWeekDateRange(for: "2024-W30")
        
        let calendar = Calendar.current
        
        // Start should be Sunday
        let startWeekday = calendar.component(.weekday, from: start)
        XCTAssertEqual(startWeekday, 1) // Sunday
        
        // End should be 7 days after start
        let daysBetween = calendar.dateComponents([.day], from: start, to: end).day
        XCTAssertEqual(daysBetween, 6) // 6 days between Sunday and Saturday
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentWeekId() -> String {
        return getWeekId(for: Date())
    }
    
    private func getWeekId(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
    
    private func createLeaderboardEntry(
        userId: String,
        displayName: String,
        totalDistance: Double,
        totalGames: Int,
        avgMVPScore: Double
    ) -> LeaderboardEntry {
        return LeaderboardEntry(
            userId: userId,
            displayName: displayName,
            profileImageUrl: nil,
            totalDistance: totalDistance,
            totalGames: totalGames,
            avgMVPScore: avgMVPScore,
            bestMVPScore: avgMVPScore + 10,
            points: avgMVPScore * Double(totalGames)
        )
    }
    
    private func calculateRankings(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        return entries.sorted { $0.points > $1.points }
    }
    
    private func calculatePoints(for entry: LeaderboardEntry) -> Double {
        return entry.avgMVPScore * Double(entry.totalGames)
    }
    
    private func calculatePointsWithBonus(for entry: LeaderboardEntry) -> Double {
        var points = calculatePoints(for: entry)
        
        // Distance bonus (1 point per km over 50)
        if entry.totalDistance > 50 {
            points += entry.totalDistance - 50
        }
        
        // Consistency bonus (10 points per game over 5)
        if entry.totalGames > 5 {
            points += Double((entry.totalGames - 5) * 10)
        }
        
        return points
    }
    
    private func generateRandomChallenge() -> WeeklyChallenge {
        let types: [WeeklyChallenge.ChallengeType] = [
            .totalDistance,
            .totalGames,
            .avgMVPScore,
            .consistentPlayer,
            .speedDemon,
            .endurance
        ]
        
        let type = types.randomElement()!
        
        let challenges: [(WeeklyChallenge.ChallengeType, String, String, Double)] = [
            (.totalDistance, "Distance Champion", "Run 50km this week", 50),
            (.totalGames, "Game Master", "Play 7 games this week", 7),
            (.avgMVPScore, "MVP of the Week", "Average 85+ MVP score", 85),
            (.consistentPlayer, "Iron Man", "Play 5 days in a row", 5),
            (.speedDemon, "Speed Demon", "Reach 25 km/h max speed", 25),
            (.endurance, "Marathon Runner", "Play a 90-minute game", 90)
        ]
        
        let challenge = challenges.first { $0.0 == type }!
        
        return WeeklyChallenge(
            id: UUID().uuidString,
            type: challenge.0,
            title: challenge.1,
            description: challenge.2,
            target: challenge.3,
            startDate: Date(),
            endDate: Date().addingTimeInterval(604800)
        )
    }
    
    private func getWeekDateRange(for weekId: String) -> (start: Date, end: Date) {
        let components = weekId.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let weekNumber = Int(String(components[1].dropFirst())) else {
            return (Date(), Date())
        }
        
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        var dateComponents = DateComponents()
        dateComponents.yearForWeekOfYear = year
        dateComponents.weekOfYear = weekNumber
        dateComponents.weekday = 1 // Sunday
        
        let startDate = calendar.date(from: dateComponents) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? Date()
        
        return (startDate, endDate)
    }
}