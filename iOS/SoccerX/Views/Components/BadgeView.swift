import SwiftUI

struct BadgeView: View {
    let badge: Badge
    let size: BadgeSize
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(badge.backgroundColor)
                .frame(width: size.diameter, height: size.diameter)
                .shadow(color: badge.shadowColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Inner Design
            Circle()
                .stroke(badge.borderColor, lineWidth: size.borderWidth)
                .frame(width: size.diameter - 8, height: size.diameter - 8)
            
            // Icon
            Image(systemName: badge.icon)
                .font(.system(size: size.iconSize, weight: .bold))
                .foregroundColor(badge.iconColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Sparkles for special badges
            if badge.isSpecial {
                ForEach(0..<6, id: \.self) { index in
                    SparkleView()
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(CGFloat(index) * .pi / 3) * (size.diameter / 2 + 10),
                            y: sin(CGFloat(index) * .pi / 3) * (size.diameter / 2 + 10)
                        )
                        .opacity(isAnimating ? 0.8 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear {
            if badge.isAnimated {
                isAnimating = true
            }
        }
    }
}

// MARK: - Badge Model

struct Badge: Identifiable {
    let id = UUID()
    let type: BadgeType
    let name: String
    let description: String
    let icon: String
    let backgroundColor: Color
    let borderColor: Color
    let iconColor: Color
    let shadowColor: Color
    let isSpecial: Bool
    let isAnimated: Bool
    let unlockedAt: Date?
    
    init(
        type: BadgeType,
        name: String,
        description: String,
        icon: String,
        backgroundColor: Color,
        borderColor: Color,
        iconColor: Color,
        shadowColor: Color? = nil,
        isSpecial: Bool = false,
        isAnimated: Bool = false,
        unlockedAt: Date? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.iconColor = iconColor
        self.shadowColor = shadowColor ?? backgroundColor
        self.isSpecial = isSpecial
        self.isAnimated = isAnimated
        self.unlockedAt = unlockedAt
    }
}

enum BadgeType {
    case weeklyWinner
    case monthlyChampion
    case achievement
    case milestone
    case special
}

enum BadgeSize {
    case small
    case medium
    case large
    case extraLarge
    
    var diameter: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 60
        case .large: return 80
        case .extraLarge: return 100
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        case .extraLarge: return 40
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        case .extraLarge: return 5
        }
    }
}

// MARK: - Sparkle View

struct SparkleView: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 8))
            .foregroundColor(.yellow)
    }
}

// MARK: - Badge Collection View

struct BadgeCollectionView: View {
    let badges: [Badge]
    let columns: Int
    
    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 20) {
            ForEach(badges) { badge in
                VStack(spacing: 8) {
                    BadgeView(badge: badge, size: .medium)
                    
                    Text(badge.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Weekly Winner Celebration

struct WeeklyWinnerCelebration: View {
    let winnerName: String
    let badge: Badge
    @State private var showAnimation = false
    @State private var confettiOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // Confetti
            ForEach(0..<20, id: \.self) { index in
                ConfettiPiece()
                    .position(
                        x: CGFloat.random(in: 50...350),
                        y: showAnimation ? CGFloat.random(in: 600...800) : -100
                    )
                    .opacity(confettiOpacity)
                    .animation(
                        Animation.easeOut(duration: 2)
                            .delay(Double(index) * 0.05),
                        value: showAnimation
                    )
            }
            
            // Content
            VStack(spacing: 32) {
                Text("🎉 Weekly Winner! 🎉")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(showAnimation ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showAnimation)
                
                BadgeView(badge: badge, size: .extraLarge)
                    .scaleEffect(showAnimation ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showAnimation)
                
                VStack(spacing: 8) {
                    Text(winnerName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Congratulations!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .opacity(showAnimation ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.4), value: showAnimation)
            }
        }
        .onAppear {
            withAnimation {
                showAnimation = true
                confettiOpacity = 1
            }
            
            // Hide confetti after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    confettiOpacity = 0
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .orange]
    
    var body: some View {
        Rectangle()
            .fill(colors.randomElement()!)
            .frame(width: 10, height: 20)
            .rotationEffect(.degrees(Double.random(in: 0...360)))
    }
}

// MARK: - Predefined Badges

extension Badge {
    static let weeklyWinner = Badge(
        type: .weeklyWinner,
        name: "Weekly Champion",
        description: "First place in weekly leaderboard",
        icon: "trophy.fill",
        backgroundColor: .yellow,
        borderColor: .orange,
        iconColor: .white,
        isSpecial: true,
        isAnimated: true
    )
    
    static let monthlyChampion = Badge(
        type: .monthlyChampion,
        name: "Monthly Legend",
        description: "Top performer of the month",
        icon: "crown.fill",
        backgroundColor: .purple,
        borderColor: .pink,
        iconColor: .white,
        isSpecial: true,
        isAnimated: true
    )
    
    static let speedDemon = Badge(
        type: .achievement,
        name: "Speed Demon",
        description: "Reached 25+ km/h",
        icon: "speedometer",
        backgroundColor: .orange,
        borderColor: .red,
        iconColor: .white
    )
    
    static let marathoner = Badge(
        type: .achievement,
        name: "Marathoner",
        description: "10+ km in single game",
        icon: "figure.run",
        backgroundColor: .blue,
        borderColor: .cyan,
        iconColor: .white
    )
    
    static let consistent = Badge(
        type: .milestone,
        name: "Consistent Player",
        description: "Played 7 days in a row",
        icon: "calendar.badge.checkmark",
        backgroundColor: .green,
        borderColor: .mint,
        iconColor: .white
    )
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Single Badges
        HStack(spacing: 20) {
            BadgeView(badge: .weeklyWinner, size: .small)
            BadgeView(badge: .weeklyWinner, size: .medium)
            BadgeView(badge: .weeklyWinner, size: .large)
        }
        
        // Badge Collection
        BadgeCollectionView(
            badges: [
                .weeklyWinner,
                .monthlyChampion,
                .speedDemon,
                .marathoner,
                .consistent
            ],
            columns: 3
        )
        .padding()
        
        // Winner Celebration
        WeeklyWinnerCelebration(
            winnerName: "John Doe",
            badge: .weeklyWinner
        )
        .frame(height: 400)
        .cornerRadius(20)
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}