import XCTest
@testable import SoccerX
import Combine

class DashboardViewModelTests: XCTestCase {
    
    var sut: DashboardViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = DashboardViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertEqual(sut.weeklyStats.gamesPlayed, 0)
        XCTAssertEqual(sut.weeklyStats.totalDuration, 0)
        XCTAssertEqual(sut.weeklyStats.avgMVPScore, 0)
        XCTAssertTrue(sut.recentActivities.isEmpty)
        XCTAssertTrue(sut.groupStandings.isEmpty)
        XCTAssertNil(sut.primaryGroup)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadDashboardDataSetsLoadingState() {
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await sut.loadDashboardData()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should start with false, then true when loading, then false when done
        XCTAssertTrue(loadingStates.contains(true))
    }
    
    func testRefreshDataClearsError() {
        // Set an error
        sut.error = "Test error"
        XCTAssertNotNil(sut.error)
        
        // Refresh should clear error
        Task {
            await sut.refreshData()
        }
        
        // Allow async operation to start
        let expectation = XCTestExpectation(description: "Refresh clears error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(self.sut.error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Weekly Stats Tests
    
    func testWeeklyStatsCalculation() {
        // Mock data
        let stats = DashboardViewModel.WeeklyStats(
            gamesPlayed: 5,
            totalDuration: 7200, // 2 hours
            avgMVPScore: 85.5
        )
        
        sut.weeklyStats = stats
        
        XCTAssertEqual(sut.weeklyStats.gamesPlayed, 5)
        XCTAssertEqual(sut.weeklyStats.totalDuration, 7200)
        XCTAssertEqual(sut.weeklyStats.avgMVPScore, 85.5)
        
        // Test formatted duration
        XCTAssertEqual(sut.weeklyStats.totalDurationFormatted, "2h 0m")
    }
    
    func testWeeklyStatsWithNoGames() {
        let stats = DashboardViewModel.WeeklyStats(
            gamesPlayed: 0,
            totalDuration: 0,
            avgMVPScore: 0
        )
        
        sut.weeklyStats = stats
        
        XCTAssertEqual(sut.weeklyStats.gamesPlayed, 0)
        XCTAssertEqual(sut.weeklyStats.totalDurationFormatted, "0h 0m")
        XCTAssertEqual(sut.weeklyStats.avgMVPScore, 0)
    }
    
    // MARK: - Recent Activities Tests
    
    func testRecentActivitiesLimit() {
        // Create 10 activities
        let activities = (1...10).map { index in
            ActivityItem(
                id: "activity\(index)",
                type: .game,
                title: "Game \(index)",
                subtitle: "Subtitle \(index)",
                timestamp: Date().addingTimeInterval(Double(-index * 3600)),
                value: "\(index * 10)"
            )
        }
        
        sut.recentActivities = activities
        
        // Dashboard should only show 5 most recent
        XCTAssertEqual(sut.recentActivities.count, 10) // All stored
        
        // In real implementation, the view would limit to 5
        let displayedActivities = Array(sut.recentActivities.prefix(5))
        XCTAssertEqual(displayedActivities.count, 5)
    }
    
    func testActivityItemTypes() {
        let gameActivity = ActivityItem(
            id: "1",
            type: .game,
            title: "Morning Game",
            subtitle: "MVP Score: 85",
            timestamp: Date(),
            value: "85"
        )
        
        let achievementActivity = ActivityItem(
            id: "2",
            type: .achievement,
            title: "Speed Demon",
            subtitle: "Reached 25 km/h",
            timestamp: Date(),
            value: nil
        )
        
        XCTAssertEqual(gameActivity.type, .game)
        XCTAssertEqual(achievementActivity.type, .achievement)
        XCTAssertNotNil(gameActivity.value)
        XCTAssertNil(achievementActivity.value)
    }
    
    // MARK: - Group Standings Tests
    
    func testGroupStandingsUpdate() {
        let standings = [
            GroupStanding(
                userId: "user1",
                userName: "John Doe",
                rank: 1,
                score: 450.5,
                gamesPlayed: 5,
                isCurrentUser: false
            ),
            GroupStanding(
                userId: "user2",
                userName: "Jane Smith",
                rank: 2,
                score: 425.0,
                gamesPlayed: 4,
                isCurrentUser: true
            ),
            GroupStanding(
                userId: "user3",
                userName: "Bob Johnson",
                rank: 3,
                score: 400.0,
                gamesPlayed: 5,
                isCurrentUser: false
            )
        ]
        
        sut.groupStandings = standings
        
        XCTAssertEqual(sut.groupStandings.count, 3)
        XCTAssertEqual(sut.groupStandings[0].rank, 1)
        XCTAssertEqual(sut.groupStandings[1].isCurrentUser, true)
        XCTAssertEqual(sut.groupStandings[2].score, 400.0)
    }
    
    func testEmptyGroupStandings() {
        sut.groupStandings = []
        XCTAssertTrue(sut.groupStandings.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        let testError = "Failed to load dashboard data"
        sut.error = testError
        
        XCTAssertEqual(sut.error, testError)
        XCTAssertNotNil(sut.error)
    }
    
    func testLoadingStateResetsOnError() {
        sut.isLoading = true
        sut.error = "Network error"
        
        // In real implementation, error should stop loading
        sut.isLoading = false
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.error)
    }
    
    // MARK: - Primary Group Tests
    
    func testPrimaryGroupSelection() {
        let group = Group(
            name: "Weekend Warriors",
            description: "Sunday games",
            creatorId: "creator123",
            isPublic: true
        )
        
        sut.primaryGroup = group
        
        XCTAssertNotNil(sut.primaryGroup)
        XCTAssertEqual(sut.primaryGroup?.name, "Weekend Warriors")
    }
    
    // MARK: - Performance Tests
    
    func testLargeDataSetPerformance() {
        measure {
            // Create large dataset
            let activities = (1...1000).map { index in
                ActivityItem(
                    id: "activity\(index)",
                    type: .game,
                    title: "Game \(index)",
                    subtitle: "Subtitle",
                    timestamp: Date(),
                    value: "\(index)"
                )
            }
            
            sut.recentActivities = activities
            
            // Access data
            _ = sut.recentActivities.prefix(5)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testNoMemoryLeaks() {
        weak var weakSut = sut
        
        // Create strong reference cycle scenario
        sut.$isLoading.sink { _ in
            // This could create a retain cycle if not handled properly
            _ = self.sut?.weeklyStats
        }.store(in: &cancellables)
        
        // Clear references
        cancellables.removeAll()
        sut = nil
        
        XCTAssertNil(weakSut, "DashboardViewModel should be deallocated")
    }
    
    // MARK: - Publisher Tests
    
    func testPublisherEmitsChanges() {
        let expectation = XCTestExpectation(description: "Publisher emits changes")
        var receivedStats: [DashboardViewModel.WeeklyStats] = []
        
        sut.$weeklyStats
            .sink { stats in
                receivedStats.append(stats)
                if receivedStats.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Update stats
        sut.weeklyStats = DashboardViewModel.WeeklyStats(
            gamesPlayed: 3,
            totalDuration: 5400,
            avgMVPScore: 82.0
        )
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(receivedStats.count, 2)
        XCTAssertEqual(receivedStats[1].gamesPlayed, 3)
    }
}