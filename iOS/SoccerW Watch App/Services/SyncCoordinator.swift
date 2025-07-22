//
//  SyncCoordinator.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import Combine
import WatchKit

class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var pendingDataCount = 0
    @Published var syncStatus: SyncStatus = .idle
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
        
        var description: String {
            switch self {
            case .idle: return "Ready to sync"
            case .syncing: return "Syncing..."
            case .success: return "Synced successfully"
            case .failed(let error): return "Sync failed: \(error.localizedDescription)"
            }
        }
    }
    
    private init() {
        setupObservers()
        startPeriodicSync()
        checkPendingData()
    }
    
    private func setupObservers() {
        // Monitor connectivity changes
        WatchConnectivityManager.shared.$connectionStatus
            .sink { [weak self] status in
                if status == .connected {
                    // Attempt sync when connection is established
                    self?.attemptSync()
                }
            }
            .store(in: &cancellables)
        
        // Monitor tracking state changes
        TrackingService.shared.$trackingState
            .sink { [weak self] state in
                if state == .stopped {
                    // Attempt sync after game completion
                    self?.attemptSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.attemptSync()
        }
    }
    
    func attemptSync() {
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        Task {
            await performSync()
        }
    }
    
    private func performSync() async {
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }
        
        do {
            // Check for pending local files
            let pendingFiles = getPendingLocalFiles()
            pendingDataCount = pendingFiles.count
            
            // Send each pending file
            for file in pendingFiles {
                try await sendPendingFile(file)
            }
            
            // Check for cached tracking data
            if let cachedData = getCachedTrackingData() {
                try await sendCachedData(cachedData)
            }
            
            await MainActor.run {
                lastSyncTime = Date()
                syncStatus = .success
                pendingDataCount = 0
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
            }
            print("Sync failed: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    private func getPendingLocalFiles() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            return files.filter { $0.lastPathComponent.hasPrefix("pending_sync_") }
        } catch {
            print("Error getting pending files: \(error)")
            return []
        }
    }
    
    private func sendPendingFile(_ url: URL) async throws {
        guard let data = try? Data(contentsOf: url) else {
            throw SyncError.fileReadError
        }
        
        // Send via WatchConnectivity
        if WatchConnectivityManager.shared.connectionStatus == .connected {
            WatchConnectivityManager.shared.sendUserInfo([
                "type": "pendingGameData",
                "data": data.base64EncodedString(),
                "timestamp": Date().timeIntervalSince1970
            ])
            
            // Delete file after successful send
            try FileManager.default.removeItem(at: url)
            print("Sent and deleted pending file: \(url)")
        } else {
            throw SyncError.notConnected
        }
    }
    
    private func getCachedTrackingData() -> Data? {
        // Check if there's any cached tracking data that hasn't been sent
        if let session = TrackingService.shared.currentSession,
           session.dataPoints.count > 0 {
            return TrackingService.shared.exportSessionData()
        }
        return nil
    }
    
    private func sendCachedData(_ data: Data) async throws {
        if WatchConnectivityManager.shared.connectionStatus == .connected {
            WatchConnectivityManager.shared.sendUserInfo([
                "type": "cachedTrackingData",
                "data": data.base64EncodedString(),
                "timestamp": Date().timeIntervalSince1970
            ])
        } else {
            throw SyncError.notConnected
        }
    }
    
    private func checkPendingData() {
        let files = getPendingLocalFiles()
        pendingDataCount = files.count
    }
    
    enum SyncError: LocalizedError {
        case notConnected
        case fileReadError
        case encodingError
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "iPhone not connected"
            case .fileReadError:
                return "Failed to read pending file"
            case .encodingError:
                return "Failed to encode data"
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}