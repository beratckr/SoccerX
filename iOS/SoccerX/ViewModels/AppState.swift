import Foundation
import Combine
import FirebaseAuth

class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: Tab = .dashboard
    @Published var notificationBadges: NotificationBadges = NotificationBadges()
    @Published var activeGameId: String?
    @Published var isTrackingGame = false
    @Published var hasActiveSubscription = false
    @Published var isOnboarding = false
    
    // MARK: - Services
    private let authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auth state binding
        authService.$currentUser
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
        
        // Listen for auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user == nil {
                self?.reset()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func setActiveGame(_ gameId: String?) {
        activeGameId = gameId
        isTrackingGame = gameId != nil
    }
    
    func updateBadge(for tab: Tab, count: Int) {
        switch tab {
        case .dashboard:
            notificationBadges.dashboard = count
        case .history:
            notificationBadges.history = count
        case .groups:
            notificationBadges.groups = count
        case .profile:
            notificationBadges.profile = count
        }
    }
    
    func clearBadge(for tab: Tab) {
        updateBadge(for: tab, count: 0)
    }
    
    func clearAllBadges() {
        notificationBadges = NotificationBadges()
    }
    
    func navigateToTab(_ tab: Tab) {
        selectedTab = tab
    }
    
    func reset() {
        currentUser = nil
        isAuthenticated = false
        selectedTab = .dashboard
        notificationBadges = NotificationBadges()
        activeGameId = nil
        isTrackingGame = false
        hasActiveSubscription = false
    }
}

// MARK: - Supporting Types

struct NotificationBadges {
    var dashboard: Int = 0
    var history: Int = 0
    var groups: Int = 0
    var profile: Int = 0
    
    var total: Int {
        dashboard + history + groups + profile
    }
}

// MARK: - Deep Linking

extension AppState {
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        switch components.host {
        case "group":
            if let groupId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigateToGroup(groupId)
            }
        case "game":
            if let gameId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigateToGame(gameId)
            }
        case "leaderboard":
            if let groupId = components.queryItems?.first(where: { $0.name == "groupId" })?.value {
                navigateToLeaderboard(groupId)
            }
        case "subscription":
            navigateToSubscription()
        default:
            break
        }
    }
    
    private func navigateToGroup(_ groupId: String) {
        selectedTab = .groups
        // Post notification for Groups tab to handle navigation
        NotificationCenter.default.post(
            name: .navigateToGroup,
            object: nil,
            userInfo: ["groupId": groupId]
        )
    }
    
    private func navigateToGame(_ gameId: String) {
        selectedTab = .history
        // Post notification for History tab to handle navigation
        NotificationCenter.default.post(
            name: .navigateToGame,
            object: nil,
            userInfo: ["gameId": gameId]
        )
    }
    
    private func navigateToLeaderboard(_ groupId: String) {
        selectedTab = .groups
        // Post notification for Groups tab to handle navigation
        NotificationCenter.default.post(
            name: .navigateToLeaderboard,
            object: nil,
            userInfo: ["groupId": groupId]
        )
    }
    
    private func navigateToSubscription() {
        selectedTab = .profile
        // Post notification for Profile tab to handle navigation
        NotificationCenter.default.post(
            name: .navigateToSubscription,
            object: nil
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToGroup = Notification.Name("navigateToGroup")
    static let navigateToGame = Notification.Name("navigateToGame")
    static let navigateToLeaderboard = Notification.Name("navigateToLeaderboard")
    static let navigateToSubscription = Notification.Name("navigateToSubscription")
}