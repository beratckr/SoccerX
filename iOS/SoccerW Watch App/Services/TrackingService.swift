//
//  TrackingService.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import Combine
import CoreLocation
import HealthKit

// MARK: - Game Data Models

struct TrackingDataPoint {
    let timestamp: Date
    let location: CLLocation?
    let heartRate: Int
    let speed: Double
    let distance: Double
    let calories: Double
    let altitude: Double?
}

struct TrackingSession {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var dataPoints: [TrackingDataPoint]
    var totalDistance: Double
    var totalCalories: Double
    var averageHeartRate: Int
    var maxHeartRate: Int
    var averageSpeed: Double
    var maxSpeed: Double
    var duration: TimeInterval
    
    init() {
        self.id = UUID()
        self.startTime = Date()
        self.dataPoints = []
        self.totalDistance = 0
        self.totalCalories = 0
        self.averageHeartRate = 0
        self.maxHeartRate = 0
        self.averageSpeed = 0
        self.maxSpeed = 0
        self.duration = 0
    }
}

// MARK: - Tracking Service

class TrackingService: ObservableObject {
    static let shared = TrackingService()
    
    // Services
    private let locationService = LocationService.shared
    private let healthKitService = HealthKitService.shared
    
    // State
    @Published var trackingState: TrackingState = .idle
    @Published var currentSession: TrackingSession?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isPaused = false
    
    // Data aggregation
    private var dataAggregationTimer: Timer?
    private var elapsedTimeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum TrackingState {
        case idle
        case preparing
        case tracking
        case paused
        case stopping
        case stopped
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .preparing: return "Preparing..."
            case .tracking: return "Tracking"
            case .paused: return "Paused"
            case .stopping: return "Stopping..."
            case .stopped: return "Stopped"
            }
        }
    }
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe location updates
        locationService.$distance
            .sink { [weak self] distance in
                self?.currentSession?.totalDistance = distance
            }
            .store(in: &cancellables)
        
        // Observe heart rate updates
        healthKitService.$heartRate
            .sink { [weak self] heartRate in
                guard let session = self?.currentSession else { return }
                if heartRate > session.maxHeartRate {
                    self?.currentSession?.maxHeartRate = heartRate
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func requestPermissions() async throws {
        // Request location permission
        locationService.requestPermission()
        
        // Request HealthKit permission
        try await healthKitService.requestAuthorization()
    }
    
    func startTracking() async throws {
        trackingState = .preparing
        
        // Initialize new session
        currentSession = TrackingSession()
        elapsedTime = 0
        isPaused = false
        
        // Start services
        locationService.startTracking()
        try await healthKitService.startWorkout()
        
        // Start timers
        startDataAggregationTimer()
        startElapsedTimeTimer()
        
        // Start extended runtime session for background tracking
        BackgroundTaskScheduler.shared.startExtendedRuntimeSession()
        
        // Schedule background tasks
        BackgroundTaskScheduler.shared.scheduleBackgroundRefresh()
        BackgroundTaskScheduler.shared.scheduleSnapshotRefresh()
        
        trackingState = .tracking
    }
    
    func pauseTracking() {
        guard trackingState == .tracking else { return }
        
        trackingState = .paused
        isPaused = true
        
        // Pause services
        locationService.pauseTracking()
        healthKitService.pauseWorkout()
        
        // Pause timers
        dataAggregationTimer?.invalidate()
        elapsedTimeTimer?.invalidate()
    }
    
    func resumeTracking() {
        guard trackingState == .paused else { return }
        
        trackingState = .tracking
        isPaused = false
        
        // Resume services
        locationService.resumeTracking()
        healthKitService.resumeWorkout()
        
        // Resume timers
        startDataAggregationTimer()
        startElapsedTimeTimer()
    }
    
    func stopTracking() async throws {
        trackingState = .stopping
        
        // Stop timers
        dataAggregationTimer?.invalidate()
        elapsedTimeTimer?.invalidate()
        
        // Finalize session data
        currentSession?.endTime = Date()
        currentSession?.duration = elapsedTime
        
        // Calculate final statistics
        calculateFinalStatistics()
        
        // Stop services
        locationService.stopTracking()
        try await healthKitService.endWorkout()
        
        // Stop extended runtime session
        BackgroundTaskScheduler.shared.stopExtendedRuntimeSession()
        
        // Send game completed to iPhone
        if let session = currentSession {
            WatchConnectivityManager.shared.sendGameCompleted(session)
        }
        
        trackingState = .stopped
    }
    
    // MARK: - Private Methods
    
    private func startDataAggregationTimer() {
        dataAggregationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.aggregateDataPoint()
        }
    }
    
    private func startElapsedTimeTimer() {
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.elapsedTime += 1
        }
    }
    
    private func aggregateDataPoint() {
        let dataPoint = TrackingDataPoint(
            timestamp: Date(),
            location: locationService.currentLocation,
            heartRate: healthKitService.heartRate,
            speed: locationService.currentSpeed,
            distance: locationService.distance,
            calories: healthKitService.activeCalories,
            altitude: locationService.currentLocation?.altitude
        )
        
        currentSession?.dataPoints.append(dataPoint)
        
        // Update max speed
        if dataPoint.speed > (currentSession?.maxSpeed ?? 0) {
            currentSession?.maxSpeed = dataPoint.speed
        }
        
        // Send data point to iPhone
        WatchConnectivityManager.shared.sendGameDataPoint(dataPoint)
    }
    
    private func calculateFinalStatistics() {
        guard let session = currentSession, !session.dataPoints.isEmpty else { return }
        
        // Calculate average heart rate
        let totalHeartRate = session.dataPoints.reduce(0) { $0 + $1.heartRate }
        currentSession?.averageHeartRate = totalHeartRate / session.dataPoints.count
        
        // Calculate average speed
        let totalSpeed = session.dataPoints.reduce(0) { $0 + $1.speed }
        currentSession?.averageSpeed = totalSpeed / Double(session.dataPoints.count)
        
        // Update final values
        currentSession?.totalDistance = locationService.distance
        currentSession?.totalCalories = healthKitService.activeCalories
    }
    
    // MARK: - Background Support
    
    func aggregateBackgroundDataPoint() {
        // Only aggregate if actively tracking
        guard trackingState == .tracking else { return }
        
        aggregateDataPoint()
        print("Background data point aggregated at \(Date())")
    }
    
    // MARK: - Data Export
    
    func exportSessionData() -> Data? {
        guard let session = currentSession else { return nil }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(session)
        } catch {
            print("Failed to encode session data: \(error)")
            return nil
        }
    }
}

// Make TrackingSession Codable for export
extension TrackingSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, totalDistance, totalCalories
        case averageHeartRate, maxHeartRate, averageSpeed, maxSpeed, duration
        case dataPoints
    }
}

extension TrackingDataPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, heartRate, speed, distance, calories, altitude
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(heartRate, forKey: .heartRate)
        try container.encode(speed, forKey: .speed)
        try container.encode(distance, forKey: .distance)
        try container.encode(calories, forKey: .calories)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(location?.coordinate.latitude, forKey: .latitude)
        try container.encode(location?.coordinate.longitude, forKey: .longitude)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        heartRate = try container.decode(Int.self, forKey: .heartRate)
        speed = try container.decode(Double.self, forKey: .speed)
        distance = try container.decode(Double.self, forKey: .distance)
        calories = try container.decode(Double.self, forKey: .calories)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocation(latitude: lat, longitude: lon)
        } else {
            location = nil
        }
    }
}