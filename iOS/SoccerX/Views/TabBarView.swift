import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .home
    @EnvironmentObject var authService: AuthenticationService
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case history = 1
        case groups = 2
        case profile = 3
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .history: return "History"
            case .groups: return "Groups"
            case .profile: return "Profile"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .history: return "chart.bar"
            case .groups: return "person.2"
            case .profile: return "person"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .history: return "chart.bar.fill"
            case .groups: return "person.2.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: selectedTab == .home ? Tab.home.selectedIcon : Tab.home.icon)
                    Text(Tab.home.title)
                }
                .tag(Tab.home)
            
            HistoryView()
                .tabItem {
                    Image(systemName: selectedTab == .history ? Tab.history.selectedIcon : Tab.history.icon)
                    Text(Tab.history.title)
                }
                .tag(Tab.history)
            
            GroupsView()
                .tabItem {
                    Image(systemName: selectedTab == .groups ? Tab.groups.selectedIcon : Tab.groups.icon)
                    Text(Tab.groups.title)
                }
                .tag(Tab.groups)
            
            ProfileView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: selectedTab == .profile ? Tab.profile.selectedIcon : Tab.profile.icon)
                    Text(Tab.profile.title)
                }
                .tag(Tab.profile)
        }
        .accentColor(.green)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthenticationService())
}