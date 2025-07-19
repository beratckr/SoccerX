import SwiftUI

struct HistoryView: View {
    @State private var selectedFilter: HistoryFilter = .all
    @State private var games: [GameSummary] = mockGames
    
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section
                filterSection
                
                // Games List
                gamesList
            }
            .background(Color.black)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Color.green : Color.clear
                            )
                            .foregroundColor(
                                selectedFilter == filter ? .black : .white
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        selectedFilter == filter ? Color.clear : Color.gray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    private var gamesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredGames) { game in
                    GameHistoryCard(game: game)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
    }
    
    private var filteredGames: [GameSummary] {
        // TODO: Implement actual filtering logic
        return games
    }
}

struct GameHistoryCard: View {
    let game: GameSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.date)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(game.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("MVP: \(game.mvpScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
            }
            
            // Stats Grid
            HStack(spacing: 20) {
                statItem(icon: "figure.run", value: "\(game.distance) km", label: "Distance")
                statItem(icon: "heart.fill", value: "\(game.avgHeartRate)", label: "Avg HR")
                statItem(icon: "flame.fill", value: "\(game.calories)", label: "Calories")
                statItem(icon: "speedometer", value: "\(game.maxSpeed) km/h", label: "Max Speed")
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
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mock Data
struct GameSummary: Identifiable {
    let id = UUID()
    let date: String
    let duration: String
    let distance: Double
    let avgHeartRate: Int
    let calories: Int
    let maxSpeed: Double
    let mvpScore: Int
}

let mockGames: [GameSummary] = [
    GameSummary(date: "Wed, July 16", duration: "68 mins", distance: 5.2, avgHeartRate: 152, calories: 485, maxSpeed: 24.5, mvpScore: 85),
    GameSummary(date: "Sun, July 13", duration: "72 mins", distance: 5.6, avgHeartRate: 148, calories: 512, maxSpeed: 26.2, mvpScore: 78),
    GameSummary(date: "Thu, July 10", duration: "65 mins", distance: 4.9, avgHeartRate: 155, calories: 467, maxSpeed: 23.8, mvpScore: 82),
    GameSummary(date: "Mon, July 7", duration: "70 mins", distance: 5.3, avgHeartRate: 151, calories: 498, maxSpeed: 25.1, mvpScore: 79),
    GameSummary(date: "Fri, July 4", duration: "66 mins", distance: 5.0, avgHeartRate: 149, calories: 478, maxSpeed: 24.0, mvpScore: 77)
]

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}