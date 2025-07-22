//
//  WatchConnectivityManager.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private let session = WCSession.default
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isReachable = false
    #if os(iOS)
    @Published var isPaired = false
    @Published var isComplicationEnabled = false
    #endif
    @Published var hasContentPending = false
    @Published var receivedMessage: [String: Any] = [:]
    @Published var connectionStatus: ConnectionStatus = .notConnected
    
    enum ConnectionStatus {
        case notConnected
        case connecting
        case connected
        case disconnected
        
        var description: String {
            switch self {
            case .notConnected: return "Not Connected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            }
        }
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .connecting: return .orange
            case .notConnected, .disconnected: return .red
            }
        }
    }
    
    private override init() {
        super.init()
        setupSession()
        setupObservers()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported")
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    private func setupObservers() {
        // Observe tracking service changes to sync with iPhone
        TrackingService.shared.$trackingState
            .sink { [weak self] state in
                self?.sendTrackingStateUpdate(state)
            }
            .store(in: &cancellables)
        
        TrackingService.shared.$currentSession
            .compactMap { $0 }
            .sink { [weak self] session in
                self?.sendGameSessionUpdate(session)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard session.isReachable else {
            print("iPhone is not reachable")
            errorHandler?(WCError(.notReachable))
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
            print("Error sending message: \(error)")
            errorHandler?(error)
        })
    }
    
    func sendUserInfo(_ userInfo: [String: Any]) {
        guard session.activationState == .activated else {
            print("Session not activated")
            return
        }
        
        session.transferUserInfo(userInfo)
    }
    
    func sendApplicationContext(_ context: [String: Any]) {
        guard session.activationState == .activated else {
            print("Session not activated")
            return
        }
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Error updating application context: \(error)")
        }
    }
    
    // MARK: - Game Data Sync
    
    private func sendTrackingStateUpdate(_ state: TrackingService.TrackingState) {
        let message: [String: Any] = [
            "type": "trackingStateUpdate",
            "state": state.description,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            sendMessage(message)
        } else {
            // Queue for later delivery
            sendUserInfo(message)
        }
    }
    
    private func sendGameSessionUpdate(_ session: TrackingSession) {
        let message: [String: Any] = [
            "type": "gameSessionUpdate",
            "sessionId": session.id.uuidString,
            "startTime": session.startTime.timeIntervalSince1970,
            "distance": session.totalDistance,
            "calories": session.totalCalories,
            "avgHeartRate": session.averageHeartRate,
            "maxHeartRate": session.maxHeartRate,
            "avgSpeed": session.averageSpeed,
            "maxSpeed": session.maxSpeed,
            "duration": session.duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if self.session.isReachable {
            sendMessage(message)
        } else {
            // Queue for later delivery
            sendUserInfo(message)
        }
    }
    
    func sendGameDataPoint(_ dataPoint: TrackingDataPoint) {
        let message: [String: Any] = [
            "type": "gameDataPoint",
            "timestamp": dataPoint.timestamp.timeIntervalSince1970,
            "heartRate": dataPoint.heartRate,
            "speed": dataPoint.speed,
            "distance": dataPoint.distance,
            "calories": dataPoint.calories,
            "altitude": dataPoint.altitude ?? 0,
            "latitude": dataPoint.location?.coordinate.latitude ?? 0,
            "longitude": dataPoint.location?.coordinate.longitude ?? 0
        ]
        
        // For real-time data, only send if reachable
        if session.isReachable {
            sendMessage(message)
        }
    }
    
    func sendGameCompleted(_ session: TrackingSession) {
        guard let data = TrackingService.shared.exportSessionData() else { return }
        
        let message: [String: Any] = [
            "type": "gameCompleted",
            "sessionId": session.id.uuidString,
            "sessionData": data.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Use UserInfo for important data that must be delivered
        sendUserInfo(message)
    }
    
    // MARK: - Receiving Data
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.receivedMessage = message
            
            switch type {
            case "userProfileUpdate":
                // Handle user profile updates from iPhone
                if let userId = message["userId"] as? String {
                    print("Received user profile update for: \(userId)")
                }
                
            case "groupUpdate":
                // Handle group updates from iPhone
                if let groupId = message["groupId"] as? String {
                    print("Received group update for: \(groupId)")
                }
                
            case "settingsUpdate":
                // Handle settings updates from iPhone
                if let settings = message["settings"] as? [String: Any] {
                    print("Received settings update: \(settings)")
                }
                
            default:
                print("Unknown message type: \(type)")
            }
        }
    }
    
    // MARK: - File Transfer
    
    func sendGameSessionFile(_ fileURL: URL, metadata: [String: Any]? = nil) {
        guard session.activationState == .activated else { return }
        
        session.transferFile(fileURL, metadata: metadata)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Session activation failed: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = .disconnected
            }
            return
        }
        
        print("Session activated with state: \(activationState.rawValue)")
        DispatchQueue.main.async {
            self.connectionStatus = activationState == .activated ? .connected : .notConnected
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isComplicationEnabled = session.isComplicationEnabled
            #endif
            self.hasContentPending = session.hasContentPending
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.connectionStatus = session.isReachable ? .connected : .disconnected
        }
    }
    
    // MARK: - Message Reception
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        
        // Send acknowledgment
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleReceivedMessage(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleReceivedMessage(applicationContext)
    }
    
    // MARK: - File Reception
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Handle received files from iPhone
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent(file.fileURL.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)
            print("Received file saved to: \(destinationURL)")
            
            // Process the file based on metadata
            if let metadata = file.metadata,
               let type = metadata["type"] as? String {
                switch type {
                case "userProfile":
                    // Process user profile data
                    break
                case "groupData":
                    // Process group data
                    break
                default:
                    break
                }
            }
        } catch {
            print("Error saving received file: \(error)")
        }
    }
}

// Import SwiftUI for Color
import SwiftUI