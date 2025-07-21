import Foundation
import FirebaseFirestore
import Combine

class GameRepository: BaseRepository<Game> {
    
    init() {
        super.init(collectionPath: "games")
    }
    
    // MARK: - Game-specific operations
    
    func getUserGames(uid: String, limit: Int = 50) -> AnyPublisher<[Game], RepositoryError> {
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .order(by: "startTime", descending: true)
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func getUserGamesThisWeek(uid: String) -> AnyPublisher<[Game], RepositoryError> {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfWeek))
            .order(by: "startTime", descending: true)
        
        return fetch(query: query)
    }
    
    func getGroupGames(groupId: String, limit: Int = 50) -> AnyPublisher<[Game], RepositoryError> {
        let query = collection
            .whereField("groupIds", arrayContains: groupId)
            .order(by: "startTime", descending: true)
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func getUserBestGames(uid: String, limit: Int = 10) -> AnyPublisher<[Game], RepositoryError> {
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .whereField("mvpScore", isGreaterThan: 0)
            .order(by: "mvpScore", descending: true)
            .limit(to: limit)
        
        return fetch(query: query)
    }
    
    func getActiveGames(uid: String) -> AnyPublisher<[Game], RepositoryError> {
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .whereField("isCompleted", isEqualTo: false)
            .order(by: "startTime", descending: true)
        
        return fetch(query: query)
    }
    
    func observeActiveGame(uid: String) -> AnyPublisher<Game?, RepositoryError> {
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .whereField("isCompleted", isEqualTo: false)
            .order(by: "startTime", descending: true)
            .limit(to: 1)
        
        return observeCollection(query: query)
            .map { games in games.first }
            .eraseToAnyPublisher()
    }
    
    func completeGame(gameId: String, finalStats: GameCompletionStats) -> AnyPublisher<Game, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GameRepository", code: -1))))
                return
            }
            
            let updateData: [String: Any] = [
                "endTime": FieldValue.serverTimestamp(),
                "duration": finalStats.duration,
                "distance": finalStats.distance,
                "avgSpeed": finalStats.avgSpeed,
                "maxSpeed": finalStats.maxSpeed,
                "isCompleted": true
            ]
            
            self.collection.document(gameId).updateData(updateData) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                    return
                }
                
                // Fetch the updated game
                self.read(id: gameId)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { game in
                            if let game = game {
                                promise(.success(game))
                            } else {
                                promise(.failure(.documentNotFound))
                            }
                        }
                    )
                    .store(in: &self.cancellables)
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func addGameEvent(gameId: String, event: GameEvent) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GameRepository", code: -1))))
                return
            }
            
            self.collection.document(gameId).updateData([
                "events": FieldValue.arrayUnion([event.toDictionary()])
            ]) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func updateGameWithMVPScore(gameId: String, mvpScore: Double, scoreBreakdown: MVPScoreBreakdown) -> AnyPublisher<Void, RepositoryError> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(NSError(domain: "GameRepository", code: -1))))
                return
            }
            
            let updateData: [String: Any] = [
                "mvpScore": mvpScore,
                "scoreBreakdown": scoreBreakdown.toFirestore(),
                "processedAt": FieldValue.serverTimestamp()
            ]
            
            self.collection.document(gameId).updateData(updateData) { error in
                if let error = error {
                    promise(.failure(self.mapError(error)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func getGamesByDateRange(uid: String, startDate: Date, endDate: Date) -> AnyPublisher<[Game], RepositoryError> {
        let query = collection
            .whereField("userId", isEqualTo: uid)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "startTime", descending: true)
        
        return fetch(query: query)
    }
    
    func getGameStatistics(uid: String) -> AnyPublisher<GameStatistics, RepositoryError> {
        getUserGames(uid: uid, limit: 1000)
            .map { games in
                GameStatistics(from: games)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Helper Methods
    
    private func mapError(_ error: Error) -> RepositoryError {
        if let firestoreError = error as NSError? {
            switch firestoreError.code {
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.notFound.rawValue:
                return .documentNotFound
            case FirestoreErrorCode.unavailable.rawValue,
                 FirestoreErrorCode.deadlineExceeded.rawValue:
                return .networkError(error)
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
}

// MARK: - Supporting Types

struct GameCompletionStats {
    let duration: Int
    let distance: Double
    let avgSpeed: Double
    let maxSpeed: Double
}

struct GameStatistics {
    let totalGames: Int
    let totalDistance: Double
    let totalDuration: Int
    let averageMVPScore: Double
    let bestMVPScore: Double
    let averageDistance: Double
    let averageDuration: Int
    let gamesThisWeek: Int
    let gamesThisMonth: Int
    
    init(from games: [Game]) {
        totalGames = games.count
        totalDistance = games.reduce(0) { $0 + $1.distance }
        totalDuration = games.reduce(0) { $0 + $1.duration }
        
        let completedGames = games.filter { $0.mvpScore != nil }
        if completedGames.isEmpty {
            averageMVPScore = 0
            bestMVPScore = 0
        } else {
            let scores = completedGames.compactMap { $0.mvpScore }
            averageMVPScore = scores.reduce(0, +) / Double(scores.count)
            bestMVPScore = scores.max() ?? 0
        }
        
        averageDistance = totalGames > 0 ? totalDistance / Double(totalGames) : 0
        averageDuration = totalGames > 0 ? totalDuration / totalGames : 0
        
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        gamesThisWeek = games.filter { game in
            guard let startTime = game.startTime else { return false }
            return startTime.dateValue() >= startOfWeek
        }.count
        
        gamesThisMonth = games.filter { game in
            guard let startTime = game.startTime else { return false }
            return startTime.dateValue() >= startOfMonth
        }.count
    }
}