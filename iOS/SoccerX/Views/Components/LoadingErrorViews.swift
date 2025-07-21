import SwiftUI

struct LoadingView: View {
    let message: String
    let style: LoadingStyle
    
    init(message: String = "Loading...", style: LoadingStyle = .default) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch style {
            case .default:
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.green)
            case .soccer:
                SoccerBallLoadingView()
            case .minimal:
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
            }
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }
}

struct SoccerBallLoadingView: View {
    @State private var isRotating = false
    
    var body: some View {
        Image(systemName: "soccerball")
            .font(.system(size: 32, weight: .regular))
            .foregroundColor(.green)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

enum LoadingStyle {
    case `default`
    case soccer
    case minimal
}

struct ErrorView: View {
    let title: String
    let message: String
    let icon: String
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    init(
        title: String = "Something went wrong",
        message: String,
        icon: String = "exclamationmark.triangle",
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                if let retryAction = retryAction {
                    Button("Try Again") {
                        retryAction()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.green)
                    .cornerRadius(10)
                }
                
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.black.opacity(0.05))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        icon: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.green)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#Preview {
    TabView {
        LoadingView(message: "Loading games...", style: .soccer)
            .tabItem {
                Label("Loading", systemImage: "clock")
            }
        
        ErrorView(
            title: "Failed to load",
            message: "Unable to connect to the server. Please check your internet connection.",
            retryAction: {
                print("Retry tapped")
            },
            dismissAction: {
                print("Dismiss tapped")
            }
        )
        .tabItem {
            Label("Error", systemImage: "exclamationmark.triangle")
        }
        
        EmptyStateView(
            title: "No Games Yet",
            message: "Start tracking your first game to see your statistics here.",
            icon: "soccerball",
            actionTitle: "Start Game",
            action: {
                print("Start Game tapped")
            }
        )
        .tabItem {
            Label("Empty", systemImage: "tray")
        }
    }
    .preferredColorScheme(.dark)
}