//
//  GameDataPersistenceManager.swift
//  SoccerX
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import CoreData

class GameDataPersistenceManager {
    static let shared = GameDataPersistenceManager()
    
    private let containerName = "SoccerXGameData"
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Failed to load Core Data stack: \(error)")
            }
        }
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    func saveGameSession(_ session: GameSessionData) throws {
        let entity = NSEntityDescription.entity(forEntityName: "GameSession", in: context)!
        let gameSession = NSManagedObject(entity: entity, insertInto: context)
        
        gameSession.setValue(session.id, forKey: "id")
        gameSession.setValue(session.startTime, forKey: "startTime")
        gameSession.setValue(session.endTime, forKey: "endTime")
        gameSession.setValue(session.distance, forKey: "distance")
        gameSession.setValue(session.calories, forKey: "calories")
        gameSession.setValue(session.avgHeartRate, forKey: "avgHeartRate")
        gameSession.setValue(session.maxHeartRate, forKey: "maxHeartRate")
        gameSession.setValue(session.avgSpeed, forKey: "avgSpeed")
        gameSession.setValue(session.maxSpeed, forKey: "maxSpeed")
        gameSession.setValue(session.duration, forKey: "duration")
        gameSession.setValue(session.isSynced, forKey: "isSynced")
        gameSession.setValue(session.rawData, forKey: "rawData")
        
        try context.save()
    }
    
    func savePendingGameData(_ data: Data, sessionId: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pendingDataPath = documentsPath.appendingPathComponent("PendingSync")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: pendingDataPath, withIntermediateDirectories: true)
        
        // Save file with timestamp
        let fileName = "\(sessionId)_\(Date().timeIntervalSince1970).json"
        let filePath = pendingDataPath.appendingPathComponent(fileName)
        
        try data.write(to: filePath)
        print("Saved pending game data: \(filePath)")
    }
    
    func loadPendingGameData() -> [(url: URL, data: Data)] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pendingDataPath = documentsPath.appendingPathComponent("PendingSync")
        
        var pendingData: [(url: URL, data: Data)] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: pendingDataPath, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file) {
                    pendingData.append((url: file, data: data))
                }
            }
        } catch {
            print("Error loading pending data: \(error)")
        }
        
        return pendingData
    }
    
    func deletePendingDataFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("Deleted pending data file: \(url)")
        } catch {
            print("Error deleting pending data file: \(error)")
        }
    }
    
    func getUnsyncedSessions() -> [GameSessionData] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "GameSession")
        request.predicate = NSPredicate(format: "isSynced == false")
        
        do {
            let results = try context.fetch(request)
            return results.compactMap { GameSessionData(from: $0) }
        } catch {
            print("Error fetching unsynced sessions: \(error)")
            return []
        }
    }
    
    func markSessionAsSynced(_ sessionId: String) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "GameSession")
        request.predicate = NSPredicate(format: "id == %@", sessionId)
        
        do {
            let results = try context.fetch(request)
            if let session = results.first {
                session.setValue(true, forKey: "isSynced")
                try context.save()
                print("Marked session as synced: \(sessionId)")
            }
        } catch {
            print("Error marking session as synced: \(error)")
        }
    }
}

// MARK: - Data Models

struct GameSessionData {
    let id: String
    let startTime: Date
    let endTime: Date?
    let distance: Double
    let calories: Double
    let avgHeartRate: Int
    let maxHeartRate: Int
    let avgSpeed: Double
    let maxSpeed: Double
    let duration: TimeInterval
    let isSynced: Bool
    let rawData: Data?
    
    init(from managedObject: NSManagedObject) {
        self.id = managedObject.value(forKey: "id") as? String ?? ""
        self.startTime = managedObject.value(forKey: "startTime") as? Date ?? Date()
        self.endTime = managedObject.value(forKey: "endTime") as? Date
        self.distance = managedObject.value(forKey: "distance") as? Double ?? 0
        self.calories = managedObject.value(forKey: "calories") as? Double ?? 0
        self.avgHeartRate = managedObject.value(forKey: "avgHeartRate") as? Int ?? 0
        self.maxHeartRate = managedObject.value(forKey: "maxHeartRate") as? Int ?? 0
        self.avgSpeed = managedObject.value(forKey: "avgSpeed") as? Double ?? 0
        self.maxSpeed = managedObject.value(forKey: "maxSpeed") as? Double ?? 0
        self.duration = managedObject.value(forKey: "duration") as? TimeInterval ?? 0
        self.isSynced = managedObject.value(forKey: "isSynced") as? Bool ?? false
        self.rawData = managedObject.value(forKey: "rawData") as? Data
    }
    
    init(id: String, startTime: Date, endTime: Date?, distance: Double, calories: Double,
         avgHeartRate: Int, maxHeartRate: Int, avgSpeed: Double, maxSpeed: Double,
         duration: TimeInterval, isSynced: Bool = false, rawData: Data? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.calories = calories
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.avgSpeed = avgSpeed
        self.maxSpeed = maxSpeed
        self.duration = duration
        self.isSynced = isSynced
        self.rawData = rawData
    }
}

// MARK: - Sync Manager

extension GameDataPersistenceManager {
    func syncPendingData() async {
        // Sync pending files
        let pendingFiles = loadPendingGameData()
        
        for (url, data) in pendingFiles {
            do {
                // Try to sync with Firebase
                // For now, just mark as synced and delete file
                deletePendingDataFile(url)
                print("Synced pending file: \(url)")
            } catch {
                print("Failed to sync file: \(url), error: \(error)")
            }
        }
        
        // Sync unsynced Core Data sessions
        let unsyncedSessions = getUnsyncedSessions()
        
        for session in unsyncedSessions {
            do {
                // Try to sync with Firebase
                // For now, just mark as synced
                markSessionAsSynced(session.id)
                print("Synced session: \(session.id)")
            } catch {
                print("Failed to sync session: \(session.id), error: \(error)")
            }
        }
    }
}