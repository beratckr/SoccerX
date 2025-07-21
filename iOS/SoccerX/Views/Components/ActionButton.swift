import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String?
    let style: ActionButtonStyle
    let size: ActionButtonSize
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ActionButtonStyle = .primary,
        size: ActionButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: size.fontSize, weight: .semibold))
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(style.backgroundColor)
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
        }
    }
}

enum ActionButtonStyle {
    case primary
    case secondary
    case destructive
    case success
    case outline
    case ghost
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return .green
        case .secondary:
            return .gray
        case .destructive:
            return .red
        case .success:
            return .green
        case .outline:
            return Color.clear
        case .ghost:
            return Color.clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive, .success:
            return .white
        case .secondary:
            return .primary
        case .outline:
            return .green
        case .ghost:
            return .primary
        }
    }
    
    var borderColor: Color {
        switch self {
        case .outline:
            return .green
        default:
            return Color.clear
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .outline:
            return 1.5
        default:
            return 0
        }
    }
}

enum ActionButtonSize {
    case small
    case medium
    case large
    case extraLarge
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 20
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 20
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .extraLarge: return 24
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        case .extraLarge: return 20
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        case .extraLarge: return 14
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ActionButton("Start Game", icon: "play.fill", style: .primary, size: .large) {
            print("Start Game tapped")
        }
        
        ActionButton("Join Group", icon: "person.3", style: .outline, size: .medium) {
            print("Join Group tapped")
        }
        
        ActionButton("Delete", icon: "trash", style: .destructive, size: .small) {
            print("Delete tapped")
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}