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
            default:
                self.logger.debug("Received message of type: \(messageType.rawValue)")
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