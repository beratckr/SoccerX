//
//  BackgroundTaskScheduler.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import WatchKit

class BackgroundTaskScheduler {
    static let shared = BackgroundTaskScheduler()
    
    private init() {}
    
    // MARK: - Task Registration
    
    func registerBackgroundTasks() {
        // On watchOS, background tasks are handled differently
        // They are registered in the app delegate and handled through
        // the handle(_ backgroundTasks:) method
        print("Background tasks will be handled by WKApplicationDelegate")
    }
    
    // MARK: - Task Scheduling
    
    func scheduleBackgroundRefresh() {
        // Schedule a background refresh task
        let fireDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: fireDate,
            userInfo: ["type": "refresh"] as NSDictionary
        ) { error in
            if let error = error {
                print("Could not schedule background refresh: \(error)")
            } else {
                print("Background refresh scheduled for \(fireDate)")
            }
        }
    }
    
    func scheduleSnapshotRefresh() {
        // Schedule a snapshot refresh
        let fireDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        
        WKExtension.shared().scheduleSnapshotRefresh(
            withPreferredDate: fireDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("Could not schedule snapshot refresh: \(error)")
            } else {
                print("Snapshot refresh scheduled for \(fireDate)")
            }
        }
    }
    
    // MARK: - Extended Runtime Session
    
    func startExtendedRuntimeSession() {
        // Request extended runtime for active workout
        let session = WKExtendedRuntimeSession()
        session.delegate = ExtendedRuntimeSessionHandler.shared
        session.start()
        
        ExtendedRuntimeSessionHandler.shared.currentSession = session
    }
    
    func stopExtendedRuntimeSession() {
        ExtendedRuntimeSessionHandler.shared.currentSession?.invalidate()
        ExtendedRuntimeSessionHandler.shared.currentSession = nil
    }
    
    // MARK: - Helper Methods
    
    func processBackgroundTask(userInfo: Any?) {
        // Process background task based on userInfo
        if let info = userInfo as? [String: Any],
           let type = info["type"] as? String {
            
            switch type {
            case "refresh":
                handleBackgroundRefresh()
            default:
                break
            }
        }
    }
    
    private func handleBackgroundRefresh() {
        // Check if tracking is active and handle accordingly
        if TrackingService.shared.trackingState == .tracking {
            // Aggregate data point if tracking is active
            TrackingService.shared.aggregateBackgroundDataPoint()
        }
        
        // Schedule next refresh
        scheduleBackgroundRefresh()
    }
    
    func processSessionData(_ data: Data) {
        // Try to send to iPhone first
        if WatchConnectivityManager.shared.connectionStatus == .connected {
            // Send via WatchConnectivity
            WatchConnectivityManager.shared.sendUserInfo([
                "type": "pendingGameData",
                "data": data.base64EncodedString(),
                "timestamp": Date().timeIntervalSince1970
            ])
        } else {
            // Save locally for later sync
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filePath = documentsPath.appendingPathComponent("pending_sync_\(Date().timeIntervalSince1970).json")
            
            do {
                try data.write(to: filePath)
                print("Session data saved for sync: \(filePath)")
            } catch {
                print("Failed to save session data: \(error)")
            }
        }
    }
}

// MARK: - Extended Runtime Session Handler

class ExtendedRuntimeSessionHandler: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = ExtendedRuntimeSessionHandler()
    var currentSession: WKExtendedRuntimeSession?
    
    private override init() {
        super.init()
    }
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session started")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire")
        
        // Try to save current data before expiration
        if let data = TrackingService.shared.exportSessionData() {
            // Save data locally
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filePath = documentsPath.appendingPathComponent("emergency_save_\(Date().timeIntervalSince1970).json")
            try? data.write(to: filePath)
        }
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("Extended runtime session invalidated: \(reason)")
        if let error = error {
            print("Error: \(error)")
        }
    }
}