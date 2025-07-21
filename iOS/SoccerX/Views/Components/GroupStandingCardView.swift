import SwiftUI

struct GroupStandingCardView: View {
    let standings: [GroupStanding]
    let currentUserId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Leaderboard", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full leaderboard
                }
                .font(.caption)
                .foregroundColor(.green)
            }
            
            // Top 3 Standings
            VStack(spacing: 12) {
                ForEach(Array(standings.prefix(3).enumerated()), id: \.element.id) { index, standing in
                    StandingRow(
                        standing: standing,
                        rank: index + 1,
                        isCurrentUser: standing.userId == currentUserId
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
}

struct StandingRow: View {
    let standing: GroupStanding
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Medal
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // User Avatar
            if let profileImageUrl = standing.profileImageUrl {
                AsyncImage(url: URL(string: profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 36, height: 36)
            }
            
            // Name and Stats
            VStack(alignment: .leading, spacing: 2) {
                Text(standing.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(standing.gamesPlayed) games • \(standing.totalDistanceFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", standing.points))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("pts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

// MARK: - Supporting Types

struct GroupStanding: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let profileImageUrl: String?
    let totalDistance: Double
    let gamesPlayed: Int
    let points: Double
    
    var totalDistanceFormatted: String {
        String(format: "%.1f km", totalDistance)
    }
}

// MARK: - Preview

#Preview {
    GroupStandingCardView(
        standings: [
            GroupStanding(
                id: "1",
                userId: "user1",
                displayName: "John Doe",
                profileImageUrl: nil,
                totalDistance: 45.2,
                gamesPlayed: 8,
                points: 285
            ),
            GroupStanding(
                id: "2",
                userId: "currentUser",
                displayName: "You",
                profileImageUrl: nil,
                totalDistance: 38.7,
                gamesPlayed: 6,
                points: 232
            ),
            GroupStanding(
                id: "3",
                userId: "user3",
                displayName: "Sarah Wilson",
                profileImageUrl: nil,
                totalDistance: 32.1,
                gamesPlayed: 5,
                points: 198
            )
        ],
        currentUserId: "currentUser"
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}