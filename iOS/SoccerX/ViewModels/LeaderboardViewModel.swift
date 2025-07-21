import Foundation
import Combine
import FirebaseAuth

@MainActor
class LeaderboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentLeaderboard: Leaderboard?
    @Published var weeklyChallenge: WeeklyChallenge?
    @Published var previousRankings: [String: Int] = [:] // userId: previousRank
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Properties
    let groupId: String
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private let leaderboardManager = LeaderboardManager.shared
    private let groupRepository = GroupRepository()
    private var cancellables = Set<AnyCancellable>()
    private var currentWeekOffset = 0
    
    // MARK: - Initialization
    init(groupId: String) {
        self.groupId = groupId
        observeLeaderboardUpdates()
    }
    
    // MARK: - Public Methods
    func loadLeaderboard() async {
        isLoading = true
        errorMessage = ""
        
        do {
            // Load current week leaderboard
            let leaderboard = try await leaderboardManager.getLeaderboard(for: groupId).async()
            currentLeaderboard = leaderboard
            
            // Load previous week for rank changes
            if currentWeekOffset == 0 {
                await loadPreviousRankings()
            }
            
            // Load weekly challenge
            await loadWeeklyChallenge()
            
        } catch {
            errorMessage = "Failed to load leaderboard"
            showError = true
        }
        
        isLoading = false
    }
    
    func loadWeek(offset: Int) async {
        currentWeekOffset = offset
        isLoading = true
        
        let weekId = getWeekId(offset: offset)
        
        do {
            let leaderboard = try await leaderboardManager.getLeaderboard(for: groupId, weekId: weekId).async()
            currentLeaderboard = leaderboard
            
            // Clear previous rankings for historical weeks
            if offset != 0 {
                previousRankings = [:]
            }
        } catch {
            errorMessage = "Failed to load week data"
            showError = true
        }
        
        isLoading = false
    }
    
    func refreshLeaderboard() async {
        await loadLeaderboard()
    }
    
    // MARK: - Week Navigation
    func getWeekNumber(offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        return "\(weekOfYear)"
    }
    
    func getWeekDateRange(offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let start = formatter.string(from: weekInterval.start)
        let end = formatter.string(from: weekInterval.end.addingTimeInterval(-1)) // End of week is start of next week
        
        return "\(start) - \(end)"
    }
    
    // MARK: - Private Methods
    private func observeLeaderboardUpdates() {
        leaderboardManager.$currentLeaderboards
            .compactMap { $0[self.groupId] }
            .sink { [weak self] (leaderboard: Leaderboard) in
                if self?.currentWeekOffset == 0 {
                    self?.currentLeaderboard = leaderboard
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadPreviousRankings() async {
        let previousWeekId = getWeekId(offset: -1)
        
        do {
            let previousLeaderboard = try await leaderboardManager.getLeaderboard(
                for: groupId,
                weekId: previousWeekId
            ).async()
            
            // Create mapping of userId to previous rank
            previousRankings = Dictionary(
                uniqueKeysWithValues: previousLeaderboard.rankings.enumerated().map { index, entry in
                    (entry.userId, index + 1)
                }
            )
        } catch {
            // No previous week data, that's okay
            previousRankings = [:]
        }
    }
    
    private func loadWeeklyChallenge() async {
        do {
            let group = try await groupRepository.read(id: groupId).async()
            weeklyChallenge = group?.weeklyChallenge
            
            // If no challenge exists and it's current week, generate one
            if weeklyChallenge == nil && currentWeekOffset == 0 {
                let newChallenge = leaderboardManager.generateWeeklyChallenge(for: groupId)
                
                // Update group with new challenge
                _ = try await groupRepository.setWeeklyChallenge(
                    groupId: groupId,
                    challenge: newChallenge
                ).async()
                
                weeklyChallenge = newChallenge
            }
        } catch {
            print("Failed to load weekly challenge: \(error)")
        }
    }
    
    private func getWeekId(offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear!)-W\(String(format: "%02d", components.weekOfYear!))"
    }
}

// MARK: - Note: async() extension is defined in JoinGroupView.swift