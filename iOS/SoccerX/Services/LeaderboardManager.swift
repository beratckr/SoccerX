import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var currentLeaderboards: [String: Leaderboard] = [:] // groupId: Leaderboard
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private init() {
        observeUserGroupLeaderboards()
    }
    
    // MARK: - Leaderboard Operations
    
    func getLeaderboard(for groupId: String, weekId: String? = nil) -> AnyPublisher<Leaderboard, Error> {
        let targetWeekId = weekId ?? getCurrentWeekId()
        let leaderboardId = "\(groupId)_\(targetWeekId)"
        
        return Future<Leaderboard, Error> { promise in
            self.db.collection("leaderboards")
                .document(leaderboardId)
                .getDocument { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let leaderboard = try? snapshot?.data(as: Leaderboard.self) else {
                        // Create empty leaderboard if doesn't exist
                        var emptyLeaderboard = Leaderboard(
                            groupId: groupId,
                            weekId: targetWeekId,
                            rankings: [],
                            startDate: self.getWeekStartDate(),
                            endDate: self.getWeekEndDate()
                        )
                        emptyLeaderboard.id = leaderboardId
                        promise(.success(emptyLeaderboard))
                        return
                    }
                    
                    promise(.success(leaderboard))
                }
        }
        .eraseToAnyPublisher()
    }
    
    func updateUserScore(userId: String, groupId: String, gameData: GameLeaderboardData) -> AnyPublisher<Void, Error> {
        let weekId = getCurrentWeekId()
        let leaderboardId = "\(groupId)_\(weekId)"
        
        return Future<Void, Error> { promise in
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let leaderboardRef = self.db.collection("leaderboards").document(leaderboardId)
                
                do {
                    let snapshot = try transaction.getDocument(leaderboardRef)
                    
                    var leaderboard: Leaderboard
                    
                    if snapshot.exists,
                       let existingLeaderboard = try? snapshot.data(as: Leaderboard.self) {
                        leaderboard = existingLeaderboard
                    } else {
                        // Create new leaderboard
                        leaderboard = Leaderboard(
                            groupId: groupId,
                            weekId: weekId,
                            rankings: [],
                            startDate: self.getWeekStartDate(),
                            endDate: self.getWeekEndDate()
                        )
                        leaderboard.id = leaderboardId
                    }
                    
                    // Update or add user entry
                    if let index = leaderboard.rankings.firstIndex(where: { $0.userId == userId }) {
                        // Update existing entry
                        var entry = leaderboard.rankings[index]
                        entry.totalDistance += gameData.distance
                        entry.totalGames += 1
                        let totalMVP = entry.avgMVPScore * Double(entry.totalGames - 1) + gameData.mvpScore
                        entry.avgMVPScore = totalMVP / Double(entry.totalGames)
                        entry.bestMVPScore = max(entry.bestMVPScore, gameData.mvpScore)
                        entry.points = entry.totalDistance * 10 + entry.avgMVPScore // Simple point calculation
                        leaderboard.rankings[index] = entry
                    } else {
                        // Get user display name (would need to fetch from users collection in real implementation)
                        let displayName = "User" // Placeholder
                        
                        // Add new entry
                        let newEntry = LeaderboardEntry(
                            userId: userId,
                            displayName: displayName,
                            profileImageUrl: nil,
                            totalDistance: gameData.distance,
                            totalGames: 1,
                            avgMVPScore: gameData.mvpScore,
                            bestMVPScore: gameData.mvpScore,
                            points: gameData.distance * 10 + gameData.mvpScore
                        )
                        leaderboard.rankings.append(newEntry)
                    }
                    
                    // Sort by points (descending)
                    leaderboard.rankings.sort { $0.points > $1.points }
                    
                    // Save updated leaderboard using Codable
                    try transaction.setData(from: leaderboard, forDocument: leaderboardRef)
                    
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { (result, error) in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Weekly Challenge Management
    
    func generateWeeklyChallenge(for groupId: String) -> WeeklyChallenge {
        let challenges = [
            WeeklyChallenge(
                id: UUID().uuidString,
                type: .totalDistance,
                title: "Distance Champion",
                description: "Cover the most distance this week",
                target: 50.0, // 50km target
                startDate: getWeekStartDate(),
                endDate: getWeekEndDate()
            ),
            WeeklyChallenge(
                id: UUID().uuidString,
                type: .avgMVPScore,
                title: "MVP Master",
                description: "Achieve the highest average MVP score",
                target: 80.0, // 80 MVP score target
                startDate: getWeekStartDate(),
                endDate: getWeekEndDate()
            ),
            WeeklyChallenge(
                id: UUID().uuidString,
                type: .totalGames,
                title: "Consistency King",
                description: "Play the most games this week",
                target: 5.0, // 5 games target
                startDate: getWeekStartDate(),
                endDate: getWeekEndDate()
            ),
            WeeklyChallenge(
                id: UUID().uuidString,
                type: .speedDemon,
                title: "Speed Demon",
                description: "Achieve the highest max speed in a game",
                target: 25.0, // 25 km/h target
                startDate: getWeekStartDate(),
                endDate: getWeekEndDate()
            )
        ]
        
        return challenges.randomElement()!
    }
    
    // MARK: - Ranking Analysis
    
    func checkRankChanges(groupId: String, userId: String) -> AnyPublisher<RankChangeInfo?, Error> {
        let currentWeek = getCurrentWeekId()
        let previousWeek = getPreviousWeekId()
        
        let currentLeaderboard = getLeaderboard(for: groupId, weekId: currentWeek)
        let previousLeaderboard = getLeaderboard(for: groupId, weekId: previousWeek)
        
        return Publishers.Zip(currentLeaderboard, previousLeaderboard)
            .map { current, previous in
                // Find rank by position in sorted array (1-indexed)
                let currentRank = current.rankings.firstIndex(where: { $0.userId == userId }).map { $0 + 1 }
                let previousRank = previous.rankings.firstIndex(where: { $0.userId == userId }).map { $0 + 1 }
                
                guard let currentR = currentRank, let previousR = previousRank else {
                    return nil
                }
                
                let change = previousR - currentR
                
                if change != 0 {
                    return RankChangeInfo(
                        previousRank: previousR,
                        currentRank: currentR,
                        change: change,
                        groupId: groupId
                    )
                }
                
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Historical Data
    
    func getHistoricalLeaderboards(for groupId: String, weeks: Int = 4) -> AnyPublisher<[Leaderboard], Error> {
        let weekIds = getPastWeekIds(count: weeks)
        
        let publishers = weekIds.map { weekId in
            getLeaderboard(for: groupId, weekId: weekId)
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { leaderboards in
                leaderboards.sorted { $0.weekId > $1.weekId }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func observeUserGroupLeaderboards() {
        guard Auth.auth().currentUser != nil else { return }
        
        GroupManager.shared.$userGroups
            .sink { [weak self] groups in
                self?.observeLeaderboards(for: groups)
            }
            .store(in: &cancellables)
    }
    
    private func observeLeaderboards(for groups: [Group]) {
        let weekId = getCurrentWeekId()
        
        for group in groups {
            guard let groupId = group.id else { continue }
            let leaderboardId = "\(groupId)_\(weekId)"
            
            db.collection("leaderboards")
                .document(leaderboardId)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error = error {
                        self?.error = error
                        return
                    }
                    
                    guard let leaderboard = try? snapshot?.data(as: Leaderboard.self) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.currentLeaderboards[groupId] = leaderboard
                    }
                }
        }
    }
    
    // MARK: - Date Helpers
    
    private func getCurrentWeekId() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(components.yearForWeekOfYear!)-W\(String(format: "%02d", components.weekOfYear!))"
    }
    
    private func getPreviousWeekId() -> String {
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek)
        return "\(components.yearForWeekOfYear!)-W\(String(format: "%02d", components.weekOfYear!))"
    }
    
    private func getPastWeekIds(count: Int) -> [String] {
        let calendar = Calendar.current
        
        return (0..<count).map { weekOffset in
            let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return "\(components.yearForWeekOfYear!)-W\(String(format: "%02d", components.weekOfYear!))"
        }
    }
    
    private func getWeekStartDate() -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }
    
    private func getWeekEndDate() -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
    }
}

// MARK: - Supporting Types
// Note: Using Leaderboard and LeaderboardEntry from Models/Group.swift to avoid duplicate definitions

struct GameLeaderboardData {
    let distance: Double
    let duration: Int
    let mvpScore: Double
}

struct RankChangeInfo {
    let previousRank: Int
    let currentRank: Int
    let change: Int // Positive = improved, Negative = dropped
    let groupId: String
}