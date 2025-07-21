import Foundation
import WatchConnectivity
import os.log

// MARK: - WCSessionDelegate Implementation
extension WatchConnectivityManager: WCSessionDelegate {
    
    // MARK: - Session Activation
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch activationState {
            case .activated:
                self.connectionState = .activated
                self.updateConnectionState()
                self.logger.info("WatchConnectivity session activated successfully")
                
                // Send initial heartbeat
                self.checkConnectionHealth()
                
            case .inactive:
                self.connectionState = .notActivated
                self.isReachable = false
                self.logger.warning("WatchConnectivity session became inactive")
                
            case .notActivated:
                self.connectionState = .notActivated
                self.isReachable = false
                self.logger.error("WatchConnectivity session failed to activate")
                
            @unknown default:
                self.logger.error("Unknown WatchConnectivity activation state")
            }
            
            if let error = error {
                self.syncError = .sessionNotActivated
                self.logger.error("Session activation error: \(error.localizedDescription)")
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .notActivated
            self?.isReachable = false
            self?.logger.info("iOS: Session became inactive")
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .notActivated
            self?.isReachable = false
            self?.logger.info("iOS: Session deactivated, reactivating...")
            
            // Automatically reactivate on iOS
            session.activate()
        }
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.updateConnectionState()
            self?.logger.info("iOS: Watch state changed - paired: \(session.isPaired), installed: \(session.isWatchAppInstalled), reachable: \(session.isReachable)")
        }
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.updateConnectionState()
            self?.logger.info("Reachability changed: \(session.isReachable)")
        }
    }
    
    // MARK: - Message Receiving
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message, replyHandler: nil)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message, replyHandler: replyHandler)
    }
    
    private func handleReceivedMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("Received message: \(message["type"] as? String ?? "unknown")")
            
            // Extract message components
            guard let typeString = message["type"] as? String,
                  let messageType = MessageType(rawValue: typeString),
                  let data = message["data"] as? [String: Any],
                  let timestamp = message["timestamp"] as? TimeInterval else {
                self.logger.error("Invalid message format received")
                replyHandler?(["error": "Invalid message format"])
                return
            }
            
            // Update last sync time
            self.lastSyncTime = Date(timeIntervalSince1970: timestamp)
            
            // Process message based on type
            self.processReceivedMessage(type: messageType, data: data, replyHandler: replyHandler)
        }
    }
    
    private func processReceivedMessage(
        type: MessageType,
        data: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) {
        switch type {
        case .gameStart:
            handleGameStart(data: data, replyHandler: replyHandler)
            
        case .gameUpdate:
            handleGameUpdate(data: data, replyHandler: replyHandler)
            
        case .gameEnd:
            handleGameEnd(data: data, replyHandler: replyHandler)
            
        case .bulkData:
            handleBulkData(data: data, replyHandler: replyHandler)
            
        case .syncRequest:
            handleSyncRequest(data: data, replyHandler: replyHandler)
            
        case .heartbeat:
            handleHeartbeat(data: data, replyHandler: replyHandler)
            
        case .userProfile:
            handleUserProfile(data: data, replyHandler: replyHandler)
            
        case .groupUpdate:
            handleGroupUpdate(data: data, replyHandler: replyHandler)
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleGameStart(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling game start message")
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .gameStartReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }
    
    private func handleGameUpdate(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling game update message")
        
        NotificationCenter.default.post(
            name: .gameUpdateReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "received"])
    }
    
    private func handleGameEnd(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling game end message")
        
        NotificationCenter.default.post(
            name: .gameEndReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "received"])
    }
    
    private func handleBulkData(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling bulk data message")
        
        // Extract metadata
        guard let compressed = data["compressed"] as? Bool,
              let size = data["size"] as? Int,
              let dataHash = data["dataHash"] as? String else {
            logger.error("Invalid bulk data metadata")
            replyHandler?(["error": "Invalid metadata"])
            return
        }
        
        logger.info("Expecting bulk data: \(size) bytes, compressed: \(compressed), hash: \(dataHash)")
        
        replyHandler?(["status": "ready_for_data"])
    }
    
    private func handleSyncRequest(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling sync request")
        
        // Trigger data sync
        NotificationCenter.default.post(
            name: .syncRequestReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "sync_initiated"])
    }
    
    private func handleHeartbeat(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.debug("Handling heartbeat")
        
        replyHandler?(["status": "alive", "timestamp": Date().timeIntervalSince1970])
    }
    
    private func handleUserProfile(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling user profile update")
        
        NotificationCenter.default.post(
            name: .userProfileReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "received"])
    }
    
    private func handleGroupUpdate(data: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        logger.info("Handling group update")
        
        NotificationCenter.default.post(
            name: .groupUpdateReceived,
            object: nil,
            userInfo: data
        )
        
        replyHandler?(["status": "received"])
    }
    
    // MARK: - Background Data Transfer
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        logger.info("Received background user info")
        handleReceivedMessage(userInfo, replyHandler: nil)
    }
    
    func session(_ session: WCSession, didFinishUserInfoTransfer userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.logger.error("Background transfer failed: \(error.localizedDescription)")
                self?.syncError = .messageDeliveryFailed(error)
            } else {
                self?.logger.info("Background transfer completed successfully")
                self?.lastSyncTime = Date()
            }
        }
    }
    
    // MARK: - File Transfer
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        logger.info("Received file: \(file.fileURL.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: file.fileURL)
            
            // Process received file data
            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(
                    name: .bulkDataReceived,
                    object: nil,
                    userInfo: [
                        "data": data,
                        "metadata": file.metadata ?? [:]
                    ]
                )
                
                self?.lastSyncTime = Date()
            }
            
        } catch {
            logger.error("Failed to read received file: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didFinishFileTransfer fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.logger.error("File transfer failed: \(error.localizedDescription)")
                self?.syncError = .messageDeliveryFailed(error)
            } else {
                self?.logger.info("File transfer completed successfully")
                self?.transferProgress = 1.0
                
                // Reset progress after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.transferProgress = 0
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameStartReceived = Notification.Name("gameStartReceived")
    static let gameUpdateReceived = Notification.Name("gameUpdateReceived")
    static let gameEndReceived = Notification.Name("gameEndReceived")
    static let bulkDataReceived = Notification.Name("bulkDataReceived")
    static let syncRequestReceived = Notification.Name("syncRequestReceived")
    static let userProfileReceived = Notification.Name("userProfileReceived")
    static let groupUpdateReceived = Notification.Name("groupUpdateReceived")
}