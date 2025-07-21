import SwiftUI

struct NavigationHeaderView: View {
    let title: String
    let subtitle: String?
    let showBackButton: Bool
    let rightAction: NavigationAction?
    let backAction: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        showBackButton: Bool = false,
        rightAction: NavigationAction? = nil,
        backAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.rightAction = rightAction
        self.backAction = backAction
    }
    
    var body: some View {
        HStack {
            if showBackButton {
                Button(action: backAction ?? {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let rightAction = rightAction {
                Button(action: rightAction.action) {
                    if let icon = rightAction.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    } else if let text = rightAction.text {
                        Text(text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct NavigationAction {
    let icon: String?
    let text: String?
    let action: () -> Void
    
    init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.text = nil
        self.action = action
    }
    
    init(text: String, action: @escaping () -> Void) {
        self.icon = nil
        self.text = text
        self.action = action
    }
}

struct CompactHeaderView: View {
    let title: String
    let leftAction: NavigationAction?
    let rightAction: NavigationAction?
    
    init(
        title: String,
        leftAction: NavigationAction? = nil,
        rightAction: NavigationAction? = nil
    ) {
        self.title = title
        self.leftAction = leftAction
        self.rightAction = rightAction
    }
    
    var body: some View {
        HStack {
            if let leftAction = leftAction {
                Button(action: leftAction.action) {
                    if let icon = leftAction.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    } else if let text = leftAction.text {
                        Text(text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let rightAction = rightAction {
                Button(action: rightAction.action) {
                    if let icon = rightAction.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    } else if let text = rightAction.text {
                        Text(text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            } else {
                Spacer()
                    .frame(width: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
}

// Note: SectionHeaderView is defined in SectionHeaderView.swift

struct ProfileHeaderView: View {
    let name: String
    let subtitle: String
    let profileImageURL: String?
    let action: NavigationAction?
    
    init(
        name: String,
        subtitle: String,
        profileImageURL: String? = nil,
        action: NavigationAction? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.profileImageURL = profileImageURL
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let action = action {
                Button(action: action.action) {
                    if let icon = action.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    } else if let text = action.text {
                        Text(text)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SearchHeaderView: View {
    @Binding var searchText: String
    let placeholder: String
    let showCancelButton: Bool
    let onCancel: () -> Void
    
    init(
        searchText: Binding<String>,
        placeholder: String = "Search...",
        showCancelButton: Bool = true,
        onCancel: @escaping () -> Void = {}
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.showCancelButton = showCancelButton
        self.onCancel = onCancel
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if showCancelButton && !searchText.isEmpty {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        NavigationHeaderView(
            title: "Dashboard",
            subtitle: "Welcome back, John!",
            rightAction: NavigationAction(icon: "gear") {
                print("Settings tapped")
            }
        )
        
        NavigationHeaderView(
            title: "Game Details",
            showBackButton: true,
            rightAction: NavigationAction(text: "Edit") {
                print("Edit tapped")
            },
            backAction: {
                print("Back tapped")
            }
        )
        
        CompactHeaderView(
            title: "Groups",
            leftAction: NavigationAction(icon: "person.crop.circle.badge.plus") {
                print("Invite tapped")
            },
            rightAction: NavigationAction(icon: "plus") {
                print("Add tapped")
            }
        )
        
        SectionHeaderView(
            title: "Recent Games",
            action: SectionAction(text: "See All") {
                print("See All tapped")
            }
        )
        
        ProfileHeaderView(
            name: "John Doe",
            subtitle: "Level 15 • 127 games",
            action: NavigationAction(icon: "gear") {
                print("Settings tapped")
            }
        )
        
        SearchHeaderView(
            searchText: .constant(""),
            placeholder: "Search games..."
        )
        
        Spacer()
    }
    .preferredColorScheme(.dark)
}