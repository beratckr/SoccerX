import SwiftUI
import Combine

struct LeaderboardView: View {
    let groupId: String
    @StateObject private var viewModel: LeaderboardViewModel
    @State private var selectedWeek = 0
    @State private var showingHistory = false
    
    init(groupId: String) {
        self.groupId = groupId
        self._viewModel = StateObject(wrappedValue: LeaderboardViewModel(groupId: groupId))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.currentLeaderboard == nil {
                LoadingView(message: "Loading leaderboard...", style: .soccer)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Weekly Challenge Card
                        if let challenge = viewModel.weeklyChallenge {
                            WeeklyChallengeCard(challenge: challenge)
                                .padding(.horizontal, 20)
                        }
                        
                        // Week Selector
                        weekSelector
                            .padding(.horizontal, 20)
                        
                        // Leaderboard Rankings
                        if let leaderboard = viewModel.currentLeaderboard {
                            LeaderboardRankingsView(
                                rankings: leaderboard.rankings,
                                currentUserId: viewModel.currentUserId,
                                previousRankings: viewModel.previousRankings
                            )
                            .padding(.horizontal, 20)
                        } else {
                            EmptyStateView(
                                title: "No data yet",
                                message: "Complete some games to see the leaderboard",
                                icon: "trophy"
                            )
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, 16)
                }
                .refreshable {
                    await viewModel.refreshLeaderboard()
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("History") {
                    showingHistory = true
                }
                .foregroundColor(.green)
            }
        }
        .sheet(isPresented: $showingHistory) {
            LeaderboardHistoryView(groupId: groupId)
        }
        .task {
            await viewModel.loadLeaderboard()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var weekSelector: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    selectedWeek = max(0, selectedWeek - 1)
                    Task {
                        await viewModel.loadWeek(offset: selectedWeek)
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedWeek > -4 ? .white : .gray)
            }
            .disabled(selectedWeek <= -4)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(selectedWeek == 0 ? "This Week" : "Week \(viewModel.getWeekNumber(offset: selectedWeek))")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(viewModel.getWeekDateRange(offset: selectedWeek))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    selectedWeek = min(0, selectedWeek + 1)
                    Task {
                        await viewModel.loadWeek(offset: selectedWeek)
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedWeek < 0 ? .white : .gray)
            }
            .disabled(selectedWeek >= 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Challenge Card

struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge
    @State private var timeRemaining = ""
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Weekly Challenge", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Ends in")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(timeRemaining)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if challenge.target > 0 {
                HStack {
                    Label("Target", systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTarget(challenge.target, type: challenge.type))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let remaining = challenge.endDate.timeIntervalSince(Date())
        
        if remaining <= 0 {
            timeRemaining = "Ended"
        } else {
            let days = Int(remaining) / 86400
            let hours = (Int(remaining) % 86400) / 3600
            
            if days > 0 {
                timeRemaining = "\(days)d \(hours)h"
            } else {
                let minutes = (Int(remaining) % 3600) / 60
                timeRemaining = "\(hours)h \(minutes)m"
            }
        }
    }
    
    private func formatTarget(_ target: Double, type: WeeklyChallenge.ChallengeType) -> String {
        switch type {
        case .totalDistance:
            return "\(Int(target)) km"
        case .totalGames:
            return "\(Int(target)) games"
        case .avgMVPScore:
            return "\(Int(target)) MVP score"
        case .speedDemon:
            return "\(Int(target)) km/h"
        case .consistentPlayer:
            return "\(Int(target)) days"
        case .endurance:
            return "\(Int(target)) minutes"
        }
    }
}

// MARK: - Leaderboard Rankings View

struct LeaderboardRankingsView: View {
    let rankings: [LeaderboardEntry]
    let currentUserId: String
    let previousRankings: [String: Int] // userId: previousRank
    
    @State private var animatedRankings: [LeaderboardEntry] = []
    @State private var showAnimations = false
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(animatedRankings.enumerated()), id: \.element.userId) { index, entry in
                LeaderboardRowView(
                    entry: entry,
                    rank: index + 1,
                    isCurrentUser: entry.userId == currentUserId,
                    previousRank: previousRankings[entry.userId],
                    showAnimation: showAnimations
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
                if index < animatedRankings.count - 1 {
                    Divider()
                        .background(Color(.systemGray5).opacity(0.3))
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            animateRankings()
        }
        .onChange(of: rankings) { oldValue, newValue in
            animateRankings()
        }
    }
    
    private func animateRankings() {
        animatedRankings = []
        showAnimations = false
        
        for (index, entry) in rankings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedRankings.append(entry)
                }
                
                if index == rankings.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showAnimations = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Leaderboard Row View

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    let previousRank: Int?
    let showAnimation: Bool
    
    @State private var showRankChange = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            ZStack {
                if rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.title2)
                        .foregroundColor(rankColor)
                        .scaleEffect(showAnimation ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2), value: showAnimation)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40)
            
            // User Info
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5).opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    if let profileImageUrl = entry.profileImageUrl {
                        AsyncImage(url: URL(string: profileImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Text(entry.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                
                // Name and Stats
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Label("\(entry.totalGames)", systemImage: "soccerball")
                        Label(entry.totalDistanceFormatted, systemImage: "location")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Rank Change
                if let previousRank = previousRank, previousRank != rank {
                    RankChangeIndicator(
                        previousRank: previousRank,
                        currentRank: rank,
                        show: showRankChange
                    )
                }
                
                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", entry.points))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("pts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if rank == 1 && showAnimation {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isCurrentUser ? Color.green.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onAppear {
            if previousRank != nil && previousRank != rank {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring()) {
                        showRankChange = true
                    }
                }
            }
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return ""
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.7)
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Rank Change Indicator

struct RankChangeIndicator: View {
    let previousRank: Int
    let currentRank: Int
    let show: Bool
    
    private var rankChange: Int {
        previousRank - currentRank
    }
    
    private var isImproved: Bool {
        rankChange > 0
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isImproved ? "arrow.up" : "arrow.down")
                .font(.caption2)
                .fontWeight(.bold)
            
            Text("\(abs(rankChange))")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(isImproved ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((isImproved ? Color.green : Color.red).opacity(0.2))
        )
        .scaleEffect(show ? 1 : 0)
        .opacity(show ? 1 : 0)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeaderboardView(groupId: "preview-group-id")
    }
    .preferredColorScheme(.dark)
}