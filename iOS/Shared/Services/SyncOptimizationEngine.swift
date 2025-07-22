import Foundation
import Network
import Combine
import os.log

@MainActor
class SyncOptimizationEngine: ObservableObject {
    static let shared = SyncOptimizationEngine()
    
    @Published var connectionType: ConnectionType = .none
    @Published var bandwidth: Bandwidth = .unknown
    @Published var compressionRatio: Double = 0
    @Published var dataUsage: DataUsage = DataUsage()
    @Published var syncRules: SyncRules = SyncRules(
        allowBulkTransfer: true,
        allowHighResolutionData: true,
        allowBackgroundSync: true,
        maxBatchSize: 100,
        compressionEnabled: true,
        maxTransferSize: 10 * 1024 * 1024, // 10MB
        priorityThreshold: .medium
    )
    @Published var optimizationLevel: OptimizationLevel = .balanced
    
    private let logger = Logger(subsystem: "com.soccerx.app", category: "SyncOptimization")
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Compression tracking
    private var compressionHistory: [CompressionResult] = []
    private let maxCompressionHistory = 50
    
    // Bandwidth measurement
    private var bandwidthMeasurements: [BandwidthMeasurement] = []
    private let maxBandwidthHistory = 20
    
    // Data usage tracking
    private var sessionDataUsage: Int64 = 0
    private let dataUsageResetInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var lastDataUsageReset = Date()
    
    init() {
        setupNetworkMonitoring()
        loadSyncRules()
        startBandwidthMeasurement()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionInfo(path: path)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func updateConnectionInfo(path: NWPath) {
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .other
        } else {
            connectionType = .none
        }
        
        // Update sync rules based on connection
        updateSyncRulesForConnection()
        
        logger.info("Connection updated: \(self.connectionType.rawValue), satisfied: \(path.status == .satisfied)")
    }
    
    private func updateSyncRulesForConnection() {
        switch connectionType {
        case .wifi, .ethernet:
            syncRules = SyncRules(
                allowBulkTransfer: true,
                allowHighResolutionData: true,
                allowBackgroundSync: true,
                maxBatchSize: 10,
                compressionEnabled: true,
                maxTransferSize: 100 * 1024 * 1024, // 100MB
                priorityThreshold: .low
            )
            
        case .cellular:
            syncRules = SyncRules(
                allowBulkTransfer: false,
                allowHighResolutionData: false,
                allowBackgroundSync: true,
                maxBatchSize: 3,
                compressionEnabled: true,
                maxTransferSize: 10 * 1024 * 1024, // 10MB
                priorityThreshold: .high
            )
            
        case .other:
            syncRules = SyncRules(
                allowBulkTransfer: false,
                allowHighResolutionData: false,
                allowBackgroundSync: false,
                maxBatchSize: 1,
                compressionEnabled: true,
                maxTransferSize: 1 * 1024 * 1024, // 1MB
                priorityThreshold: .critical
            )
            
        case .none:
            syncRules = SyncRules.offline
        }
    }
    
    // MARK: - Data Compression
    
    func compressData(_ data: Data, algorithm: SyncCompressionAlgorithm = .zlib) async throws -> CompressedData {
        let startTime = Date()
        let originalSize = data.count
        
        logger.debug("Compressing \(originalSize) bytes using \(algorithm.rawValue)")
        
        let compressedData: Data
        
        switch algorithm {
        case .zlib:
            compressedData = try await compressWithZlib(data)
        case .lz4:
            compressedData = try await compressWithLZ4(data)
        case .adaptive:
            compressedData = try await compressAdaptive(data)
        }
        
        let compressionTime = Date().timeIntervalSince(startTime)
        let compressedSize = compressedData.count
        let ratio = Double(compressedSize) / Double(originalSize)
        
        // Record compression result
        let result = CompressionResult(
            algorithm: algorithm,
            originalSize: originalSize,
            compressedSize: compressedSize,
            ratio: ratio,
            duration: compressionTime,
            timestamp: Date()
        )
        
        recordCompressionResult(result)
        
        logger.info("Compression complete: \(originalSize) → \(compressedSize) bytes (\(String(format: "%.1f", (1-ratio)*100))% reduction)")
        
        return CompressedData(
            data: compressedData,
            algorithm: algorithm,
            originalSize: originalSize,
            compressedSize: compressedSize,
            checksum: data.sha256Hash
        )
    }
    
    private func compressWithZlib(_ data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let compressed = data.compressed(using: .zlib) else {
                    continuation.resume(throwing: CompressionError.zlibFailed)
                    return
                }
                continuation.resume(returning: compressed)
            }
        }
    }
    
    private func compressWithLZ4(_ data: Data) async throws -> Data {
        // LZ4 implementation would go here
        // For now, fallback to zlib
        return try await compressWithZlib(data)
    }
    
    private func compressAdaptive(_ data: Data) async throws -> Data {
        // Try different algorithms and choose the best result
        let zlibResult = try await compressWithZlib(data)
        
        // For small data, compression might not be beneficial
        if data.count < 1024 {
            return data.count < zlibResult.count ? data : zlibResult
        }
        
        return zlibResult
    }
    
    func decompressData(_ compressedData: CompressedData) async throws -> Data {
        logger.debug("Decompressing \(compressedData.compressedSize) bytes using \(compressedData.algorithm.rawValue)")
        
        let decompressed: Data
        
        switch compressedData.algorithm {
        case .zlib:
            decompressed = try await decompressWithZlib(compressedData.data)
        case .lz4:
            decompressed = try await decompressWithLZ4(compressedData.data)
        case .adaptive:
            decompressed = try await decompressWithZlib(compressedData.data)
        }
        
        // Verify integrity
        guard decompressed.sha256Hash == compressedData.checksum else {
            throw CompressionError.checksumMismatch
        }
        
        guard decompressed.count == compressedData.originalSize else {
            throw CompressionError.sizeMismatch
        }
        
        return decompressed
    }
    
    private func decompressWithZlib(_ data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let decompressed = data.decompressed(using: .zlib) else {
                    continuation.resume(throwing: CompressionError.zlibFailed)
                    return
                }
                continuation.resume(returning: decompressed)
            }
        }
    }
    
    private func decompressWithLZ4(_ data: Data) async throws -> Data {
        // LZ4 implementation would go here
        return try await decompressWithZlib(data)
    }
    
    // MARK: - Bandwidth Measurement
    
    private func startBandwidthMeasurement() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.measureBandwidth()
            }
        }
    }
    
    private func measureBandwidth() async {
        // Simplified bandwidth measurement
        // In a real implementation, this would perform actual network tests
        
        let measurement = BandwidthMeasurement(
            timestamp: Date(),
            downloadSpeed: estimateDownloadSpeed(),
            uploadSpeed: estimateUploadSpeed(),
            latency: estimateLatency(),
            connectionType: connectionType
        )
        
        bandwidthMeasurements.append(measurement)
        if bandwidthMeasurements.count > maxBandwidthHistory {
            bandwidthMeasurements.removeFirst()
        }
        
        updateBandwidthEstimate()
    }
    
    private func estimateDownloadSpeed() -> Double {
        // Simplified estimation based on connection type
        switch connectionType {
        case .wifi: return Double.random(in: 10...100) * 1024 * 1024 // 10-100 Mbps
        case .cellular: return Double.random(in: 1...50) * 1024 * 1024 // 1-50 Mbps
        case .ethernet: return Double.random(in: 50...1000) * 1024 * 1024 // 50-1000 Mbps
        case .other: return Double.random(in: 0.1...10) * 1024 * 1024 // 0.1-10 Mbps
        case .none: return 0
        }
    }
    
    private func estimateUploadSpeed() -> Double {
        return estimateDownloadSpeed() * 0.3 // Upload typically slower
    }
    
    private func estimateLatency() -> TimeInterval {
        switch connectionType {
        case .wifi: return Double.random(in: 0.01...0.05) // 10-50ms
        case .cellular: return Double.random(in: 0.05...0.2) // 50-200ms
        case .ethernet: return Double.random(in: 0.001...0.01) // 1-10ms
        case .other: return Double.random(in: 0.1...1.0) // 100-1000ms
        case .none: return Double.infinity
        }
    }
    
    private func updateBandwidthEstimate() {
        guard !bandwidthMeasurements.isEmpty else {
            bandwidth = .unknown
            return
        }
        
        let recentMeasurements = bandwidthMeasurements.suffix(5)
        let avgDownload = recentMeasurements.map { $0.downloadSpeed }.reduce(0, +) / Double(recentMeasurements.count)
        let avgUpload = recentMeasurements.map { $0.uploadSpeed }.reduce(0, +) / Double(recentMeasurements.count)
        let avgLatency = recentMeasurements.map { $0.latency }.reduce(0, +) / Double(recentMeasurements.count)
        
        bandwidth = Bandwidth(
            download: avgDownload,
            upload: avgUpload,
            latency: avgLatency
        )
    }
    
    // MARK: - Sync Rules Management
    
    private func loadSyncRules() {
        // Load saved sync rules from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "SyncRules"),
           let rules = try? JSONDecoder().decode(SyncRules.self, from: data) {
            syncRules = rules
        }
    }
    
    func updateSyncRules(_ rules: SyncRules) {
        syncRules = rules
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: "SyncRules")
        }
        
        logger.info("Sync rules updated")
    }
    
    func shouldAllowTransfer(size: Int, priority: SyncPriority) -> Bool {
        // Check size limits
        guard size <= syncRules.maxTransferSize else {
            logger.warning("Transfer blocked: size \(size) exceeds limit \(self.syncRules.maxTransferSize)")
            return false
        }
        
        // Check priority threshold
        guard priority >= syncRules.priorityThreshold else {
            logger.debug("Transfer blocked: priority \(priority.rawValue) below threshold \(self.syncRules.priorityThreshold.rawValue)")
            return false
        }
        
        // Check data usage limits
        if connectionType == .cellular && dataUsage.cellularUsageToday > dataUsage.cellularDailyLimit {
            logger.warning("Transfer blocked: cellular data limit exceeded")
            return false
        }
        
        return true
    }
    
    // MARK: - Data Usage Tracking
    
    func recordDataUsage(_ bytes: Int64, type: DataTransferType) {
        sessionDataUsage += bytes
        
        switch type {
        case .upload:
            dataUsage.uploadedToday += bytes
            if connectionType == .cellular {
                dataUsage.cellularUsageToday += bytes
            }
        case .download:
            dataUsage.downloadedToday += bytes
            if connectionType == .cellular {
                dataUsage.cellularUsageToday += bytes
            }
        }
        
        // Reset daily counters if needed
        resetDataUsageIfNeeded()
        
        logger.debug("Data usage recorded: \(bytes) bytes (\(type.rawValue))")
    }
    
    private func resetDataUsageIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastDataUsageReset) >= dataUsageResetInterval {
            dataUsage.uploadedToday = 0
            dataUsage.downloadedToday = 0
            dataUsage.cellularUsageToday = 0
            lastDataUsageReset = now
            
            logger.info("Daily data usage counters reset")
        }
    }
    
    // MARK: - Optimization Level
    
    func setOptimizationLevel(_ level: OptimizationLevel) {
        optimizationLevel = level
        updateSyncRulesForOptimization()
        
        logger.info("Optimization level changed to: \(level.rawValue)")
    }
    
    private func updateSyncRulesForOptimization() {
        var rules = syncRules
        
        switch optimizationLevel {
        case .aggressive:
            rules.compressionEnabled = true
            rules.maxBatchSize = max(1, rules.maxBatchSize / 2)
            rules.maxTransferSize = rules.maxTransferSize / 2
            rules.priorityThreshold = .high
            
        case .balanced:
            // Keep current rules
            break
            
        case .performance:
            rules.compressionEnabled = false
            rules.maxBatchSize = rules.maxBatchSize * 2
            rules.maxTransferSize = rules.maxTransferSize * 2
            rules.priorityThreshold = .low
        }
        
        syncRules = rules
    }
    
    // MARK: - Compression Analytics
    
    private func recordCompressionResult(_ result: CompressionResult) {
        compressionHistory.append(result)
        if compressionHistory.count > maxCompressionHistory {
            compressionHistory.removeFirst()
        }
        
        updateCompressionRatio()
    }
    
    private func updateCompressionRatio() {
        guard !compressionHistory.isEmpty else {
            compressionRatio = 0
            return
        }
        
        let recentResults = compressionHistory.suffix(10)
        let avgRatio = recentResults.map { $0.ratio }.reduce(0, +) / Double(recentResults.count)
        compressionRatio = 1 - avgRatio // Convert to reduction percentage
    }
    
    // MARK: - Public Interface
    
    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // Check connection type
        if connectionType == .cellular && dataUsage.cellularUsageToday > Int64(Double(dataUsage.cellularDailyLimit) * 0.8) {
            recommendations.append(.reduceCellularUsage)
        }
        
        // Check compression effectiveness
        if compressionRatio < 0.3 && connectionType != .wifi {
            recommendations.append(.enableCompression)
        }
        
        // Check sync frequency
        if bandwidthMeasurements.last?.latency ?? 0 > 0.5 {
            recommendations.append(.reduceSyncFrequency)
        }
        
        return recommendations
    }
    
    func getCompressionStats() -> CompressionStats {
        guard !compressionHistory.isEmpty else {
            return CompressionStats()
        }
        
        let totalOriginal = compressionHistory.reduce(0) { $0 + $1.originalSize }
        let totalCompressed = compressionHistory.reduce(0) { $0 + $1.compressedSize }
        let avgRatio = Double(totalCompressed) / Double(totalOriginal)
        
        return CompressionStats(
            totalCompressions: compressionHistory.count,
            totalOriginalBytes: totalOriginal,
            totalCompressedBytes: totalCompressed,
            averageRatio: avgRatio,
            spaceSaved: totalOriginal - totalCompressed
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        pathMonitor.cancel()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case other = "Other"
    case none = "None"
}

struct Bandwidth {
    let download: Double // bytes per second
    let upload: Double // bytes per second
    let latency: TimeInterval // seconds
    
    static let unknown = Bandwidth(download: 0, upload: 0, latency: 0)
    
    var downloadMbps: Double {
        return download / (1024 * 1024) * 8
    }
    
    var uploadMbps: Double {
        return upload / (1024 * 1024) * 8
    }
}

struct SyncRules: Codable {
    var allowBulkTransfer: Bool
    var allowHighResolutionData: Bool
    var allowBackgroundSync: Bool
    var maxBatchSize: Int
    var compressionEnabled: Bool
    var maxTransferSize: Int // bytes
    var priorityThreshold: SyncPriority
    
    static let offline = SyncRules(
        allowBulkTransfer: false,
        allowHighResolutionData: false,
        allowBackgroundSync: false,
        maxBatchSize: 0,
        compressionEnabled: true,
        maxTransferSize: 0,
        priorityThreshold: .critical
    )
}

struct DataUsage {
    var uploadedToday: Int64 = 0
    var downloadedToday: Int64 = 0
    var cellularUsageToday: Int64 = 0
    let cellularDailyLimit: Int64 = 100 * 1024 * 1024 // 100MB default
    
    var totalToday: Int64 {
        return uploadedToday + downloadedToday
    }
}

enum OptimizationLevel: String, CaseIterable {
    case aggressive = "Aggressive"
    case balanced = "Balanced"
    case performance = "Performance"
}

enum SyncCompressionAlgorithm: String, CaseIterable {
    case zlib = "ZLIB"
    case lz4 = "LZ4"
    case adaptive = "Adaptive"
}

struct CompressedData {
    let data: Data
    let algorithm: SyncCompressionAlgorithm
    let originalSize: Int
    let compressedSize: Int
    let checksum: String
}

enum CompressionError: LocalizedError {
    case zlibFailed
    case lz4Failed
    case checksumMismatch
    case sizeMismatch
    
    var errorDescription: String? {
        switch self {
        case .zlibFailed: return "ZLIB compression failed"
        case .lz4Failed: return "LZ4 compression failed"
        case .checksumMismatch: return "Checksum verification failed"
        case .sizeMismatch: return "Size verification failed"
        }
    }
}

struct CompressionResult {
    let algorithm: SyncCompressionAlgorithm
    let originalSize: Int
    let compressedSize: Int
    let ratio: Double
    let duration: TimeInterval
    let timestamp: Date
}

struct BandwidthMeasurement {
    let timestamp: Date
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: TimeInterval
    let connectionType: ConnectionType
}

enum DataTransferType: String {
    case upload = "upload"
    case download = "download"
}

enum OptimizationRecommendation: String, CaseIterable {
    case reduceCellularUsage = "Reduce cellular data usage"
    case enableCompression = "Enable data compression"
    case reduceSyncFrequency = "Reduce sync frequency"
    case useWiFiOnly = "Sync only on WiFi"
}

struct CompressionStats {
    let totalCompressions: Int
    let totalOriginalBytes: Int
    let totalCompressedBytes: Int
    let averageRatio: Double
    let spaceSaved: Int
    
    init() {
        totalCompressions = 0
        totalOriginalBytes = 0
        totalCompressedBytes = 0
        averageRatio = 0
        spaceSaved = 0
    }
    
    init(totalCompressions: Int, totalOriginalBytes: Int, totalCompressedBytes: Int, averageRatio: Double, spaceSaved: Int) {
        self.totalCompressions = totalCompressions
        self.totalOriginalBytes = totalOriginalBytes
        self.totalCompressedBytes = totalCompressedBytes
        self.averageRatio = averageRatio
        self.spaceSaved = spaceSaved
    }
}