import SwiftUI

struct ActivityRowView: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Activity Icon
            ZStack {
                Circle()
                    .fill(activity.type.backgroundColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(activity.type.iconColor)
            }
            
            // Activity Details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time and Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(activity.type.valueColor)
                
                Text(activity.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Types

struct ActivityItem: Identifiable {
    let id = UUID()
    let type: ActivityType
    let title: String
    let subtitle: String
    let value: String
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum ActivityType {
    case game
    case achievement
    case groupActivity
    case personalBest
    
    var icon: String {
        switch self {
        case .game: return "soccerball"
        case .achievement: return "trophy"
        case .groupActivity: return "person.3"
        case .personalBest: return "star.fill"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .game: return .green.opacity(0.2)
        case .achievement: return .yellow.opacity(0.2)
        case .groupActivity: return .blue.opacity(0.2)
        case .personalBest: return .purple.opacity(0.2)
        }
    }
    
    var iconColor: Color {
        switch self {
        case .game: return .green
        case .achievement: return .yellow
        case .groupActivity: return .blue
        case .personalBest: return .purple
        }
    }
    
    var valueColor: Color {
        switch self {
        case .game: return .green
        case .achievement: return .yellow
        case .groupActivity: return .blue
        case .personalBest: return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ActivityRowView(activity: ActivityItem(
            type: .game,
            title: "Morning Game Completed",
            subtitle: "Central Park Field",
            value: "8.2 km",
            timestamp: Date().addingTimeInterval(-3600)
        ))
        
        Divider()
        
        ActivityRowView(activity: ActivityItem(
            type: .achievement,
            title: "New Achievement Unlocked",
            subtitle: "Speed Demon",
            value: "🏆",
            timestamp: Date().addingTimeInterval(-7200)
        ))
        
        Divider()
        
        ActivityRowView(activity: ActivityItem(
            type: .personalBest,
            title: "Personal Best!",
            subtitle: "Highest MVP Score",
            value: "92",
            timestamp: Date().addingTimeInterval(-86400)
        ))
    }
    .padding(.horizontal)
    .background(Color.black)
    .preferredColorScheme(.dark)
}