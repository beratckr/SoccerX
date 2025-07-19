import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Start Game Button
                    startGameSection
                    
                    // Last Game Summary
                    lastGameSection
                    
                    // Weekly Stats
                    weeklyStatsSection
                    
                    // Group Leaderboard Preview
                    leaderboardSection
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .onAppear {
            updateCurrentDate()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(dateText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Start Game Section
    private var startGameSection: some View {
        VStack(spacing: 0) {
            Button(action: startGame) {
                VStack(spacing: 8) {
                    Text("⚽")
                        .font(.system(size: 48))
                    
                    Text("Start Game")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("Apple Watch Connected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(24)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Last Game Section
    private var lastGameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Game")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Button(action: viewGameDetails) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Wednesday, July 16 • 6:30 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        statItem(value: "5.2", label: "km")
                        statItem(value: "68", label: "mins")
                        statItem(value: "85", label: "MVP Score")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Weekly Stats Section
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                weeklyStatCard(icon: "🏃", value: "2", description: "Games Played")
                weeklyStatCard(icon: "📏", value: "10.8", description: "Total km")
                weeklyStatCard(icon: "⚡", value: "24.5", description: "Max Speed km/h")
                weeklyStatCard(icon: "🔥", value: "842", description: "Calories Burned")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Austin Sunday League")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See all") {
                    // Navigate to full leaderboard
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("🏆")
                    Text("This Week's Leaderboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    leaderboardRow(rank: "1", rankColor: .yellow, name: "Mike Johnson", stats: "3 games • 156 avg HR", distance: "18.2 km")
                    leaderboardRow(rank: "2", rankColor: .gray, name: "Sarah Chen", stats: "3 games • 148 avg HR", distance: "16.5 km")
                    leaderboardRow(rank: "3", rankColor: .orange, name: "You", stats: "2 games • 152 avg HR", distance: "10.8 km", isCurrentUser: true)
                    leaderboardRow(rank: "4", rankColor: .secondary, name: "James Wilson", stats: "2 games • 144 avg HR", distance: "9.4 km")
                }
            }
            .padding(20)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
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
    
    private func weeklyStatCard(icon: String, value: String, description: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private func leaderboardRow(rank: String, rankColor: Color, name: String, stats: String, distance: String, isCurrentUser: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(rank)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(rankColor)
                .frame(width: 24)
            
            Text(isCurrentUser ? "🙋‍♂️" : "👤")
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5).opacity(0.3))
                .cornerRadius(18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(stats)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(distance)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, isCurrentUser ? 12 : 0)
        .padding(.vertical, isCurrentUser ? 8 : 0)
        .background(isCurrentUser ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        let name = authService.currentUser?.displayName ?? "Champion"
        
        switch hour {
        case 5..<12:
            return "Good morning, \(name)!"
        case 12..<18:
            return "Good afternoon, \(name)!"
        default:
            return "Good evening, \(name)!"
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentDate)
    }
    
    // MARK: - Actions
    private func updateCurrentDate() {
        currentDate = Date()
    }
    
    private func startGame() {
        // TODO: Navigate to game tracking
        print("Starting new game...")
    }
    
    private func viewGameDetails() {
        // TODO: Navigate to game details
        print("Viewing game details...")
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    DashboardView()
}