import Foundation
import Combine
import os.log

@MainActor
class RealTimeDataTransfer: ObservableObject {
    @Published var activeTransfers: [String: TransferSession] = [:]
    @Published var transferRate: Double = 0 // Messages per second
    @Published var connectionQuality: ConnectionQuality = .none
    @Published var isTransferring = false
    
    private let connectivityManager = SharedWatchConnectivityManager.shared
    private let logger = Logger(subsystem: "com.soccerx.app", category: "RealTimeTransfer")
    private var cancellables = Set<AnyCancellable>()
    private var transferTimer: Timer?
    private var recentTransfers: [Date] = []
    
    // Transfer configuration
    private let maxConcurrentTransfers = 3
    private let transferTimeoutInterval: TimeInterval = 30
    private let rateCalculationWindow: TimeInterval = 10
    
    init() {
        setupMonitoring()
        startTransferRateMonitoring()
    }
    
    // MARK: - Setup and Monitoring
    
    private func setupMonitoring() {
        // Monitor connection state changes
        connectivityManager.$connectionState
            .sink { [weak self] state in
                self?.updateConnectionQuality(for: state)
            }
            .store(in: &cancellables)
        
        // Monitor reachability changes
        connectivityManager.$isReachable
            .sink { [weak self] isReachable in
                if !isReachable {
                    self?.pauseActiveTransfers()
                } else {
                    self?.resumeActiveTransfers()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionQuality(for state: SharedWatchConnectivityManager.ConnectionState) {
        switch state {
        case .reachable:
            connectionQuality = .excellent
        case .activated:
            connectionQuality = .good
        case .notReachable:
            connectionQuality = .poor
        case .notActivated, .activating:
            connectionQuality = .none
        case .failed:
            connectionQuality = .none
        }
    }
    
    private func startTransferRateMonitoring() {
        transferTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTransferRate()
                self?.cleanupExpiredTransfers()
            }
        }
    }
    
    private func updateTransferRate() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-rateCalculationWindow)
        
        // Remove old transfers
        recentTransfers = recentTransfers.filter { $0 > cutoff }
        
        // Calculate rate
        transferRate = Double(recentTransfers.count) / rateCalculationWindow
        
        // Update connection quality based on transfer rate
        updateConnectionQualityFromRate()
    }
    
    private func updateConnectionQualityFromRate() {
        if transferRate > 5 {
            connectionQuality = .excellent
        } else if transferRate > 3 {
            connectionQuality = .good
        } else if transferRate > 1 {
            connectionQuality = .fair
        } else if transferRate > 0 {
            connectionQuality = .poor
        } else {
            connectionQuality = .none
        }
    }
    
    // MARK: - Game Data Transfer
    
    func sendGameStart(gameData: GameSyncData) async throws {
        let transferId = "game_start_\(gameData.gameId.uuidString)"
        
        let payload: [String: Any] = [
            "gameId": gameData.gameId.uuidString,
            "userId": gameData.userId,
            "startTime": gameData.startTime.timeIntervalSince1970,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        try await sendRealTimeMessage(
            transferId: transferId,
            type: .gameStart,
            payload: payload,
            priority: .critical,
            timeout: 10.0
        )
    }
    
    func sendGameUpdate(gameData: GameSyncData, dataPoints: [CompressedDataPoint]) async throws {
        let transferId = "game_update_\(gameData.gameId.uuidString)_\(Date().timeIntervalSince1970)"
        
        let payload: [String: Any] = [
            "gameId": gameData.gameId.uuidString,
            "duration": gameData.duration,
            "distance": gameData.distance,
            "averageSpeed": gameData.averageSpeed,
            "maxSpeed": gameData.maxSpeed,
            "averageHeartRate": gameData.averageHeartRate,
            "maxHeartRate": gameData.maxHeartRate,
            "calories": gameData.calories,
            "recentDataPoints": try encodeDataPoints(dataPoints.suffix(5)), // Last 5 points
            "timestamp": Date().timeIntervalSince1970
        ]
        
        try await sendRealTimeMessage(
            transferId: transferId,
            type: .gameUpdate,
            payload: payload,
            priority: .high,
            timeout: 15.0
        )
    }
    
    func sendGameEnd(gameData: GameSyncData) async throws {
        let transferId = "game_end_\(gameData.gameId.uuidString)"
        
        let payload: [String: Any] = [
            "gameId": gameData.gameId.uuidString,
            "endTime": gameData.endTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "finalStats": [
                "duration": gameData.duration,
                "distance": gameData.distance,
                "averageSpeed": gameData.averageSpeed,
                "maxSpeed": gameData.maxSpeed,
                "averageHeartRate": gameData.averageHeartRate,
                "maxHeartRate": gameData.maxHeartRate,
                "calories": gameData.calories,
                "mvpScore": gameData.mvpScore ?? 0
            ],
            "eventCount": gameData.events.count,
            "dataPointCount": gameData.dataPoints.count,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        try await sendRealTimeMessage(
            transferId: transferId,
            type: .gameEnd,
            payload: payload,
            priority: .critical,
            timeout: 20.0
        )
    }
    
    // MARK: - Bulk Data Transfer
    
    func sendBulkGameData(gameData: GameSyncData) async throws {
        let transferId = "bulk_\(gameData.gameId.uuidString)"
        
        // Create transfer session
        let session = TransferSession(
            id: transferId,
            type: .bulkData,
            priority: .medium,
            totalSize: 0, // Will be calculated
            startTime: Date()
        )
        
        activeTransfers[transferId] = session
        isTransferring = true
        
        do {
            // Send bulk data using the connectivity manager
            // Note: The sendBulkData method is async but also uses a completion handler
            // We'll await it and handle the result inline
            try await connectivityManager.sendBulkData(
                type: .bulkData,
                data: gameData,
                priority: .normal,
                compress: true
            ) { [weak self] result in
                // This completion handler will be called by sendBulkData
                Task { @MainActor in
                    self?.handleBulkTransferCompletion(transferId: transferId, result: result)
                }
            }
            
        } catch {
            activeTransfers.removeValue(forKey: transferId)
            updateTransferringState()
            throw error
        }
    }
    
    private func handleBulkTransferCompletion(transferId: String, result: Result<Void, Error>) {
        guard var session = activeTransfers[transferId] else { return }
        
        switch result {
        case .success():
            session.status = .completed
            session.endTime = Date()
            logger.info("Bulk transfer completed: \(transferId)")
            
        case .failure(let error):
            session.status = .failed
            session.error = error
            session.endTime = Date()
            logger.error("Bulk transfer failed: \(transferId) - \(error.localizedDescription)")
        }
        
        activeTransfers[transferId] = session
        
        // Remove completed/failed transfers after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.activeTransfers.removeValue(forKey: transferId)
            self.updateTransferringState()
        }
    }
    
    // MARK: - Real-Time Messaging
    
    private func sendRealTimeMessage(
        transferId: String,
        type: SharedWatchConnectivityManager.MessageType,
        payload: [String: Any],
        priority: SharedWatchConnectivityManager.MessagePriority,
        timeout: TimeInterval
    ) async throws {
        
        // Create transfer session
        let session = TransferSession(
            id: transferId,
            type: type,
            priority: convertMessagePriorityToSyncPriority(priority),
            totalSize: estimatePayloadSize(payload),
            startTime: Date()
        )
        
        activeTransfers[transferId] = session
        isTransferring = true
        
        return try await withCheckedThrowingContinuation { continuation in
            var timeoutTimer: Timer?
            
            // Set up timeout
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                self.handleTransferTimeout(transferId: transferId)
                continuation.resume(throwing: TransferError.timeout)
            }
            
            connectivityManager.sendMessage(
                type: type,
                payload: payload,
                priority: priority,
                replyHandler: { [weak self] reply in
                    timeoutTimer?.invalidate()
                    self?.handleTransferSuccess(transferId: transferId, reply: reply)
                    self?.recordTransfer()
                    continuation.resume()
                },
                errorHandler: { [weak self] error in
                    timeoutTimer?.invalidate()
                    self?.handleTransferError(transferId: transferId, error: error)
                    continuation.resume(throwing: error)
                }
            )
        }
    }
    
    // MARK: - Transfer Management
    
    private func handleTransferSuccess(transferId: String, reply: [String: Any]) {
        guard var session = activeTransfers[transferId] else { return }
        
        session.status = .completed
        session.endTime = Date()
        activeTransfers[transferId] = session
        
        logger.info("Transfer completed: \(transferId)")
        
        // Clean up after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.activeTransfers.removeValue(forKey: transferId)
            self.updateTransferringState()
        }
    }
    
    private func handleTransferError(transferId: String, error: Error) {
        guard var session = activeTransfers[transferId] else { return }
        
        session.status = .failed
        session.error = error
        session.endTime = Date()
        activeTransfers[transferId] = session
        
        logger.error("Transfer failed: \(transferId) - \(error.localizedDescription)")
        
        // Clean up after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.activeTransfers.removeValue(forKey: transferId)
            self.updateTransferringState()
        }
    }
    
    private func handleTransferTimeout(transferId: String) {
        guard var session = activeTransfers[transferId] else { return }
        
        session.status = .failed
        session.error = TransferError.timeout
        session.endTime = Date()
        activeTransfers[transferId] = session
        
        logger.warning("Transfer timed out: \(transferId)")
    }
    
    private func pauseActiveTransfers() {
        for (id, var session) in activeTransfers {
            if session.status == .active {
                session.status = .paused
                activeTransfers[id] = session
            }
        }
        logger.info("Paused active transfers due to connection loss")
    }
    
    private func resumeActiveTransfers() {
        for (id, var session) in activeTransfers {
            if session.status == .paused {
                session.status = .active
                activeTransfers[id] = session
            }
        }
        logger.info("Resumed paused transfers")
    }
    
    private func cleanupExpiredTransfers() {
        let now = Date()
        let expiredTransfers = activeTransfers.filter { _, session in
            guard let endTime = session.endTime else {
                // Active transfer - check if it's been running too long
                return now.timeIntervalSince(session.startTime) > transferTimeoutInterval * 2
            }
            // Completed transfer - remove after 10 minutes
            return now.timeIntervalSince(endTime) > 600
        }
        
        for (id, _) in expiredTransfers {
            activeTransfers.removeValue(forKey: id)
        }
        
        updateTransferringState()
    }
    
    private func updateTransferringState() {
        isTransferring = !activeTransfers.isEmpty && activeTransfers.values.contains { $0.status == .active }
    }
    
    private func recordTransfer() {
        recentTransfers.append(Date())
    }
    
    // MARK: - Utility Methods
    
    private func estimatePayloadSize(_ payload: [String: Any]) -> Int {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            return data.count
        } catch {
            return 1024 // Default estimate
        }
    }
    
    private func encodeDataPoints(_ dataPoints: [CompressedDataPoint]) throws -> Data {
        return try JSONEncoder().encode(Array(dataPoints))
    }
    
    private func convertMessagePriorityToSyncPriority(_ priority: SharedWatchConnectivityManager.MessagePriority) -> SyncPriority {
        switch priority {
        case .critical:
            return .critical
        case .high:
            return .high
        case .normal:
            return .medium
        case .low:
            return .low
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        transferTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Transfer Session

struct TransferSession {
    let id: String
    let type: SharedWatchConnectivityManager.MessageType
    let priority: SyncPriority
    let totalSize: Int
    let startTime: Date
    var endTime: Date?
    var status: TransferStatus = .active
    var error: Error?
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var transferRate: Double {
        guard duration > 0 else { return 0 }
        return Double(totalSize) / duration // Bytes per second
    }
}

enum TransferStatus: String, CaseIterable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
}

enum TransferError: LocalizedError {
    case timeout
    case connectionLost
    case payloadTooLarge
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Transfer timed out"
        case .connectionLost:
            return "Connection lost during transfer"
        case .payloadTooLarge:
            return "Payload too large for real-time transfer"
        case .invalidData:
            return "Invalid data format"
        }
    }
}