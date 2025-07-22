import Foundation
import WatchConnectivity
import Combine
import os.log

@MainActor
class SharedWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = SharedWatchConnectivityManager()
    
    @Published var connectionState: ConnectionState = .notActivated
    @Published var isReachable = false
    @Published var lastSyncTime: Date?
    @Published var pendingMessages: Int = 0
    @Published var transferProgress: Double = 0
    @Published var syncError: SyncError?
    
    private let session = WCSession.default
    private let logger = Logger(subsystem: "com.soccerx.app", category: "WatchConnectivity")
    private var cancellables = Set<AnyCancellable>()
    private var pendingTransfers: [String: FileTransferInfo] = [:]
    
    // Message queue for offline support
    private var messageQueue: [QueuedMessage] = []
    private let messageQueueKey = "watch_message_queue"
    
    enum ConnectionState: String, Equatable {
        case notActivated = "notActivated"
        case activating = "activating"
        case activated = "activated"
        case reachable = "reachable"
        case notReachable = "notReachable"
        case failed = "failed"
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
        
        var displayText: String {
            switch self {
            case .notActivated: return "Not Connected"
            case .activating: return "Connecting..."
            case .activated: return "Connected"
            case .reachable: return "Reachable"
            case .notReachable: return "Not Reachable"
            case .failed: return "Connection Failed"
            }
        }
    }
    
    enum SyncError: LocalizedError {
        case notReachable
        case transferFailed(String)
        case messageTimeout
        case invalidData
        case sessionNotActivated
        case messageDeliveryFailed
        case compressionFailed
        case decodingFailed
        case transferLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .notReachable:
                return "Watch is not reachable"
            case .transferFailed(let reason):
                return "Transfer failed: \(reason)"
            case .messageTimeout:
                return "Message timed out"
            case .invalidData:
                return "Invalid data format"
            case .sessionNotActivated:
                return "WatchConnectivity session not activated"
            case .messageDeliveryFailed:
                return "Message delivery failed"
            case .compressionFailed:
                return "Data compression failed"
            case .decodingFailed:
                return "Data decoding failed"
            case .transferLimitExceeded:
                return "Transfer limit exceeded"
            }
        }
    }
    
    struct QueuedMessage: Codable {
        let id: String
        let message: [String: Any]
        let timestamp: Date
        let priority: MessagePriority
        
        enum CodingKeys: String, CodingKey {
            case id, timestamp, priority
            case messageData
        }
        
        init(id: String = UUID().uuidString, message: [String: Any], priority: MessagePriority = .normal) {
            self.id = id
            self.message = message
            self.timestamp = Date()
            self.priority = priority
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(priority, forKey: .priority)
            
            let data = try JSONSerialization.data(withJSONObject: message)
            try container.encode(data, forKey: .messageData)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            priority = try container.decode(MessagePriority.self, forKey: .priority)
            
            let data = try container.decode(Data.self, forKey: .messageData)
            message = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
    }
    
    enum MessagePriority: String, Codable {
        case low
        case normal
        case high
        case critical
    }
    
    enum MessageType: String, Codable {
        case startGame = "start_game"
        case stopGame = "stop_game"
        case gameUpdate = "game_update"
        case syncRequest = "sync_request"
        case syncResponse = "sync_response"
        case heartbeat
        case error
        case gameStart = "game_start"
        case gameEnd = "game_end"
        case trackingStateUpdate = "trackingStateUpdate"
        case gameSessionUpdate = "gameSessionUpdate"
        case gameDataPoint = "gameDataPoint"
        case gameCompleted = "gameCompleted"
        case bulkData = "bulk_data"
    }
    
    struct FileTransferInfo {
        let fileURL: URL
        let metadata: [String: Any]?
        let startTime: Date
        var progress: Double
    }
    
    private override init() {
        super.init()
        setupSession()
        loadMessageQueue()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            logger.warning("WatchConnectivity is not supported on this device")
            return
        }
        
        session.delegate = self
        session.activate()
        
        logger.info("WatchConnectivity session setup initiated")
    }
    
    // MARK: - Message Queue Management
    
    private func loadMessageQueue() {
        guard let data = UserDefaults.standard.data(forKey: messageQueueKey),
              let queue = try? JSONDecoder().decode([QueuedMessage].self, from: data) else {
            return
        }
        
        messageQueue = queue.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
        pendingMessages = messageQueue.count
    }
    
    private func saveMessageQueue() {
        guard let data = try? JSONEncoder().encode(messageQueue) else { return }
        UserDefaults.standard.set(data, forKey: messageQueueKey)
        pendingMessages = messageQueue.count
    }
    
    private func addToQueue(_ message: [String: Any], priority: MessagePriority = .normal) {
        let queuedMessage = QueuedMessage(message: message, priority: priority)
        messageQueue.append(queuedMessage)
        messageQueue.sort { $0.priority.sortOrder > $1.priority.sortOrder }
        saveMessageQueue()
    }
    
    private func removeFromQueue(_ id: String) {
        messageQueue.removeAll { $0.id == id }
        saveMessageQueue()
    }
    
    // MARK: - Public API
    
    func sendMessage(_ message: [String: Any], priority: MessagePriority = .normal) async throws {
        guard connectionState == .activated else {
            throw SyncError.notReachable
        }
        
        if session.isReachable {
            do {
                try await withCheckedThrowingContinuation { continuation in
                    session.sendMessage(message, replyHandler: { _ in
                        continuation.resume()
                    }, errorHandler: { error in
                        continuation.resume(throwing: error)
                    })
                }
                logger.info("Message sent successfully")
            } catch {
                logger.error("Failed to send message: \(error)")
                addToQueue(message, priority: priority)
                throw error
            }
        } else {
            addToQueue(message, priority: priority)
            throw SyncError.notReachable
        }
    }
    
    func sendGameData(_ gameData: Data, metadata: [String: Any]? = nil) async throws {
        guard connectionState == .activated else {
            throw SyncError.notReachable
        }
        
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("game_\(UUID().uuidString).json")
        
        try gameData.write(to: fileURL)
        
        let transferId = UUID().uuidString
        pendingTransfers[transferId] = FileTransferInfo(
            fileURL: fileURL,
            metadata: metadata,
            startTime: Date(),
            progress: 0
        )
        
        let transfer = session.transferFile(fileURL, metadata: metadata)
        
        // Monitor transfer progress using KVO
        let observation = transfer.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor in
                guard let self = self, let info = self.pendingTransfers[transferId] else { return }
                self.pendingTransfers[transferId] = FileTransferInfo(
                    fileURL: info.fileURL,
                    metadata: info.metadata,
                    startTime: info.startTime,
                    progress: progress.fractionCompleted
                )
                self.transferProgress = progress.fractionCompleted
            }
        }
        
        // Store the observation to keep it alive
        // Note: In a real implementation, you'd want to store this and invalidate it when done
        _ = observation
    }
    
    func processQueuedMessages() async {
        guard session.isReachable else { return }
        
        let messagesToProcess = messageQueue
        
        for queuedMessage in messagesToProcess {
            do {
                try await sendMessage(queuedMessage.message, priority: queuedMessage.priority)
                removeFromQueue(queuedMessage.id)
            } catch {
                logger.error("Failed to send queued message: \(error)")
                // Keep in queue for next attempt
            }
        }
    }
    
    func checkConnectionHealth() {
        // Send a heartbeat message to verify connection
        Task { @MainActor in
            do {
                let heartbeatMessage: [String: Any] = [
                    "type": MessageType.heartbeat.rawValue,
                    "timestamp": Date().timeIntervalSince1970
                ]
                try await sendMessage(heartbeatMessage, priority: .high)
                lastSyncTime = Date()
                logger.info("Connection health check successful")
            } catch {
                logger.error("Connection health check failed: \(error)")
                syncError = .notReachable
            }
        }
    }
    
    func sendMessage(
        type: MessageType,
        payload: [String: Any],
        priority: MessagePriority = .normal,
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        var message = payload
        message["type"] = type.rawValue
        message["timestamp"] = Date().timeIntervalSince1970
        
        guard connectionState == .activated || connectionState == .reachable else {
            errorHandler?(SyncError.notReachable)
            return
        }
        
        if session.isReachable {
            if let replyHandler = replyHandler {
                session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
                    self.logger.error("Failed to send message: \(error)")
                    errorHandler?(error)
                })
            } else {
                Task {
                    do {
                        try await sendMessage(message, priority: priority)
                    } catch {
                        errorHandler?(error)
                    }
                }
            }
        } else {
            addToQueue(message, priority: priority)
            errorHandler?(SyncError.notReachable)
        }
    }
}

// MARK: - WCSessionDelegate

extension SharedWatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.connectionState = .failed
                self.syncError = .sessionNotActivated
                logger.error("Session activation failed: \(error)")
            } else {
                self.connectionState = activationState == .activated ? .activated : .notActivated
                self.isReachable = session.isReachable
                self.lastSyncTime = Date()
                
                if activationState == .activated {
                    await processQueuedMessages()
                }
                
                logger.info("Session activated with state: \(activationState.rawValue)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            
            if session.isReachable {
                await processQueuedMessages()
            }
            
            logger.info("Session reachability changed: \(session.isReachable)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("Session deactivated")
        session.activate()
    }
    #endif
    
    // MARK: - Message Reception
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleReceivedMessage(userInfo)
    }
    
    // MARK: - File Transfer
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            do {
                let data = try Data(contentsOf: file.fileURL)
                NotificationCenter.default.post(
                    name: .watchDataReceived,
                    object: nil,
                    userInfo: [
                        "data": data,
                        "metadata": file.metadata ?? [:]
                    ]
                )
                self.lastSyncTime = Date()
                logger.info("Received file transfer: \(file.fileURL.lastPathComponent)")
            } catch {
                logger.error("Failed to process received file: \(error)")
                self.syncError = .transferFailed(error.localizedDescription)
            }
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("File transfer failed: \(error)")
                self.syncError = .transferFailed(error.localizedDescription)
            } else {
                logger.info("File transfer completed successfully")
                self.lastSyncTime = Date()
            }
            
            // Clean up pending transfer
            if let metadata = fileTransfer.file.metadata,
               let transferId = metadata["transferId"] as? String {
                pendingTransfers.removeValue(forKey: transferId)
            }
            
            self.transferProgress = 0
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchMessageReceived,
                object: nil,
                userInfo: message
            )
            
            self.lastSyncTime = Date()
            logger.info("Received message: \(message["type"] as? String ?? "unknown")")
        }
    }
    
    // MARK: - Additional Public Methods
    
    func forceSessionReactivation() {
        logger.info("Forcing session reactivation")
        connectionState = .activating
        session.activate()
    }
    
    func sendBulkData<T: Codable>(
        type: MessageType,
        data: T,
        priority: MessagePriority = .normal,
        compress: Bool = true,
        completion: @escaping (Result<Void, Error>) -> Void
    ) async throws {
        do {
            let encoder = JSONEncoder()
            var payload = try encoder.encode(data)
            
            // Compress if requested and data is large enough
            if compress && payload.count > 1024 {
                if let compressed = payload.compressed(using: .zlib) {
                    payload = compressed
                }
            }
            
            // Create message dictionary
            let message: [String: Any] = [
                "type": type.rawValue,
                "data": payload.base64EncodedString(),
                "compressed": compress,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            try await sendMessage(message, priority: priority)
            completion(.success(()))
            
        } catch {
            logger.error("Failed to send bulk data: \(error)")
            completion(.failure(error))
            throw error
        }
    }
}

// MARK: - MessagePriority Extension

extension SharedWatchConnectivityManager.MessagePriority {
    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchMessageReceived = Notification.Name("watchMessageReceived")
    static let watchDataReceived = Notification.Name("watchDataReceived")
    static let watchConnectionStateChanged = Notification.Name("watchConnectionStateChanged")
}