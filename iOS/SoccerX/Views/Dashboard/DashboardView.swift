import SwiftUI
import Combine
import Charts
import FirebaseFirestore

struct DashboardView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.recentGames.isEmpty {
                    LoadingView(message: "Loading dashboard...", style: .soccer)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(
                        title: "Failed to load",
                        message: errorMessage,
                        retryAction: {
                            Task {
                                await viewModel.refreshData(for: authService.currentUser)
                            }
                        }
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            headerSection
                            quickActionsSection
                            lastGameSection
                            weeklyStatsSection
                            performanceChartSection
                            groupsSection
                            
                            Spacer(minLength: 100) // Bottom padding for tab bar
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.loadDashboardData(for: authService.currentUser)
        }
        .onChange(of: authService.currentUser?.uid) { oldValue, newValue in
            Task {
                await viewModel.loadDashboardData(for: authService.currentUser)
            }
        }
        .refreshable {
            await viewModel.refreshData(for: authService.currentUser)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        NavigationHeaderView(
            title: viewModel.greetingText,
            subtitle: userName + " • " + viewModel.dateText
        )
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Start Game Button
            ActionButton(
                "Start Game",
                icon: "play.fill",
                style: .primary,
                size: .extraLarge
            ) {
                Task {
                    await viewModel.startGame()
                }
            }
            .disabled(viewModel.isStartingGame)
            .overlay(
                startGameOverlay,
                alignment: .bottom
            )
            
            // Secondary Actions
            HStack(spacing: 12) {
                ActionButton(
                    "Join Game",
                    icon: "person.2",
                    style: .outline,
                    size: .medium
                ) {
                    // TODO: Navigate to join game
                }
                
                ActionButton(
                    "Quick Stats",
                    icon: "chart.bar",
                    style: .ghost,
                    size: .medium
                ) {
                    // TODO: Navigate to detailed stats
                }
            }
        }
    }
    
    private var startGameOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.watchConnectionStatus.color)
                    .frame(width: 6, height: 6)
                
                Text(viewModel.watchConnectionStatus.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Last Game Section
    private var lastGameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Last Game",
                action: viewModel.lastGame != nil ? SectionAction(text: "View All") {
                    // TODO: Navigate to history
                } : nil
            )
            
            if let lastGame = viewModel.lastGame {
                lastGameCard(lastGame)
            } else {
                EmptyStateView(
                    title: "No games yet",
                    message: "Start your first game to see your progress here.",
                    icon: "soccerball",
                    actionTitle: "Start Game",
                    action: {
                        Task {
                            await viewModel.startGame()
                        }
                    }
                )
                .frame(height: 200)
            }
        }
    }
    
    private func lastGameCard(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(formatGameDate(game.startTime))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                statItem(
                    value: String(format: "%.1f", game.distance),
                    label: "km"
                )
                
                statItem(
                    value: formatDuration(game.duration),
                    label: "mins"
                )
                
                statItem(
                    value: String(format: "%.1f", game.mvpScore ?? 0),
                    label: "MVP Score"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .onTapGesture {
            // TODO: Navigate to game details
        }
    }
    
    // MARK: - Weekly Stats Section
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "This Week",
                action: SectionAction(text: "View More") {
                    // TODO: Navigate to detailed stats
                }
            )
            
            StatCardGridView(
                stats: viewModel.weeklyStatCards,
                columns: 2
            )
        }
    }
    
    // MARK: - Performance Chart Section
    private var performanceChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Performance Trends",
                action: SectionAction(text: "View All") {
                    // TODO: Navigate to detailed charts
                }
            )
            
            if viewModel.recentGames.isEmpty {
                emptyChartView
            } else {
                performanceChart
            }
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No performance data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Complete a few games to see your progress trends")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Distance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(String(format: "%.1f", weeklyTotalDistance)) km total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Chart(chartData) { point in
                LineMark(
                    x: .value("Day", point.x),
                    y: .value("Distance", point.y)
                )
                .foregroundStyle(.green.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                
                PointMark(
                    x: .value("Day", point.x),
                    y: .value("Distance", point.y)
                )
                .foregroundStyle(.green)
                .symbolSize(25)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(String(format: "%.1f", doubleValue))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartBackground { _ in
                Rectangle()
                    .fill(.clear)
            }
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Groups Section
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let firstGroup = viewModel.userGroups.first {
                SectionHeaderView(
                    title: firstGroup.name,
                    action: SectionAction(text: "See All") {
                        // TODO: Navigate to full leaderboard
                    }
                )
                
                leaderboardCard
            } else {
                SectionHeaderView(
                    title: "Join a Group",
                    action: SectionAction(text: "Browse") {
                        // TODO: Navigate to groups
                    }
                )
                
                joinGroupCard
            }
        }
    }
    
    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("🏆")
                Text("This Week's Leaderboard")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.leaderboardData.prefix(3)) { entry in
                    leaderboardRow(entry)
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    private var joinGroupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Join groups to compete with friends and see leaderboards!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ActionButton(
                "Find Groups",
                icon: "person.3",
                style: .primary,
                size: .medium
            ) {
                // TODO: Navigate to groups discovery
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Views
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
    }
    
    private func leaderboardRow(_ entry: DashboardLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(entry.rankColor)
                .frame(width: 24)
            
            Text(entry.isCurrentUser ? "🙋‍♂️" : "👤")
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5).opacity(0.3))
                .cornerRadius(18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(entry.displayStats)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(entry.displayDistance)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, entry.isCurrentUser ? 12 : 0)
        .padding(.vertical, entry.isCurrentUser ? 8 : 0)
        .background(entry.isCurrentUser ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var userName: String {
        authService.currentUser?.displayName ?? "Champion"
    }
    
    private var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create last 7 days
        let days = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: now)
        }.reversed()
        
        return days.map { date in
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "E" // Mon, Tue, etc.
            let dayName = dayFormatter.string(from: date)
            
            // Find games for this day
            let dayGames = viewModel.recentGames.filter { game in
                guard let gameDate = game.startTime?.dateValue() else { return false }
                return calendar.isDate(gameDate, inSameDayAs: date)
            }
            
            let totalDistance = dayGames.reduce(0) { $0 + $1.distance }
            
            return ChartDataPoint(x: dayName, y: totalDistance)
        }
    }
    
    private var weeklyTotalDistance: Double {
        return chartData.reduce(0) { $0 + $1.y }
    }
    
    // MARK: - Helper Methods
    private func formatGameDate(_ timestamp: FirebaseFirestore.Timestamp?) -> String {
        guard let timestamp = timestamp else { return "No date" }
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d • h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)"
    }
}

// MARK: - Supporting Types
// ChartDataPoint is now imported from StatChartView

#Preview {
    DashboardView()
        .environmentObject(AuthenticationService.shared)
        .preferredColorScheme(.dark)
}