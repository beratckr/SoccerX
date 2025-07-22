import Foundation
import WatchConnectivity
import Combine
import os.log

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var connectionState: ConnectionState = .notActivated
    @Published var isReachable = false
    @Published var lastSyncTime: Date?
    @Published var pendingMessages: Int = 0
    @Published var transferProgress: Double = 0
    @Published var syncError: SyncError?
    @Published var activeGameSession: ActiveGameSession?
    @Published var latestGameStats: GameStats?
    
    private let session = WCSession.default
    private let logger = Logger(subsystem: "com.soccerx.app", category: "WatchConnectivity")
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionState: String, CaseIterable {
        case notActivated = "Not Activated"
        case inactive = "Inactive"
        case activated = "Activated"
        case unknown = "Unknown"
    }
    
    enum MessageType: String, CaseIterable {
        case startGame = "start_game"
        case stopGame = "stop_game"
        case gameUpdate = "game_update"
        case syncRequest = "sync_request"
        case syncResponse = "sync_response"
        case trackingStateUpdate = "trackingStateUpdate"
        case gameSessionUpdate = "gameSessionUpdate"
        case gameDataPoint = "gameDataPoint"
        case gameCompleted = "gameCompleted"
    }
    
    enum MessagePriority: Int, CaseIterable {
        case critical = 0
        case high = 1
        case medium = 2
        case low = 3
    }
    
    enum SyncError: Error, LocalizedError {
        case sessionNotActivated
        case messageDeliveryFailed(String)
        case dataTransferFailed(String)
        case connectionTimeout
        case watchNotPaired
        
        var errorDescription: String? {
            switch self {
            case .sessionNotActivated:
                return "Watch connectivity session not activated"
            case .messageDeliveryFailed(let message):
                return "Failed to deliver message: \(message)"
            case .dataTransferFailed(let error):
                return "Data transfer failed: \(error)"
            case .connectionTimeout:
                return "Connection timeout"
            case .watchNotPaired:
                return "Apple Watch not paired"
            }
        }
    }
    
    struct ActiveGameSession {
        let id: String
        let startTime: Date
        var distance: Double
        var calories: Double
        var avgHeartRate: Int
        var maxHeartRate: Int
        var avgSpeed: Double
        var maxSpeed: Double
        var duration: TimeInterval
        var dataPoints: [GameDataPoint] = []
        
        init(from message: [String: Any]) {
            self.id = message["sessionId"] as? String ?? UUID().uuidString
            self.startTime = Date(timeIntervalSince1970: message["startTime"] as? TimeInterval ?? Date().timeIntervalSince1970)
            self.distance = message["distance"] as? Double ?? 0
            self.calories = message["calories"] as? Double ?? 0
            self.avgHeartRate = message["avgHeartRate"] as? Int ?? 0
            self.maxHeartRate = message["maxHeartRate"] as? Int ?? 0
            self.avgSpeed = message["avgSpeed"] as? Double ?? 0
            self.maxSpeed = message["maxSpeed"] as? Double ?? 0
            self.duration = message["duration"] as? TimeInterval ?? 0
        }
    }
    
    struct GameDataPoint {
        let timestamp: Date
        let heartRate: Int
        let speed: Double
        let distance: Double
        let calories: Double
        let altitude: Double
        let latitude: Double
        let longitude: Double
        
        init(from message: [String: Any]) {
            self.timestamp = Date(timeIntervalSince1970: message["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970)
            self.heartRate = message["heartRate"] as? Int ?? 0
            self.speed = message["speed"] as? Double ?? 0
            self.distance = message["distance"] as? Double ?? 0
            self.calories = message["calories"] as? Double ?? 0
            self.altitude = message["altitude"] as? Double ?? 0
            self.latitude = message["latitude"] as? Double ?? 0
            self.longitude = message["longitude"] as? Double ?? 0
        }
    }
    
    struct GameStats {
        let distance: Double
        let duration: Int
        let avgSpeed: Double
        let maxSpeed: Double
        let calories: Int
        let avgHeartRate: Int
        let maxHeartRate: Int
    }
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            logger.error("WatchConnectivity not supported on this device")
            return
        }
        
        session.delegate = self
        session.activate()
        logger.info("WatchConnectivity session activation requested")
    }
}

// MARK: - Public API
extension WatchConnectivityManager {
    
    func startGame(gameId: String) async throws {
        let message = [
            "type": MessageType.startGame.rawValue,
            "gameId": gameId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        try await sendMessage(message, priority: .critical)
        logger.info("Game start command sent to Watch: \(gameId)")
    }
    
    func stopGame(gameId: String) async throws {
        let message = [
            "type": MessageType.stopGame.rawValue,
            "gameId": gameId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        try await sendMessage(message, priority: .critical)
        logger.info("Game stop command sent to Watch: \(gameId)")
    }
    
    func sendGameUpdate(gameId: String, data: [String: Any]) async throws {
        var message = data
        message["type"] = MessageType.gameUpdate.rawValue
        message["gameId"] = gameId
        message["timestamp"] = Date().timeIntervalSince1970
        
        try await sendMessage(message, priority: .high)
        logger.debug("Game update sent to Watch: \(gameId)")
    }
    
    func requestSync() async throws {
        let message = [
            "type": MessageType.syncRequest.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        try await sendMessage(message, priority: .medium)
        logger.info("Sync request sent to Watch")
    }
}

// MARK: - Message Sending
extension WatchConnectivityManager {
    
    private func sendMessage(_ message: [String: Any], priority: MessagePriority) async throws {
        guard connectionState == .activated else {
            throw SyncError.sessionNotActivated
        }
        
        // Try immediate delivery first if reachable
        if isReachable {
            do {
                try await sendMessageImmediate(message)
                return
            } catch {
                logger.warning("Immediate message failed, falling back to background transfer: \(error)")
            }
        }
        
        // Fallback to background transfer
        try await sendBackgroundTransfer(message)
    }
    
    private func sendMessageImmediate(_ message: [String: Any]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { reply in
                self.logger.debug("Message sent successfully with reply: \(reply)")
                continuation.resume()
            }, errorHandler: { error in
                self.logger.error("Message send failed: \(error.localizedDescription)")
                continuation.resume(throwing: SyncError.messageDeliveryFailed(error.localizedDescription))
            })
        }
    }
    
    private func sendBackgroundTransfer(_ message: [String: Any]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            session.transferUserInfo(message)
            self.logger.info("Background transfer initiated")
            continuation.resume()
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: @preconcurrency WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.connectionState = .activated
                self.logger.info("WatchConnectivity session activated")
            case .inactive:
                self.connectionState = .inactive
                self.logger.warning("WatchConnectivity session inactive")
            case .notActivated:
                self.connectionState = .notActivated
                self.logger.error("WatchConnectivity session not activated")
            @unknown default:
                self.connectionState = .unknown
                self.logger.error("WatchConnectivity session unknown state")
            }
            
            self.isReachable = session.isReachable
            
            if let error = error {
                self.logger.error("WatchConnectivity activation error: \(error.localizedDescription)")
                self.syncError = .sessionNotActivated
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionState = .inactive
            self.isReachable = false
            self.logger.info("WatchConnectivity session became inactive")
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionState = .notActivated
            self.isReachable = false
            self.logger.info("WatchConnectivity session deactivated")
        }
        
        // Reactivate session for iOS
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.logger.info("WatchConnectivity reachability changed: \(self.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        
        // Send acknowledgment
        let reply = [
            "status": "received",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        replyHandler(reply)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let typeString = message["type"] as? String,
              let messageType = MessageType(rawValue: typeString) else {
            logger.warning("Received message with unknown type: \(message)")
            return
        }
        
        DispatchQueue.main.async {
            switch messageType {
            case .syncResponse:
                self.handleSyncResponse(message)
            case .gameUpdate:
                self.handleGameUpdate(message)
            case .trackingStateUpdate:
                self.handleTrackingStateUpdate(message)
            case .gameSessionUpdate:
                self.handleGameSessionUpdate(message)
            case .gameDataPoint:
                self.handleGameDataPoint(message)
            case .gameCompleted:
                self.handleGameCompleted(message)
            default:
                // Handle non-enum message types
                if let type = message["type"] as? String, type == "pendingGameData" {
                    self.handlePendingGameData(message)
                } else {
                    self.logger.debug("Received message of type: \(messageType.rawValue)")
                }
            }
            
            self.lastSyncTime = Date()
        }
    }
    
    private func handleSyncResponse(_ message: [String: Any]) {
        logger.info("Received sync response from Watch")
        // Process sync data here
    }
    
    private func handleGameUpdate(_ message: [String: Any]) {
        guard let gameId = message["gameId"] as? String else {
            logger.warning("Game update missing gameId")
            return
        }
        
        logger.debug("Received game update for: \(gameId)")
        // Process game update here
    }
    
    private func handleTrackingStateUpdate(_ message: [String: Any]) {
        if let state = message["state"] as? String {
            logger.info("Watch tracking state: \(state)")
            // Update UI or send notifications based on state
            NotificationCenter.default.post(
                name: Notification.Name("WatchTrackingStateChanged"),
                object: nil,
                userInfo: ["state": state]
            )
        }
    }
    
    private func handleGameSessionUpdate(_ message: [String: Any]) {
        activeGameSession = ActiveGameSession(from: message)
        logger.info("Game session updated: \(self.activeGameSession?.id ?? "unknown")")
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: Notification.Name("ActiveGameSessionUpdated"),
            object: nil,
            userInfo: ["session": activeGameSession as Any]
        )
    }
    
    private func handleGameDataPoint(_ message: [String: Any]) {
        let dataPoint = GameDataPoint(from: message)
        activeGameSession?.dataPoints.append(dataPoint)
        
        // Update real-time stats
        if let session = activeGameSession {
            updateRealTimeStats(with: dataPoint, session: session)
        }
        
        logger.debug("Game data point received")
    }
    
    private func handleGameCompleted(_ message: [String: Any]) {
        guard let sessionId = message["sessionId"] as? String,
              let sessionDataString = message["sessionData"] as? String,
              let sessionData = Data(base64Encoded: sessionDataString) else {
            logger.error("Invalid game completed message format")
            return
        }
        
        // Process completed game
        processCompletedGame(sessionId: sessionId, data: sessionData)
        
        // Clear active session
        activeGameSession = nil
        
        logger.info("Game completed: \(sessionId)")
    }
    
    private func updateRealTimeStats(with dataPoint: GameDataPoint, session: ActiveGameSession) {
        // Update session with latest data
        activeGameSession?.distance = dataPoint.distance
        activeGameSession?.calories = dataPoint.calories
        
        // Update heart rate stats
        if dataPoint.heartRate > 0 {
            if dataPoint.heartRate > session.maxHeartRate {
                activeGameSession?.maxHeartRate = dataPoint.heartRate
            }
        }
        
        // Update speed stats
        if dataPoint.speed > session.maxSpeed {
            activeGameSession?.maxSpeed = dataPoint.speed
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: Notification.Name("GameDataPointReceived"),
            object: nil,
            userInfo: ["dataPoint": dataPoint]
        )
    }
    
    private func processCompletedGame(sessionId: String, data: Data) {
        // Decode session data
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Here you would decode and save to Core Data or Firebase
            
            // Update latest game stats
            if let session = activeGameSession {
                latestGameStats = GameStats(
                    distance: session.distance,
                    duration: Int(session.duration),
                    avgSpeed: session.avgSpeed,
                    maxSpeed: session.maxSpeed,
                    calories: Int(session.calories),
                    avgHeartRate: session.avgHeartRate,
                    maxHeartRate: session.maxHeartRate
                )
            }
            
            // Post notification
            NotificationCenter.default.post(
                name: Notification.Name("GameCompleted"),
                object: nil,
                userInfo: ["sessionId": sessionId, "stats": latestGameStats as Any]
            )
        } catch {
            logger.error("Error decoding completed game session: \(error)")
        }
    }
    
    private func handlePendingGameData(_ message: [String: Any]) {
        guard let dataString = message["data"] as? String,
              let data = Data(base64Encoded: dataString) else {
            logger.error("Invalid pending game data format")
            return
        }
        
        // Save pending data using persistence manager
        do {
            let sessionId = UUID().uuidString // Generate new ID for pending data
            try GameDataPersistenceManager.shared.savePendingGameData(data, sessionId: sessionId)
            logger.info("Saved pending game data for later sync")
            
            // Trigger sync attempt
            Task {
                await GameDataPersistenceManager.shared.syncPendingData()
            }
        } catch {
            logger.error("Failed to save pending game data: \(error)")
        }
    }
}

// MARK: - Connection Management
extension WatchConnectivityManager {
    
    func checkConnectionHealth() {
        isReachable = session.isReachable
        logger.info("Connection health checked - reachable: \(self.isReachable)")
    }
    
    func forceSessionReactivation() {
        if WCSession.isSupported() {
            session.activate()
            logger.info("Session reactivation requested")
        }
    }
    
    var isPaired: Bool {
        return session.isPaired
    }
    
    var isWatchAppInstalled: Bool {
        return session.isWatchAppInstalled
    }
}