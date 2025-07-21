import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentDate = Date()
    
    // Game Data
    @Published var recentGames: [Game] = []
    @Published var weeklyStats: WeeklyStats = WeeklyStats()
    
    // Group Data
    @Published var userGroups: [Group] = []
    @Published var leaderboardData: [DashboardLeaderboardEntry] = []
    
    // Quick Actions
    @Published var isStartingGame = false
    @Published var watchConnectionStatus: WatchConnectionStatus = .disconnected
    
    // MARK: - Dependencies
    private let gameRepository = GameRepository()
    private let groupRepository = GroupRepository()
    private let watchConnectivity = WatchConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupObservers()
        updateCurrentDate()
    }
    
    // MARK: - Public Methods
    func loadDashboardData(for user: User?) async {
        guard let user = user else { return }
        
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            // Load recent games
            group.addTask {
                await self.loadRecentGames(for: user.uid)
            }
            
            // Load weekly stats
            group.addTask {
                await self.loadWeeklyStats(for: user.uid)
            }
            
            // Load user groups
            group.addTask {
                await self.loadUserGroups(for: user.uid)
            }
        }
        
        isLoading = false
    }
    
    func startGame() async {
        guard !isStartingGame else { return }
        
        isStartingGame = true
        errorMessage = nil
        
        do {
            let gameId = UUID().uuidString
            try await watchConnectivity.startGame(gameId: gameId)
            print("Game started successfully with ID: \(gameId)")
            // TODO: Navigate to game tracking view
        } catch {
            errorMessage = "Failed to start game: \(error.localizedDescription)"
        }
        
        isStartingGame = false
    }
    
    func refreshData(for user: User?) async {
        await loadDashboardData(for: user)
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Update date every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentDate()
            }
            .store(in: &cancellables)
        
        // Watch connectivity status
        watchConnectivity.$isReachable
            .map { isReachable in
                isReachable ? WatchConnectionStatus.connected : WatchConnectionStatus.disconnected
            }
            .assign(to: \.watchConnectionStatus, on: self)
            .store(in: &cancellables)
    }
    
    private func updateCurrentDate() {
        currentDate = Date()
    }
    
    private func loadRecentGames(for uid: String) async {
        do {
            let games = try await withCheckedThrowingContinuation { continuation in
                gameRepository.getUserGames(uid: uid, limit: 5)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { games in
                            continuation.resume(returning: games)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            recentGames = games
        } catch {
            print("Failed to load recent games: \(error)")
            if errorMessage == nil {
                errorMessage = "Failed to load recent games"
            }
        }
    }
    
    private func loadWeeklyStats(for uid: String) async {
        // Calculate weekly stats from recent games directly
        weeklyStats = WeeklyStats(games: recentGames)
    }
    
    private func loadUserGroups(for uid: String) async {
        do {
            let groups = try await withCheckedThrowingContinuation { continuation in
                groupRepository.getUserGroups(uid: uid)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { groups in
                            continuation.resume(returning: groups)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            userGroups = groups
            
            // Load leaderboard for first group
            if let firstGroup = groups.first {
                await loadLeaderboard(for: firstGroup.id ?? "", uid: uid)
            }
        } catch {
            print("Failed to load user groups: \(error)")
            if errorMessage == nil {
                errorMessage = "Failed to load groups"
            }
        }
    }
    
    private func loadLeaderboard(for groupId: String, uid: String) async {
        // TODO: Implement leaderboard loading when backend is ready
        // For now, create mock data
        leaderboardData = [
            DashboardLeaderboardEntry(rank: 1, userId: "mock1", name: "Top Player", gamesPlayed: 5, totalDistance: 25.5, isCurrentUser: false),
            DashboardLeaderboardEntry(rank: 2, userId: uid, name: "You", gamesPlayed: weeklyStats.gamesPlayed, totalDistance: weeklyStats.totalDistance, isCurrentUser: true)
        ]
    }
}

// MARK: - Supporting Types
enum WatchConnectionStatus {
    case connected
    case disconnected
    case connecting
    
    var displayText: String {
        switch self {
        case .connected:
            return "Apple Watch Connected"
        case .disconnected:
            return "Connect Apple Watch"
        case .connecting:
            return "Connecting..."
        }
    }
    
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .disconnected:
            return .orange
        case .connecting:
            return .blue
        }
    }
}

struct WeeklyStats {
    let gamesPlayed: Int
    let totalDistance: Double
    let maxSpeed: Double
    let averageSpeed: Double
    let totalCalories: Int
    let totalDuration: Int
    
    init() {
        self.gamesPlayed = 0
        self.totalDistance = 0
        self.maxSpeed = 0
        self.averageSpeed = 0
        self.totalCalories = 0
        self.totalDuration = 0
    }
    
    init(games: [Game]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let thisWeekGames = games.filter { game in
            guard let startTime = game.startTime else { return false }
            return startTime.dateValue() >= startOfWeek
        }
        
        self.gamesPlayed = thisWeekGames.count
        self.totalDistance = thisWeekGames.reduce(0) { $0 + $1.distance }
        self.maxSpeed = thisWeekGames.map { $0.maxSpeed }.max() ?? 0
        self.averageSpeed = thisWeekGames.isEmpty ? 0 : thisWeekGames.reduce(0) { $0 + $1.avgSpeed } / Double(thisWeekGames.count)
        self.totalCalories = thisWeekGames.count * 300 // Rough estimate: 300 calories per game
        self.totalDuration = thisWeekGames.reduce(0) { $0 + $1.duration }
    }
}

struct DashboardLeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let userId: String
    let name: String
    let gamesPlayed: Int
    let totalDistance: Double
    let isCurrentUser: Bool
    
    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(.systemBrown)
        default: return .secondary
        }
    }
    
    var displayStats: String {
        return "\(gamesPlayed) games"
    }
    
    var displayDistance: String {
        return String(format: "%.1f km", totalDistance)
    }
}

// MARK: - Computed Properties Extension
extension DashboardViewModel {
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentDate)
    }
    
    var lastGame: Game? {
        return recentGames.first
    }
    
    var weeklyStatCards: [StatCardData] {
        return [
            StatCardData(
                title: "Games",
                value: "\(weeklyStats.gamesPlayed)",
                subtitle: "This week",
                icon: "soccerball",
                accentColor: .green
            ),
            StatCardData(
                title: "Distance",
                value: String(format: "%.1f km", weeklyStats.totalDistance),
                subtitle: "Total",
                icon: "location",
                accentColor: .blue
            ),
            StatCardData(
                title: "Max Speed",
                value: String(format: "%.1f", weeklyStats.maxSpeed),
                subtitle: "km/h",
                icon: "speedometer",
                accentColor: .orange
            ),
            StatCardData(
                title: "Calories",
                value: "\(weeklyStats.totalCalories)",
                subtitle: "Burned",
                icon: "flame",
                accentColor: .red
            )
        ]
    }
}