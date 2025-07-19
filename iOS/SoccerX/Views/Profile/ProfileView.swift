import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Overview
                    statsOverview
                    
                    // Achievements
                    achievementsSection
                    
                    // Settings & Actions
                    settingsSection
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                }
                .padding(.horizontal, 20)
            }
            .background(Color.black)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .foregroundColor(.green)
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Picture
            Button(action: {
                showingEditProfile = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5).opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    if let user = authService.currentUser {
                        Text(String(user.displayName?.first ?? "U").uppercased())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                    
                    // Edit indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                        .offset(x: 35, y: 35)
                }
            }
            
            // Name and details
            VStack(spacing: 4) {
                Text(authService.currentUser?.displayName ?? "Soccer Player")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Member since July 2024")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Premium Badge
                HStack(spacing: 8) {
                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    
                    Text("Premium Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 20)
    }
    
    private var statsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                statCard(icon: "figure.run", title: "Total Games", value: "47", subtitle: "This season")
                statCard(icon: "map", title: "Total Distance", value: "245.8 km", subtitle: "All time")
                statCard(icon: "clock", title: "Total Time", value: "52h 30m", subtitle: "Playing time")
                statCard(icon: "flame.fill", title: "Calories", value: "24,850", subtitle: "Burned")
            }
        }
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to achievements
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    achievementBadge(icon: "🏆", title: "First Goal", description: "Score your first goal")
                    achievementBadge(icon: "⚡", title: "Speed Demon", description: "Reach 25+ km/h")
                    achievementBadge(icon: "🔥", title: "Hot Streak", description: "5 games in a week")
                    achievementBadge(icon: "📏", title: "Marathon", description: "Run 10km in a game")
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            settingRow(icon: "bell", title: "Notifications", action: {})
            settingRow(icon: "heart", title: "Health & Fitness", action: {})
            settingRow(icon: "questionmark.circle", title: "Help & Support", action: {})
            settingRow(icon: "info.circle", title: "About", action: {})
            
            Divider()
                .background(Color(.systemGray5).opacity(0.3))
                .padding(.vertical, 8)
            
            Button("Sign Out") {
                authService.signOut()
            }
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func statCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private func achievementBadge(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.largeTitle)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 120)
        .padding(12)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
    
    private func settingRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Placeholder Views
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings Feature")
                    .font(.title)
                    .padding()
                
                Text("Coming Soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Sign Out") {
                    authService.signOut()
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Profile Feature")
                    .font(.title)
                    .padding()
                
                Text("Coming Soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService())
        .preferredColorScheme(.dark)
}