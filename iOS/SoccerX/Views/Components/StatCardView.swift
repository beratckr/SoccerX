import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let backgroundColor: Color
    let accentColor: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        backgroundColor: Color = Color(.systemGray6),
        accentColor: Color = .green
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accentColor)
                
                Spacer()
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct StatCardViewModifier: ViewModifier {
    let isSelected: Bool
    let accentColor: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

extension StatCardView {
    func selected(_ isSelected: Bool) -> some View {
        self.modifier(StatCardViewModifier(isSelected: isSelected, accentColor: accentColor))
    }
}

struct StatCardGridView: View {
    let stats: [StatCardData]
    let columns: Int
    
    init(stats: [StatCardData], columns: Int = 2) {
        self.stats = stats
        self.columns = columns
    }
    
    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 12) {
            ForEach(stats) { stat in
                StatCardView(
                    title: stat.title,
                    value: stat.value,
                    subtitle: stat.subtitle,
                    icon: stat.icon,
                    backgroundColor: stat.backgroundColor,
                    accentColor: stat.accentColor
                )
            }
        }
    }
}

struct StatCardData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let backgroundColor: Color
    let accentColor: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        backgroundColor: Color = Color(.systemGray6),
        accentColor: Color = .green
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
    }
}

#Preview {
    VStack(spacing: 20) {
        StatCardView(
            title: "Goals",
            value: "12",
            subtitle: "This week",
            icon: "soccerball",
            accentColor: .green
        )
        
        StatCardView(
            title: "Games Played",
            value: "8",
            subtitle: "Total",
            icon: "stopwatch",
            accentColor: .blue
        )
        .selected(true)
        
        StatCardGridView(stats: [
            StatCardData(title: "Goals", value: "12", subtitle: "This week", icon: "soccerball", accentColor: .green),
            StatCardData(title: "Assists", value: "5", subtitle: "This week", icon: "hands.sparkles", accentColor: .blue),
            StatCardData(title: "Games", value: "8", subtitle: "Total", icon: "stopwatch", accentColor: .orange),
            StatCardData(title: "Rating", value: "8.5", subtitle: "Average", icon: "star", accentColor: .yellow)
        ])
    }
    .padding()
    .preferredColorScheme(.dark)
}