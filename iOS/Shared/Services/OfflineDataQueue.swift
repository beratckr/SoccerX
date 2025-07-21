import Foundation
import Combine
import os.log

@MainActor
class OfflineDataQueue: ObservableObject {
    static let shared = OfflineDataQueue()
    
    @Published var queuedItems: [SyncQueueItem] = []
    @Published var totalQueueSize: Int64 = 0
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var lastProcessedTime: Date?
    @Published var queueHealth: QueueHealth = .healthy
    
    private let logger = Logger(subsystem: "com.soccerx.app", category: "OfflineQueue")
    private let connectivityManager = WatchConnectivityManager.shared
    private let realTimeTransfer = RealTimeDataTransfer()
    private var cancellables = Set<AnyCancellable>()
    private var processingTimer: Timer?
    
    // Queue configuration
    private let maxQueueSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let maxRetentionDays = 7
    private let maxRetryAttempts = 3
    private let processingInterval: TimeInterval = 30 // 30 seconds
    private let batchSize = 5
    
    // Storage
    private let queueDirectory: URL
    private let fileManager = FileManager.default
    
    init() {
        // Setup queue directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        queueDirectory = documentsPath.appendingPathComponent("SyncQueue")
        
        setupQueueDirectory()
        loadQueueFromDisk()
        setupMonitoring()
        startProcessingTimer()
    }
    
    // MARK: - Setup and Initialization
    
    private func setupQueueDirectory() {
        do {
            try fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
            logger.info("Queue directory initialized: \(queueDirectory.path)")
        } catch {
            logger.error("Failed to create queue directory: \(error.localizedDescription)")
        }
    }
    
    private func loadQueueFromDisk() {
        do {
            let files = try fileManager.contentsOfDirectory(at: queueDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for file in files where file.pathExtension == "json" {
                if let item = loadQueueItem(from: file) {
                    queuedItems.append(item)
                }
            }
            
            // Sort by priority and creation time
            sortQueue()
            updateQueueMetrics()
            
            logger.info("Loaded \(queuedItems.count) items from disk")
            
        } catch {
            logger.error("Failed to load queue from disk: \(error.localizedDescription)")
        }
    }
    
    private func loadQueueItem(from url: URL) -> SyncQueueItem? {
        do {
            let data = try Data(contentsOf: url)
            let item = try JSONDecoder().decode(SyncQueueItem.self, from: data)
            
            // Check if item is expired
            if item.isExpired {
                try? fileManager.removeItem(at: url)
                return nil
            }
            
            return item
        } catch {
            logger.warning("Failed to load queue item from \(url.lastPathComponent): \(error.localizedDescription)")
            // Remove corrupted file
            try? fileManager.removeItem(at: url)
            return nil
        }
    }
    
    private func setupMonitoring() {
        // Monitor connectivity changes
        connectivityManager.$isReachable
            .sink { [weak self] isReachable in
                if isReachable {
                    self?.startProcessingIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Monitor connection state
        connectivityManager.$connectionState
            .sink { [weak self] state in
                if state == .reachable {
                    self?.startProcessingIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: processingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueueIfReady()
                self?.performMaintenanceTasks()
            }
        }
    }
    
    // MARK: - Queue Operations
    
    func enqueue<T: Codable>(
        messageType: WatchConnectivityManager.MessageType,
        data: T,
        priority: SyncPriority = .medium
    ) async throws {
        
        // Encode data
        let payload = try JSONEncoder().encode(data)
        
        // Check queue size limits
        if totalQueueSize + Int64(payload.count) > maxQueueSize {
            try await makeSpaceInQueue(requiredSpace: Int64(payload.count))
        }
        
        // Create queue item
        let item = SyncQueueItem(
            messageType: messageType,
            priority: priority,
            payload: payload
        )
        
        // Save to disk
        try await saveQueueItem(item)
        
        // Add to in-memory queue
        queuedItems.append(item)
        sortQueue()
        updateQueueMetrics()
        
        logger.info("Enqueued item: \(messageType.rawValue) (priority: \(priority.rawValue), size: \(payload.count) bytes)")
        
        // Try to process immediately if connected
        if connectivityManager.isReachable && !isProcessing {
            await processQueueIfReady()
        }
    }
    
    func dequeue(count: Int = 1) -> [SyncQueueItem] {
        guard !queuedItems.isEmpty else { return [] }
        
        let itemsToDequeue = Array(queuedItems.prefix(count))
        queuedItems.removeFirst(min(count, queuedItems.count))
        
        updateQueueMetrics()
        return itemsToDequeue
    }
    
    private func sortQueue() {
        queuedItems.sort { lhs, rhs in
            // First by priority (higher priority first)
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            // Then by creation time (older first)
            return lhs.createdAt < rhs.createdAt
        }
    }
    
    // MARK: - Queue Processing
    
    private func processQueueIfReady() async {
        guard connectivityManager.isReachable,
              !isProcessing,
              !queuedItems.isEmpty else {
            return
        }
        
        isProcessing = true
        processingProgress = 0
        
        logger.info("Starting queue processing with \(queuedItems.count) items")
        
        do {
            await processQueueBatch()
        } catch {
            logger.error("Queue processing failed: \(error.localizedDescription)")
        }
        
        isProcessing = false
        processingProgress = 0
        lastProcessedTime = Date()
    }
    
    private func processQueueBatch() async {
        let connectionQuality = realTimeTransfer.connectionQuality
        let batchSize = connectionQuality.maxBatchSize
        
        while !queuedItems.isEmpty && connectivityManager.isReachable {
            let batch = createBatch(size: batchSize)
            
            do {
                await processBatch(batch)
                updateProcessingProgress()
                
                // Add delay based on connection quality
                try await Task.sleep(nanoseconds: UInt64(connectionQuality.recommendedDelay * 1_000_000_000))
                
            } catch {
                logger.error("Batch processing failed: \(error.localizedDescription)")
                
                // Mark items as failed and retry later
                for item in batch {
                    await handleItemFailure(item, error: error)
                }
                break
            }
        }
    }
    
    private func createBatch(size: Int) -> [SyncQueueItem] {
        let availableItems = queuedItems.filter { 
            $0.syncStatus == .pending && ($0.shouldRetry || $0.retryCount == 0)
        }
        
        return Array(availableItems.prefix(size))
    }
    
    private func processBatch(_ batch: [SyncQueueItem]) async {
        for item in batch {
            do {
                try await processQueueItem(item)
                await handleItemSuccess(item)
            } catch {
                await handleItemFailure(item, error: error)
            }
        }
    }
    
    private func processQueueItem(_ item: SyncQueueItem) async throws {
        logger.debug("Processing queue item: \(item.messageType.rawValue)")
        
        // Decode payload
        let payload = try JSONSerialization.jsonObject(with: item.payload) as? [String: Any]
        ?? [:]
        
        // Send via connectivity manager
        return try await withCheckedThrowingContinuation { continuation in
            connectivityManager.sendMessage(
                type: item.messageType,
                payload: payload,
                priority: MessagePriority(rawValue: item.priority.rawValue) ?? .medium,
                replyHandler: { _ in
                    continuation.resume()
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
    
    private func handleItemSuccess(_ item: SyncQueueItem) async {
        // Remove from queue
        if let index = queuedItems.firstIndex(where: { $0.id == item.id }) {
            queuedItems.remove(at: index)
        }
        
        // Remove from disk
        await removeQueueItemFromDisk(item)
        
        updateQueueMetrics()
        logger.debug("Successfully processed item: \(item.messageType.rawValue)")
    }
    
    private func handleItemFailure(_ item: SyncQueueItem, error: Error) async {
        guard let index = queuedItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        var updatedItem = item
        updatedItem.retryCount += 1
        updatedItem.lastAttempt = Date()
        
        if updatedItem.retryCount >= maxRetryAttempts {
            // Max retries reached - remove from queue
            queuedItems.remove(at: index)
            await removeQueueItemFromDisk(item)
            logger.warning("Item failed permanently: \(item.messageType.rawValue) (attempts: \(updatedItem.retryCount))")
        } else {
            // Update item for retry
            updatedItem.syncStatus = .failed
            queuedItems[index] = updatedItem
            
            // Save updated item to disk
            do {
                try await saveQueueItem(updatedItem)
                logger.info("Item scheduled for retry: \(item.messageType.rawValue) (attempt \(updatedItem.retryCount)/\(maxRetryAttempts))")
            } catch {
                logger.error("Failed to save retry item: \(error.localizedDescription)")
            }
        }
        
        updateQueueMetrics()
    }
    
    // MARK: - Storage Operations
    
    private func saveQueueItem(_ item: SyncQueueItem) async throws {
        let filename = "\(item.id.uuidString).json"
        let fileURL = queueDirectory.appendingPathComponent(filename)
        
        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL)
    }
    
    private func removeQueueItemFromDisk(_ item: SyncQueueItem) async {
        let filename = "\(item.id.uuidString).json"
        let fileURL = queueDirectory.appendingPathComponent(filename)
        
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Queue Management
    
    private func makeSpaceInQueue(requiredSpace: Int64) async throws {
        let spaceToFree = requiredSpace + (totalQueueSize - maxQueueSize)
        var freedSpace: Int64 = 0
        
        // Remove expired items first
        await removeExpiredItems()
        
        // If still need space, remove oldest low-priority items
        if totalQueueSize > maxQueueSize - requiredSpace {
            let sortedByAge = queuedItems
                .filter { $0.priority == .low }
                .sorted { $0.createdAt < $1.createdAt }
            
            for item in sortedByAge {
                if freedSpace >= spaceToFree { break }
                
                if let index = queuedItems.firstIndex(where: { $0.id == item.id }) {
                    queuedItems.remove(at: index)
                    await removeQueueItemFromDisk(item)
                    freedSpace += Int64(item.payload.count)
                }
            }
        }
        
        updateQueueMetrics()
        logger.info("Freed \(freedSpace) bytes from queue")
    }
    
    private func removeExpiredItems() async {
        let expiredItems = queuedItems.filter { $0.isExpired }
        
        for item in expiredItems {
            if let index = queuedItems.firstIndex(where: { $0.id == item.id }) {
                queuedItems.remove(at: index)
                await removeQueueItemFromDisk(item)
            }
        }
        
        if !expiredItems.isEmpty {
            logger.info("Removed \(expiredItems.count) expired items")
            updateQueueMetrics()
        }
    }
    
    private func performMaintenanceTasks() {
        Task {
            await removeExpiredItems()
            updateQueueHealth()
        }
    }
    
    // MARK: - Metrics and Health
    
    private func updateQueueMetrics() {
        totalQueueSize = queuedItems.reduce(0) { $0 + Int64($1.payload.count) }
        updateQueueHealth()
    }
    
    private func updateQueueHealth() {
        let totalItems = queuedItems.count
        let failedItems = queuedItems.filter { $0.syncStatus == .failed }.count
        let oldItems = queuedItems.filter { 
            Date().timeIntervalSince($0.createdAt) > TimeInterval.oneHour 
        }.count
        
        let failureRate = totalItems > 0 ? Double(failedItems) / Double(totalItems) : 0
        let oldItemRate = totalItems > 0 ? Double(oldItems) / Double(totalItems) : 0
        let sizeUsage = Double(totalQueueSize) / Double(maxQueueSize)
        
        if failureRate > 0.5 || sizeUsage > 0.9 {
            queueHealth = .critical
        } else if failureRate > 0.3 || oldItemRate > 0.3 || sizeUsage > 0.7 {
            queueHealth = .warning
        } else {
            queueHealth = .healthy
        }
    }
    
    private func updateProcessingProgress() {
        let totalItems = queuedItems.count
        let processedItems = queuedItems.filter { $0.syncStatus == .synced }.count
        
        processingProgress = totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
    }
    
    private func startProcessingIfNeeded() {
        guard !queuedItems.isEmpty, !isProcessing else { return }
        
        Task {
            await processQueueIfReady()
        }
    }
    
    // MARK: - Public Interface
    
    func getQueueStatus() -> QueueStatus {
        return QueueStatus(
            totalItems: queuedItems.count,
            pendingItems: queuedItems.filter { $0.syncStatus == .pending }.count,
            failedItems: queuedItems.filter { $0.syncStatus == .failed }.count,
            totalSize: totalQueueSize,
            maxSize: maxQueueSize,
            health: queueHealth,
            lastProcessed: lastProcessedTime,
            isProcessing: isProcessing
        )
    }
    
    func clearFailedItems() async {
        let failedItems = queuedItems.filter { $0.syncStatus == .failed }
        
        for item in failedItems {
            if let index = queuedItems.firstIndex(where: { $0.id == item.id }) {
                queuedItems.remove(at: index)
                await removeQueueItemFromDisk(item)
            }
        }
        
        updateQueueMetrics()
        logger.info("Cleared \(failedItems.count) failed items")
    }
    
    func forceProcessQueue() async {
        guard !queuedItems.isEmpty else { return }
        
        logger.info("Force processing queue requested")
        await processQueueIfReady()
    }
    
    // MARK: - Cleanup
    
    deinit {
        processingTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum QueueHealth: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

struct QueueStatus {
    let totalItems: Int
    let pendingItems: Int
    let failedItems: Int
    let totalSize: Int64
    let maxSize: Int64
    let health: QueueHealth
    let lastProcessed: Date?
    let isProcessing: Bool
    
    var usagePercentage: Double {
        guard maxSize > 0 else { return 0 }
        return Double(totalSize) / Double(maxSize) * 100
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: totalSize)
    }
}