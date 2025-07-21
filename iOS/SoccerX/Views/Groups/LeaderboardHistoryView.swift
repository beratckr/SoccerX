import SwiftUI
import FirebaseAuth

struct LeaderboardHistoryView: View {
    let groupId: String
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: LeaderboardHistoryViewModel
    
    init(groupId: String) {
        self.groupId = groupId
        self._viewModel = StateObject(wrappedValue: LeaderboardHistoryViewModel(groupId: groupId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingView(message: "Loading history...", style: .soccer)
                } else if viewModel.historicalLeaderboards.isEmpty {
                    EmptyStateView(
                        title: "No history yet",
                        message: "Past leaderboards will appear here",
                        icon: "clock.arrow.circlepath"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.historicalLeaderboards) { leaderboard in
                                HistoricalLeaderboardCard(
                                    leaderboard: leaderboard,
                                    currentUserId: viewModel.currentUserId
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Leaderboard History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadHistory()
        }
    }
}

// MARK: - Historical Leaderboard Card

struct HistoricalLeaderboardCard: View {
    let leaderboard: Leaderboard
    let currentUserId: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week \(weekNumber)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(weekDateRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let userRank = userRank {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Your Rank")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                if userRank <= 3 {
                                    Image(systemName: rankIcon(for: userRank))
                                        .font(.caption)
                                        .foregroundColor(rankColor(for: userRank))
                                }
                                Text("#\(userRank)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(20)
            }
            
            // Expanded Content
            if isExpanded {
                Divider()
                    .background(Color(.systemGray5).opacity(0.3))
                
                VStack(spacing: 12) {
                    ForEach(Array(leaderboard.rankings.prefix(5).enumerated()), id: \.element.userId) { index, entry in
                        CompactLeaderboardRow(
                            entry: entry,
                            rank: index + 1,
                            isCurrentUser: entry.userId == currentUserId
                        )
                    }
                }
                .padding(20)
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private var weekNumber: String {
        let components = leaderboard.weekId.split(separator: "-W")
        return String(components.last ?? "")
    }
    
    private var weekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        
        let start = formatter.string(from: leaderboard.startDate)
        formatter.dateFormat = "MMM d"
        let end = formatter.string(from: leaderboard.endDate.addingTimeInterval(-86400))
        
        return "\(start) - \(end)"
    }
    
    private var userRank: Int? {
        leaderboard.rankings.firstIndex(where: { $0.userId == currentUserId }).map { $0 + 1 }
    }
    
    private func rankIcon(for rank: Int) -> String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return ""
        }
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.7)
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Compact Leaderboard Row

struct CompactLeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 24)
            
            // Name
            Text(entry.displayName)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                Label("\(entry.totalGames)", systemImage: "soccerball")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.0f pts", entry.points))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, isCurrentUser ? 12 : 0)
        .padding(.vertical, isCurrentUser ? 8 : 0)
        .background(isCurrentUser ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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

// MARK: - View Model

@MainActor
class LeaderboardHistoryViewModel: ObservableObject {
    @Published var historicalLeaderboards: [Leaderboard] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    let groupId: String
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private let leaderboardManager = LeaderboardManager.shared
    
    init(groupId: String) {
        self.groupId = groupId
    }
    
    func loadHistory() async {
        isLoading = true
        
        do {
            let leaderboards = try await leaderboardManager.getHistoricalLeaderboards(
                for: groupId,
                weeks: 8
            ).async()
            
            // Filter out current week and sort by most recent first
            historicalLeaderboards = leaderboards
                .filter { !$0.isCurrentWeek }
                .sorted { $0.weekId > $1.weekId }
            
        } catch {
            errorMessage = "Failed to load history"
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    LeaderboardHistoryView(groupId: "preview-group-id")
        .preferredColorScheme(.dark)
}