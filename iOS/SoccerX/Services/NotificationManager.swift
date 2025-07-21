import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published var fcmToken: String?
    @Published var hasNotificationPermission = false
    @Published var notificationSettings = NotificationSettings()
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private let settingsKey = "notificationSettings"
    private let fcmTokenKey = "fcmToken"
    
    override private init() {
        super.init()
        loadSettings()
        setupMessaging()
        checkNotificationPermission()
    }
    
    // MARK: - Setup
    
    private func setupMessaging() {
        Messaging.messaging().delegate = self
        
        // Get FCM token
        Task {
            do {
                let token = try await Messaging.messaging().token()
                await MainActor.run {
                    self.fcmToken = token
                    self.userDefaults.set(token, forKey: fcmTokenKey)
                }
                print("FCM Token: \(token)")
            } catch {
                print("Error fetching FCM token: \(error)")
            }
        }
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.hasNotificationPermission = granted
            }
            
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasNotificationPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        saveSettings()
        
        // Update topic subscriptions
        updateTopicSubscriptions()
    }
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notificationSettings = settings
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(notificationSettings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    // MARK: - Topic Management
    
    private func updateTopicSubscriptions() {
        // Subscribe/unsubscribe from notification topics based on settings
        
        if notificationSettings.rankingChanges {
            Messaging.messaging().subscribe(toTopic: "ranking_changes")
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "ranking_changes")
        }
        
        if notificationSettings.weeklyWinners {
            Messaging.messaging().subscribe(toTopic: "weekly_winners")
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "weekly_winners")
        }
        
        if notificationSettings.newChallenges {
            Messaging.messaging().subscribe(toTopic: "new_challenges")
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "new_challenges")
        }
        
        if notificationSettings.groupUpdates {
            Messaging.messaging().subscribe(toTopic: "group_updates")
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "group_updates")
        }
    }
    
    func subscribeToGroup(_ groupId: String) {
        Messaging.messaging().subscribe(toTopic: "group_\(groupId)")
    }
    
    func unsubscribeFromGroup(_ groupId: String) {
        Messaging.messaging().unsubscribe(fromTopic: "group_\(groupId)")
    }
    
    // MARK: - Token Management
    
    func updateUserFCMToken() {
        guard let userId = Auth.auth().currentUser?.uid,
              let token = fcmToken else { return }
        
        // Update FCM token in user document
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.updateData(["fcmToken": token]) { error in
            if let error = error {
                print("Failed to update FCM token: \(error)")
            } else {
                print("FCM token updated successfully")
            }
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        badge: Int? = nil,
        userInfo: [AnyHashable: Any] = [:],
        delay: TimeInterval = 0
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        if let badge = badge {
            content.badge = NSNumber(value: badge)
        }
        
        let trigger = delay > 0 
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("Failed to set badge count: \(error)")
                }
            }
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - MessagingDelegate

extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        DispatchQueue.main.async {
            self.fcmToken = token
            self.userDefaults.set(token, forKey: self.fcmTokenKey)
            self.updateUserFCMToken()
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var enabled: Bool = true
    var rankingChanges: Bool = true
    var weeklyWinners: Bool = true
    var newChallenges: Bool = true
    var groupUpdates: Bool = true
    var gameReminders: Bool = true
    var achievementUnlocks: Bool = true
    
    // Frequency settings
    var rankingChangeFrequency: NotificationFrequency = .immediate
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
}

enum NotificationFrequency: String, Codable, CaseIterable {
    case immediate = "immediate"
    case hourly = "hourly"
    case daily = "daily"
    
    var displayName: String {
        switch self {
        case .immediate: return "Immediately"
        case .hourly: return "Hourly Summary"
        case .daily: return "Daily Summary"
        }
    }
}

// MARK: - Notification Payload Types

struct RankChangeNotification: Codable {
    let groupId: String
    let groupName: String
    let previousRank: Int
    let currentRank: Int
    let change: Int
}

struct WeeklyWinnerNotification: Codable {
    let groupId: String
    let groupName: String
    let winnerId: String
    let winnerName: String
    let badgeType: String
}

struct ChallengeNotification: Codable {
    let groupId: String
    let groupName: String
    let challengeTitle: String
    let challengeDescription: String
}

// MARK: - Deep Link Handler

extension NotificationManager {
    func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "rank_change":
            if let groupId = userInfo["groupId"] as? String {
                AppState.shared.handleDeepLink(
                    URL(string: "soccerx://leaderboard?groupId=\(groupId)")!
                )
            }
            
        case "weekly_winner":
            if let groupId = userInfo["groupId"] as? String {
                AppState.shared.handleDeepLink(
                    URL(string: "soccerx://leaderboard?groupId=\(groupId)")!
                )
            }
            
        case "new_challenge":
            if let groupId = userInfo["groupId"] as? String {
                AppState.shared.handleDeepLink(
                    URL(string: "soccerx://group?id=\(groupId)")!
                )
            }
            
        case "group_update":
            if let groupId = userInfo["groupId"] as? String {
                AppState.shared.handleDeepLink(
                    URL(string: "soccerx://group?id=\(groupId)")!
                )
            }
            
        default:
            break
        }
    }
}