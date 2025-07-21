import SwiftUI

struct MainTabView: View {
    @StateObject private var tabViewModel = TabBarViewModel()
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        TabView(selection: $tabViewModel.selectedTab) {
            // Dashboard Tab
            NavigationStack(path: $tabViewModel.dashboardPath) {
                DashboardView()
                    .environmentObject(authService)
                    .navigationDestination(for: DashboardNavigationDestination.self) { destination in
                        destination.view()
                    }
            }
            .tabItem {
                Image(systemName: tabViewModel.selectedTab == .dashboard ? "house.fill" : "house")
                Text("Dashboard")
            }
            .tag(Tab.dashboard)
            .badge(tabViewModel.dashboardBadgeCount)
            
            // History Tab
            NavigationStack(path: $tabViewModel.historyPath) {
                HistoryView()
                    .navigationDestination(for: HistoryNavigationDestination.self) { destination in
                        destination.view()
                    }
            }
            .tabItem {
                Image(systemName: tabViewModel.selectedTab == .history ? "clock.fill" : "clock")
                Text("History")
            }
            .tag(Tab.history)
            
            // Groups Tab
            NavigationStack(path: $tabViewModel.groupsPath) {
                GroupsView()
                    .navigationDestination(for: GroupsNavigationDestination.self) { destination in
                        destination.view()
                    }
            }
            .tabItem {
                Image(systemName: tabViewModel.selectedTab == .groups ? "person.3.fill" : "person.3")
                Text("Groups")
            }
            .tag(Tab.groups)
            .badge(tabViewModel.groupsBadgeCount)
            
            // Profile Tab
            NavigationStack(path: $tabViewModel.profilePath) {
                ProfileView()
                    .environmentObject(authService)
                    .navigationDestination(for: ProfileNavigationDestination.self) { destination in
                        destination.view()
                    }
            }
            .tabItem {
                Image(systemName: tabViewModel.selectedTab == .profile ? "person.circle.fill" : "person.circle")
                Text("Profile")
            }
            .tag(Tab.profile)
        }
        .accentColor(.green)
        .preferredColorScheme(.dark)
        .onReceive(tabViewModel.deepLinkPublisher) { destination in
            tabViewModel.handleDeepLink(destination)
        }
    }
}

// MARK: - Tab Enum
enum Tab: String, CaseIterable {
    case dashboard
    case history
    case groups
    case profile
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .history: return "History"
        case .groups: return "Groups"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .history: return "clock"
        case .groups: return "person.3"
        case .profile: return "person.circle"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .history: return "clock.fill"
        case .groups: return "person.3.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

// MARK: - Navigation Destinations
enum DashboardNavigationDestination: Hashable {
    case gameTracking
    case gameDetail(gameId: String)
    case settings
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .gameTracking:
            Text("Game Tracking View")
                .navigationTitle("Track Game")
        case .gameDetail(let gameId):
            Text("Game Detail: \(gameId)")
                .navigationTitle("Game Details")
        case .settings:
            Text("Settings View")
                .navigationTitle("Settings")
        }
    }
}

enum HistoryNavigationDestination: Hashable {
    case gameDetail(gameId: String)
    case gameStatistics
    case exportData
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .gameDetail(let gameId):
            Text("Game Detail: \(gameId)")
                .navigationTitle("Game Details")
        case .gameStatistics:
            Text("Statistics View")
                .navigationTitle("Statistics")
        case .exportData:
            Text("Export Data View")
                .navigationTitle("Export Data")
        }
    }
}

enum GroupsNavigationDestination: Hashable {
    case groupDetail(groupId: String)
    case createGroup
    case inviteMembers
    case leaderboard(groupId: String)
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .groupDetail(let groupId):
            Text("Group Detail: \(groupId)")
                .navigationTitle("Group Details")
        case .createGroup:
            Text("Create Group View")
                .navigationTitle("Create Group")
        case .inviteMembers:
            Text("Invite Members View")
                .navigationTitle("Invite Members")
        case .leaderboard(let groupId):
            Text("Leaderboard: \(groupId)")
                .navigationTitle("Leaderboard")
        }
    }
}

enum ProfileNavigationDestination: Hashable {
    case settings
    case subscription
    case achievements
    case privacyPolicy
    case about
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .settings:
            Text("Settings View")
                .navigationTitle("Settings")
        case .subscription:
            Text("Subscription View")
                .navigationTitle("Subscription")
        case .achievements:
            Text("Achievements View")
                .navigationTitle("Achievements")
        case .privacyPolicy:
            Text("Privacy Policy View")
                .navigationTitle("Privacy Policy")
        case .about:
            Text("About View")
                .navigationTitle("About")
        }
    }
}

// MARK: - Deep Link Support
struct DeepLinkDestination {
    let tab: Tab
    let destination: Any
}

#Preview {
    MainTabView()
        .environmentObject(AuthenticationService())
}