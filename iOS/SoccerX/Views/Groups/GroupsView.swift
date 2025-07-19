import SwiftUI

struct GroupsView: View {
    @State private var selectedTab: GroupTab = .myGroups
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var groups: [SoccerGroup] = mockGroups
    
    enum GroupTab: String, CaseIterable {
        case myGroups = "My Groups"
        case leaderboards = "Leaderboards"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                tabSelector
                
                // Content
                if selectedTab == .myGroups {
                    myGroupsContent
                } else {
                    leaderboardsContent
                }
            }
            .background(Color.black)
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create Group") {
                            showingCreateGroup = true
                        }
                        Button("Join Group") {
                            showingJoinGroup = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView()
        }
        .sheet(isPresented: $showingJoinGroup) {
            JoinGroupView()
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(GroupTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == tab ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab ? Color.green : Color.clear
                        )
                }
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var myGroupsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groups) { group in
                    GroupCard(group: group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
    }
    
    private var leaderboardsContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(groups) { group in
                    GroupLeaderboardCard(group: group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
    }
}

struct GroupCard: View {
    let group: SoccerGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(group.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if group.isPremium {
                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                }
            }
            
            // Stats
            HStack(spacing: 20) {
                statItem(label: "Your Rank", value: "#\(group.yourRank)")
                statItem(label: "This Week", value: "\(group.yourWeeklyDistance) km")
                statItem(label: "Total Games", value: "\(group.totalGames)")
            }
            
            // Recent Activity
            if !group.recentActivity.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(group.recentActivity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct GroupLeaderboardCard: View {
    let group: SoccerGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full leaderboard
                }
                .font(.caption)
                .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                ForEach(Array(group.topPlayers.enumerated()), id: \.offset) { index, player in
                    leaderboardRow(
                        rank: index + 1,
                        name: player.name,
                        distance: player.weeklyDistance,
                        isCurrentUser: player.isCurrentUser
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private func leaderboardRow(rank: Int, name: String, distance: Double, isCurrentUser: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(rankColor(rank))
                .frame(width: 24)
            
            Text(isCurrentUser ? "🙋‍♂️" : "👤")
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray5).opacity(0.3))
                .cornerRadius(16)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(String(format: "%.1f", distance)) km")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, isCurrentUser ? 12 : 0)
        .padding(.vertical, isCurrentUser ? 8 : 0)
        .background(isCurrentUser ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Placeholder Views
struct CreateGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Group Feature")
                    .font(.title)
                    .padding()
                
                Text("Coming Soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct JoinGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Join Group Feature")
                    .font(.title)
                    .padding()
                
                Text("Coming Soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Mock Data
struct SoccerGroup: Identifiable {
    let id = UUID()
    let name: String
    let memberCount: Int
    let yourRank: Int
    let yourWeeklyDistance: Double
    let totalGames: Int
    let recentActivity: String
    let isPremium: Bool
    let topPlayers: [GroupPlayer]
}

struct GroupPlayer {
    let name: String
    let weeklyDistance: Double
    let isCurrentUser: Bool
}

let mockGroups: [SoccerGroup] = [
    SoccerGroup(
        name: "Austin Sunday League",
        memberCount: 24,
        yourRank: 3,
        yourWeeklyDistance: 10.8,
        totalGames: 15,
        recentActivity: "Mike Johnson completed a game • 2h ago",
        isPremium: true,
        topPlayers: [
            GroupPlayer(name: "Mike Johnson", weeklyDistance: 18.2, isCurrentUser: false),
            GroupPlayer(name: "Sarah Chen", weeklyDistance: 16.5, isCurrentUser: false),
            GroupPlayer(name: "You", weeklyDistance: 10.8, isCurrentUser: true)
        ]
    ),
    SoccerGroup(
        name: "Weekend Warriors",
        memberCount: 12,
        yourRank: 2,
        yourWeeklyDistance: 8.5,
        totalGames: 8,
        recentActivity: "Emma Wilson joined the group • 1d ago",
        isPremium: false,
        topPlayers: [
            GroupPlayer(name: "Alex Rodriguez", weeklyDistance: 9.2, isCurrentUser: false),
            GroupPlayer(name: "You", weeklyDistance: 8.5, isCurrentUser: true),
            GroupPlayer(name: "Chris Taylor", weeklyDistance: 7.9, isCurrentUser: false)
        ]
    )
]

#Preview {
    GroupsView()
        .preferredColorScheme(.dark)
}