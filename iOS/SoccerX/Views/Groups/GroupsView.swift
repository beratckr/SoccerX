import SwiftUI
import Combine
import FirebaseFirestore

struct GroupsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var selectedTab: GroupTab = .myGroups
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var groups: [Group] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let groupRepository = GroupRepository()
    @State private var cancellables = Set<AnyCancellable>()
    
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
        .onAppear {
            loadGroups()
        }
        .onChange(of: authService.currentUser) { _ in
            loadGroups()
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
            if isLoading {
                ProgressView("Loading groups...")
                    .foregroundColor(.white)
                    .padding(.top, 50)
            } else if groups.isEmpty {
                VStack(spacing: 16) {
                    Text("👥")
                        .font(.system(size: 48))
                    Text("No groups yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Join or create a group to compete with friends!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Group") {
                        showingCreateGroup = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                    .cornerRadius(12)
                    .padding(.top, 8)
                }
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(groups) { group in
                        GroupCard(group: group)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Bottom padding for tab bar
            }
        }
    }
    
    private var leaderboardsContent: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading leaderboards...")
                    .foregroundColor(.white)
                    .padding(.top, 50)
            } else if groups.isEmpty {
                VStack(spacing: 16) {
                    Text("🏆")
                        .font(.system(size: 48))
                    Text("No leaderboards")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Join groups to see leaderboards and compete!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
            } else {
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
    
    // MARK: - Data Loading
    private func loadGroups() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        groupRepository.getUserGroups(uid: currentUser.uid)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        isLoading = false
                    }
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            errorMessage = "Failed to load groups: \(error.localizedDescription)"
                        }
                    }
                },
                receiveValue: { groups in
                    DispatchQueue.main.async {
                        self.groups = groups
                    }
                }
            )
            .store(in: &cancellables)
    }
}

struct GroupCard: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(group.memberIds.count) members")
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
            
            // Description
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Stats
            HStack(spacing: 20) {
                statItem(label: "Members", value: "\(group.memberIds.count)/\(group.maxMembers)")
                statItem(label: "Visibility", value: group.isPublic ? "Public" : "Private")
                statItem(label: "Created", value: formattedDate(group.createdAt))
            }
            
            // Weekly Challenge
            if let challenge = group.weeklyChallenge {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Challenge")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(challenge.title)
                        .font(.caption)
                        .foregroundColor(.green)
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
    
    private func formattedDate(_ timestamp: FirebaseFirestore.Timestamp?) -> String {
        guard let timestamp = timestamp else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: timestamp.dateValue())
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
    let group: Group
    
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
                // Placeholder leaderboard since we don't have real leaderboard data yet
                leaderboardRow(rank: 1, name: "Top Player", distance: 0.0, isCurrentUser: false)
                leaderboardRow(rank: 2, name: "You", distance: 0.0, isCurrentUser: true)
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


#Preview {
    GroupsView()
        .preferredColorScheme(.dark)
}