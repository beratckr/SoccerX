import SwiftUI
import Combine

@MainActor
class TabBarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: Tab = .dashboard
    @Published var dashboardBadgeCount: Int = 0
    @Published var groupsBadgeCount: Int = 0
    
    // Navigation paths for each tab
    @Published var dashboardPath = NavigationPath()
    @Published var historyPath = NavigationPath()
    @Published var groupsPath = NavigationPath()
    @Published var profilePath = NavigationPath()
    
    // Deep linking
    let deepLinkPublisher = PassthroughSubject<DeepLinkDestination, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Listen for notification badge updates
        NotificationCenter.default.publisher(for: .notificationBadgeUpdated)
            .compactMap { $0.object as? [String: Int] }
            .sink { [weak self] badges in
                self?.updateBadges(badges)
            }
            .store(in: &cancellables)
        
        // Listen for deep link requests
        NotificationCenter.default.publisher(for: .deepLinkRequested)
            .compactMap { $0.object as? DeepLinkDestination }
            .sink { [weak self] destination in
                self?.deepLinkPublisher.send(destination)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func selectTab(_ tab: Tab) {
        selectedTab = tab
    }
    
    func handleDeepLink(_ destination: DeepLinkDestination) {
        // Switch to the appropriate tab
        selectedTab = destination.tab
        
        // Navigate to the specific destination within that tab
        switch destination.tab {
        case .dashboard:
            if let dashboardDestination = destination.destination as? DashboardNavigationDestination {
                dashboardPath.append(dashboardDestination)
            }
        case .history:
            if let historyDestination = destination.destination as? HistoryNavigationDestination {
                historyPath.append(historyDestination)
            }
        case .groups:
            if let groupsDestination = destination.destination as? GroupsNavigationDestination {
                groupsPath.append(groupsDestination)
            }
        case .profile:
            if let profileDestination = destination.destination as? ProfileNavigationDestination {
                profilePath.append(profileDestination)
            }
        }
    }
    
    func resetNavigationPath(for tab: Tab) {
        switch tab {
        case .dashboard:
            dashboardPath = NavigationPath()
        case .history:
            historyPath = NavigationPath()
        case .groups:
            groupsPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }
    
    func navigateTo(tab: Tab, destination: Any) {
        selectedTab = tab
        
        switch tab {
        case .dashboard:
            if let dest = destination as? DashboardNavigationDestination {
                dashboardPath.append(dest)
            }
        case .history:
            if let dest = destination as? HistoryNavigationDestination {
                historyPath.append(dest)
            }
        case .groups:
            if let dest = destination as? GroupsNavigationDestination {
                groupsPath.append(dest)
            }
        case .profile:
            if let dest = destination as? ProfileNavigationDestination {
                profilePath.append(dest)
            }
        }
    }
    
    // MARK: - Private Methods
    private func updateBadges(_ badges: [String: Int]) {
        dashboardBadgeCount = badges["dashboard"] ?? 0
        groupsBadgeCount = badges["groups"] ?? 0
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let notificationBadgeUpdated = Notification.Name("notificationBadgeUpdated")
    static let deepLinkRequested = Notification.Name("deepLinkRequested")
}

// MARK: - Tab Navigation Extensions
extension TabBarViewModel {
    /// Navigate to game tracking from anywhere in the app
    func startGameTracking() {
        navigateTo(tab: .dashboard, destination: DashboardNavigationDestination.gameTracking)
    }
    
    /// Navigate to specific game details
    func showGameDetails(gameId: String) {
        navigateTo(tab: .history, destination: HistoryNavigationDestination.gameDetail(gameId: gameId))
    }
    
    /// Navigate to group details
    func showGroupDetails(groupId: String) {
        navigateTo(tab: .groups, destination: GroupsNavigationDestination.groupDetail(groupId: groupId))
    }
    
    /// Navigate to subscription management
    func showSubscription() {
        navigateTo(tab: .profile, destination: ProfileNavigationDestination.subscription)
    }
}