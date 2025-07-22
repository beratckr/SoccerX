import Foundation
import Combine
import os.log

@MainActor
class ErrorRecoveryService: ObservableObject {
    static let shared = ErrorRecoveryService()
    
    @Published var recoveryActions: [RecoveryAction] = []
    @Published var isRecovering = false
    @Published var lastRecoveryTime: Date?
    @Published var recoveryHistory: [RecoveryResult] = []
    
    private let logger = Logger(subsystem: "com.soccerx.app", category: "ErrorRecovery")
    private let connectivityManager = SharedWatchConnectivityManager.shared
    private let offlineQueue = OfflineDataQueue.shared
    private let optimizationEngine = SyncOptimizationEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Recovery configuration
    private let maxRecoveryAttempts = 3
    private let recoveryTimeoutInterval: TimeInterval = 60
    private let recoveryHistoryLimit = 20
    
    init() {
        setupErrorMonitoring()
        loadRecoveryHistory()
    }
    
    // MARK: - Error Monitoring
    
    private func setupErrorMonitoring() {
        // Monitor connectivity errors
        connectivityManager.$syncError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleConnectivityError(error)
            }
            .store(in: &cancellables)
        
        // Monitor queue health
        offlineQueue.$queueHealth
            .sink { [weak self] health in
                if health == .critical {
                    self?.handleQueueCriticalState()
                }
            }
            .store(in: &cancellables)
        
        // Monitor connection state changes
        connectivityManager.$connectionState
            .sink { [weak self] state in
                if state == .notActivated {
                    self?.handleSessionDeactivation()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handlers
    
    private func handleConnectivityError(_ error: SharedWatchConnectivityManager.SyncError) {
        logger.warning("Connectivity error detected: \(error.localizedDescription)")
        
        switch error {
        case .sessionNotActivated:
            addRecoveryAction(.reactivateSession)
            
        case .messageDeliveryFailed:
            addRecoveryAction(.retryFailedMessages)
            addRecoveryAction(.checkConnectionHealth)
            
        case .compressionFailed:
            addRecoveryAction(.disableCompression)
            
        case .decodingFailed:
            addRecoveryAction(.clearCorruptedData)
            
        case .transferLimitExceeded:
            addRecoveryAction(.reduceTransferSize)
            
        case .notReachable:
            addRecoveryAction(.checkConnectionHealth)
            
        case .transferFailed:
            addRecoveryAction(.retryFailedMessages)
            
        case .messageTimeout:
            addRecoveryAction(.retryFailedMessages)
            
        case .invalidData:
            addRecoveryAction(.clearCorruptedData)
        }
    }
    
    private func handleQueueCriticalState() {
        logger.warning("Queue critical state detected")
        
        addRecoveryAction(.clearOldQueueItems)
        addRecoveryAction(.optimizeQueueSize)
        addRecoveryAction(.enableAggressiveCompression)
    }
    
    private func handleSessionDeactivation() {
        logger.warning("Session deactivation detected")
        
        addRecoveryAction(.reactivateSession)
        addRecoveryAction(.checkWatchPairing)
    }
    
    // MARK: - Recovery Actions
    
    private func addRecoveryAction(_ actionType: RecoveryActionType) {
        // Don't add duplicate actions
        guard !recoveryActions.contains(where: { $0.type == actionType }) else { return }
        
        let action = RecoveryAction(
            type: actionType,
            priority: actionType.priority,
            description: actionType.description,
            estimatedDuration: actionType.estimatedDuration
        )
        
        recoveryActions.append(action)
        sortRecoveryActions()
        
        logger.info("Added recovery action: \(actionType.rawValue)")
    }
    
    private func sortRecoveryActions() {
        recoveryActions.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.numericValue > rhs.priority.numericValue
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
    
    func executeRecoveryAction(_ action: RecoveryAction) async -> RecoveryResult {
        guard !isRecovering else {
            return RecoveryResult(
                actionType: action.type,
                success: false,
                error: "Recovery already in progress",
                duration: 0,
                timestamp: Date()
            )
        }
        
        isRecovering = true
        let startTime = Date()
        
        logger.info("Executing recovery action: \(action.type.rawValue)")
        
        let result: RecoveryResult
        
        do {
            let success = try await performRecoveryAction(action.type)
            let duration = Date().timeIntervalSince(startTime)
            
            result = RecoveryResult(
                actionType: action.type,
                success: success,
                error: nil,
                duration: duration,
                timestamp: Date()
            )
            
            if success {
                // Remove the completed action
                recoveryActions.removeAll { $0.id == action.id }
                logger.info("Recovery action completed successfully: \(action.type.rawValue)")
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            result = RecoveryResult(
                actionType: action.type,
                success: false,
                error: error.localizedDescription,
                duration: duration,
                timestamp: Date()
            )
            
            logger.error("Recovery action failed: \(action.type.rawValue) - \(error.localizedDescription)")
        }
        
        // Record result
        addRecoveryResult(result)
        isRecovering = false
        lastRecoveryTime = Date()
        
        return result
    }
    
    private func performRecoveryAction(_ actionType: RecoveryActionType) async throws -> Bool {
        switch actionType {
        case .reactivateSession:
            return await reactivateSession()
            
        case .retryFailedMessages:
            return await retryFailedMessages()
            
        case .checkConnectionHealth:
            return await checkConnectionHealth()
            
        case .clearCorruptedData:
            return await clearCorruptedData()
            
        case .clearOldQueueItems:
            return await clearOldQueueItems()
            
        case .optimizeQueueSize:
            return await optimizeQueueSize()
            
        case .disableCompression:
            return await disableCompression()
            
        case .reduceTransferSize:
            return await reduceTransferSize()
            
        case .enableAggressiveCompression:
            return await enableAggressiveCompression()
            
        case .checkWatchPairing:
            return await checkWatchPairing()
            
        case .resetSyncSettings:
            return await resetSyncSettings()
            
        case .clearAllData:
            return await clearAllData()
        }
    }
    
    // MARK: - Recovery Implementations
    
    private func reactivateSession() async -> Bool {
        connectivityManager.forceSessionReactivation()
        
        // Wait for session to activate
        return await withCheckedContinuation { continuation in
            var observer: AnyCancellable?
            
            let timeout = DispatchWorkItem {
                observer?.cancel()
                continuation.resume(returning: false)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
            
            observer = connectivityManager.$connectionState
                .sink { state in
                    if state == .activated || state == .reachable {
                        timeout.cancel()
                        observer?.cancel()
                        continuation.resume(returning: true)
                    }
                }
        }
    }
    
    private func retryFailedMessages() async -> Bool {
        await offlineQueue.forceProcessQueue()
        
        // Wait a moment and check if failed items decreased
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        let failedCount = offlineQueue.getQueueStatus().failedItems
        return failedCount == 0
    }
    
    private func checkConnectionHealth() async -> Bool {
        connectivityManager.checkConnectionHealth()
        
        // Wait for heartbeat response
        return await withCheckedContinuation { continuation in
            var observer: AnyCancellable?
            
            let timeout = DispatchWorkItem {
                observer?.cancel()
                continuation.resume(returning: false)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
            
            observer = connectivityManager.$lastSyncTime
                .sink { lastSync in
                    if let lastSync = lastSync, Date().timeIntervalSince(lastSync) < 10 {
                        timeout.cancel()
                        observer?.cancel()
                        continuation.resume(returning: true)
                    }
                }
        }
    }
    
    private func clearCorruptedData() async -> Bool {
        await offlineQueue.clearFailedItems()
        return true
    }
    
    private func clearOldQueueItems() async -> Bool {
        // This would implement clearing of old queue items
        // For now, just clear failed items
        await offlineQueue.clearFailedItems()
        return true
    }
    
    private func optimizeQueueSize() async -> Bool {
        // Implementation would optimize queue storage
        return true
    }
    
    private func disableCompression() async -> Bool {
        optimizationEngine.setOptimizationLevel(.performance)
        return true
    }
    
    private func reduceTransferSize() async -> Bool {
        optimizationEngine.setOptimizationLevel(.aggressive)
        return true
    }
    
    private func enableAggressiveCompression() async -> Bool {
        optimizationEngine.setOptimizationLevel(.aggressive)
        return true
    }
    
    private func checkWatchPairing() async -> Bool {
        // This would check Apple Watch pairing status
        // For now, assume it's working
        return true
    }
    
    private func resetSyncSettings() async -> Bool {
        // Reset to default sync settings
        let defaultRules = SyncRules(
            allowBulkTransfer: true,
            allowHighResolutionData: true,
            allowBackgroundSync: true,
            maxBatchSize: 5,
            compressionEnabled: true,
            maxTransferSize: 10 * 1024 * 1024,
            priorityThreshold: .medium
        )
        
        optimizationEngine.updateSyncRules(defaultRules)
        return true
    }
    
    private func clearAllData() async -> Bool {
        // Nuclear option - clear all sync data
        await offlineQueue.clearFailedItems()
        // Additional cleanup would go here
        return true
    }
    
    // MARK: - Auto Recovery
    
    func executeAutoRecovery() async {
        guard !isRecovering, !recoveryActions.isEmpty else { return }
        
        logger.info("Starting auto recovery with \(self.recoveryActions.count) actions")
        
        // Execute high priority actions automatically
        let highPriorityActions = recoveryActions.filter { 
            $0.priority == .critical || $0.priority == .high 
        }
        
        for action in highPriorityActions.prefix(3) { // Limit to 3 actions
            let result = await executeRecoveryAction(action)
            
            if !result.success {
                logger.warning("Auto recovery action failed: \(action.type.rawValue)")
                break // Stop on first failure
            }
            
            // Small delay between actions
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        logger.info("Auto recovery completed")
    }
    
    // MARK: - Recovery History
    
    private func addRecoveryResult(_ result: RecoveryResult) {
        recoveryHistory.append(result)
        
        // Maintain history limit
        if recoveryHistory.count > recoveryHistoryLimit {
            recoveryHistory.removeFirst()
        }
        
        saveRecoveryHistory()
    }
    
    private func loadRecoveryHistory() {
        if let data = UserDefaults.standard.data(forKey: "RecoveryHistory"),
           let history = try? JSONDecoder().decode([RecoveryResult].self, from: data) {
            recoveryHistory = history
        }
    }
    
    private func saveRecoveryHistory() {
        if let data = try? JSONEncoder().encode(recoveryHistory) {
            UserDefaults.standard.set(data, forKey: "RecoveryHistory")
        }
    }
    
    // MARK: - Public Interface
    
    func clearRecoveryActions() {
        recoveryActions.removeAll()
        logger.info("Recovery actions cleared")
    }
    
    func getRecoveryStatus() -> RecoveryStatus {
        let successfulRecoveries = recoveryHistory.filter { $0.success }.count
        let totalRecoveries = recoveryHistory.count
        let successRate = totalRecoveries > 0 ? Double(successfulRecoveries) / Double(totalRecoveries) : 0
        
        return RecoveryStatus(
            pendingActions: recoveryActions.count,
            isRecovering: isRecovering,
            lastRecoveryTime: lastRecoveryTime,
            successRate: successRate,
            totalRecoveries: totalRecoveries
        )
    }
}

// MARK: - Supporting Types

enum RecoveryActionType: String, CaseIterable {
    case reactivateSession = "reactivate_session"
    case retryFailedMessages = "retry_failed_messages"
    case checkConnectionHealth = "check_connection_health"
    case clearCorruptedData = "clear_corrupted_data"
    case clearOldQueueItems = "clear_old_queue_items"
    case optimizeQueueSize = "optimize_queue_size"
    case disableCompression = "disable_compression"
    case reduceTransferSize = "reduce_transfer_size"
    case enableAggressiveCompression = "enable_aggressive_compression"
    case checkWatchPairing = "check_watch_pairing"
    case resetSyncSettings = "reset_sync_settings"
    case clearAllData = "clear_all_data"
    
    var priority: SyncPriority {
        switch self {
        case .reactivateSession, .checkConnectionHealth:
            return .critical
        case .retryFailedMessages, .clearCorruptedData:
            return .high
        case .clearOldQueueItems, .optimizeQueueSize, .reduceTransferSize:
            return .medium
        case .disableCompression, .enableAggressiveCompression, .checkWatchPairing, .resetSyncSettings:
            return .low
        case .clearAllData:
            return .critical
        }
    }
    
    var description: String {
        switch self {
        case .reactivateSession:
            return "Reactivate watch connectivity session"
        case .retryFailedMessages:
            return "Retry failed message transfers"
        case .checkConnectionHealth:
            return "Test connection with heartbeat"
        case .clearCorruptedData:
            return "Remove corrupted sync data"
        case .clearOldQueueItems:
            return "Remove expired queue items"
        case .optimizeQueueSize:
            return "Optimize queue storage usage"
        case .disableCompression:
            return "Disable data compression temporarily"
        case .reduceTransferSize:
            return "Reduce maximum transfer size"
        case .enableAggressiveCompression:
            return "Enable aggressive data compression"
        case .checkWatchPairing:
            return "Verify Apple Watch pairing status"
        case .resetSyncSettings:
            return "Reset sync settings to defaults"
        case .clearAllData:
            return "Clear all sync data (nuclear option)"
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .reactivateSession, .checkConnectionHealth:
            return 10
        case .retryFailedMessages:
            return 30
        case .clearCorruptedData, .clearOldQueueItems:
            return 5
        case .optimizeQueueSize:
            return 15
        case .disableCompression, .enableAggressiveCompression, .reduceTransferSize:
            return 2
        case .checkWatchPairing:
            return 5
        case .resetSyncSettings:
            return 3
        case .clearAllData:
            return 10
        }
    }
}

struct RecoveryAction: Identifiable {
    let id = UUID()
    let type: RecoveryActionType
    let priority: SyncPriority
    let description: String
    let estimatedDuration: TimeInterval
    let createdAt = Date()
}

struct RecoveryResult: Codable {
    let actionType: String // Store as String for Codable
    let success: Bool
    let error: String?
    let duration: TimeInterval
    let timestamp: Date
    
    init(actionType: RecoveryActionType, success: Bool, error: String?, duration: TimeInterval, timestamp: Date = Date()) {
        self.actionType = actionType.rawValue
        self.success = success
        self.error = error
        self.duration = duration
        self.timestamp = timestamp
    }
    
    var actionTypeEnum: RecoveryActionType? {
        RecoveryActionType(rawValue: actionType)
    }
}

struct RecoveryStatus {
    let pendingActions: Int
    let isRecovering: Bool
    let lastRecoveryTime: Date?
    let successRate: Double
    let totalRecoveries: Int
}