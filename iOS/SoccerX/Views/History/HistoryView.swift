import SwiftUI
import Combine

struct HistoryView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var selectedFilter: HistoryFilter = .all
    @State private var games: [Game] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let gameRepository = GameRepository()
    @State private var cancellables = Set<AnyCancellable>()
    
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
        .onAppear {
            loadGames()
        }
        .onChange(of: authService.currentUser) { _ in
            loadGames()
        }
        .onChange(of: selectedFilter) { _ in
            loadGames()
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
            if isLoading {
                ProgressView("Loading games...")
                    .foregroundColor(.white)
                    .padding(.top, 50)
            } else if games.isEmpty {
                VStack(spacing: 16) {
                    Text("🏆")
                        .font(.system(size: 48))
                    Text("No games yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Start playing to see your game history here!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(filteredGames) { game in
                        GameHistoryCard(game: game)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Bottom padding for tab bar
            }
        }
    }
    
    private var filteredGames: [Game] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedFilter {
        case .all:
            return games
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return games.filter { game in
                guard let startTime = game.startTime else { return false }
                return startTime.dateValue() >= startOfWeek
            }
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return games.filter { game in
                guard let startTime = game.startTime else { return false }
                return startTime.dateValue() >= startOfMonth
            }
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return games.filter { game in
                guard let startTime = game.startTime else { return false }
                return startTime.dateValue() >= startOfYear
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadGames() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        gameRepository.getUserGames(uid: currentUser.uid, limit: 100)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        isLoading = false
                    }
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            errorMessage = "Failed to load games: \(error.localizedDescription)"
                        }
                    }
                },
                receiveValue: { games in
                    DispatchQueue.main.async {
                        self.games = games
                    }
                }
            )
            .store(in: &cancellables)
    }
}

struct GameHistoryCard: View {
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("MVP: \(Int(game.mvpScore ?? 0))")
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
                statItem(icon: "figure.run", value: String(format: "%.1f km", game.distance), label: "Distance")
                statItem(icon: "heart.fill", value: "\(game.heartRateData?.average ?? 0)", label: "Avg HR")
                statItem(icon: "flame.fill", value: "0", label: "Calories") // TODO: Calculate calories
                statItem(icon: "speedometer", value: String(format: "%.1f km/h", game.maxSpeed), label: "Max Speed")
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
    
    private var formattedDate: String {
        guard let startTime = game.startTime else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startTime.dateValue())
    }
    
    private var formattedDuration: String {
        let minutes = game.duration / 60
        return "\(minutes) mins"
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


#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}