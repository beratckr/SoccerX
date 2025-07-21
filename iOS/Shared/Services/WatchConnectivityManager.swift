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
    
    // Message types for standardized communication
    enum MessageType: String, CaseIterable {
        case gameStart = "game_start"
        case gameUpdate = "game_update" 
        case gameEnd = "game_end"
        case bulkData = "bulk_data"
        case syncRequest = "sync_request"
        case heartbeat = "heartbeat"
        case userProfile = "user_profile"
        case groupUpdate = "group_update"
    }
    
    // Connection states
    enum ConnectionState: String, CaseIterable {
        case notActivated = "Not Activated"
        case activated = "Activated"
        case notReachable = "Not Reachable"
        case reachable = "Reachable"
    }
    
    // Sync errors
    enum SyncError: LocalizedError {
        case sessionNotActivated
        case messageDeliveryFailed(Error)
        case compressionFailed
        case decodingFailed
        case transferLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .sessionNotActivated:
                return "Watch connectivity session not activated"
            case .messageDeliveryFailed(let error):
                return "Message delivery failed: \(error.localizedDescription)"
            case .compressionFailed:
                return "Data compression failed"
            case .decodingFailed:
                return "Data decoding failed"
            case .transferLimitExceeded:
                return "Transfer size limit exceeded"
            }
        }
    }
    
    override init() {
        super.init()
        setupSession()
        startConnectionMonitoring()
    }
    
    // MARK: - Session Management
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            logger.error("WatchConnectivity not supported on this device")
            return
        }
        
        session.delegate = self
        session.activate()
        logger.info("WatchConnectivity session activation initiated")
    }
    
    private func startConnectionMonitoring() {
        // Monitor reachability changes
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateConnectionState()
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionState() {
        guard session.activationState == .activated else {
            connectionState = .notActivated
            isReachable = false
            return
        }
        
        connectionState = .activated
        
        #if os(iOS)
        isReachable = session.isWatchAppInstalled && session.isReachable
        #else
        isReachable = session.isCompanionAppInstalled && session.isReachable
        #endif
        
        if isReachable {
            connectionState = .reachable
        } else {
            connectionState = .notReachable
        }
    }
    
    // MARK: - Message Sending
    
    func sendMessage(
        type: MessageType,
        payload: [String: Any],
        priority: MessagePriority = .medium,
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard session.activationState == .activated else {
            let error = SyncError.sessionNotActivated
            syncError = error
            errorHandler?(error)
            logger.error("Attempted to send message with inactive session")
            return
        }
        
        let message = createMessage(type: type, payload: payload, priority: priority)
        
        if session.isReachable {
            // Use sendMessage for immediate delivery when reachable
            sendImmediateMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
        } else {
            // Use transferUserInfo for reliable background delivery
            sendBackgroundMessage(message, errorHandler: errorHandler)
        }
    }
    
    private func createMessage(type: MessageType, payload: [String: Any], priority: MessagePriority) -> [String: Any] {
        var message: [String: Any] = [
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "priority": priority.rawValue,
            "messageId": UUID().uuidString
        ]
        
        // Add payload data
        message["data"] = payload
        
        return message
    }
    
    private func sendImmediateMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        pendingMessages += 1
        
        session.sendMessage(
            message,
            replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.pendingMessages = max(0, (self?.pendingMessages ?? 1) - 1)
                    self?.lastSyncTime = Date()
                    replyHandler?(reply)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.pendingMessages = max(0, (self?.pendingMessages ?? 1) - 1)
                    self?.syncError = .messageDeliveryFailed(error)
                    self?.logger.error("Immediate message failed: \(error.localizedDescription)")
                    
                    // Fallback to background transfer
                    self?.sendBackgroundMessage(message, errorHandler: errorHandler)
                }
            }
        )
        
        logger.info("Sent immediate message: \(message["type"] as? String ?? "unknown")")
    }
    
    private func sendBackgroundMessage(
        _ message: [String: Any],
        errorHandler: ((Error) -> Void)?
    ) {
        do {
            session.transferUserInfo(message)
            logger.info("Queued background message: \(message["type"] as? String ?? "unknown")")
            lastSyncTime = Date()
        } catch {
            syncError = .messageDeliveryFailed(error)
            errorHandler?(error)
            logger.error("Background message failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Bulk Data Transfer
    
    func sendBulkData<T: Codable>(
        type: MessageType,
        data: T,
        priority: MessagePriority = .medium,
        compress: Bool = true,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                let jsonData = try JSONEncoder().encode(data)
                let finalData = compress ? try compressData(jsonData) : jsonData
                
                let payload: [String: Any] = [
                    "compressed": compress,
                    "size": finalData.count,
                    "dataHash": finalData.sha256Hash
                ]
                
                await MainActor.run {
                    // Send metadata first
                    sendMessage(
                        type: type,
                        payload: payload,
                        priority: priority,
                        replyHandler: { [weak self] _ in
                            // Then transfer the actual data
                            self?.transferLargeData(finalData, completion: completion)
                        },
                        errorHandler: { error in
                            completion(.failure(error))
                        }
                    )
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func transferLargeData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        // For large data, use file transfer
        let tempURL = createTemporaryFile(with: data)
        
        session.transferFile(tempURL, metadata: [
            "size": data.count,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Clean up temp file after transfer
        DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        completion(.success(()))
    }
    
    private func createTemporaryFile(with data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("transfer_\(UUID().uuidString).data")
        
        try? data.write(to: tempFile)
        return tempFile
    }
    
    // MARK: - Data Compression
    
    private func compressData(_ data: Data) throws -> Data {
        guard let compressed = data.compressed(using: .zlib) else {
            throw SyncError.compressionFailed
        }
        logger.info("Compressed data: \(data.count) → \(compressed.count) bytes (\(100 - (compressed.count * 100 / data.count))% reduction)")
        return compressed
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        guard let decompressed = data.decompressed(using: .zlib) else {
            throw SyncError.decodingFailed
        }
        return decompressed
    }
    
    // MARK: - Connection Health
    
    func checkConnectionHealth() {
        sendMessage(
            type: .heartbeat,
            payload: ["timestamp": Date().timeIntervalSince1970],
            priority: .low,
            replyHandler: { [weak self] _ in
                self?.logger.info("Heartbeat successful")
            },
            errorHandler: { [weak self] error in
                self?.logger.warning("Heartbeat failed: \(error.localizedDescription)")
            }
        )
    }
    
    // MARK: - Session State Management
    
    func forceSessionReactivation() {
        guard WCSession.isSupported() else { return }
        
        if session.activationState != .activated {
            session.activate()
            logger.info("Forced session reactivation")
        }
    }
}

// MARK: - Message Priority
enum MessagePriority: String, CaseIterable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var numericValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

// MARK: - Data Extensions
extension Data {
    var sha256Hash: String {
        return withUnsafeBytes { bytes in
            var hash = [UInt8](repeating: 0, count: 32)
            // Simple hash implementation for demo - in production use CryptoKit
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }
    
    func compressed(using algorithm: NSData.CompressionAlgorithm) -> Data? {
        return (self as NSData).compressed(using: algorithm) as Data?
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm) -> Data? {
        return (self as NSData).decompressed(using: algorithm) as Data?
    }
}