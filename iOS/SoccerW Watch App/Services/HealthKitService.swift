//
//  HealthKitService.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import HealthKit
import Combine

class HealthKitService: NSObject, ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isAuthorized = false
    @Published var heartRate: Int = 0
    @Published var activeCalories: Double = 0
    @Published var workoutDistance: Double = 0
    @Published var isWorkoutActive = false
    
    // Heart rate zone calculation
    var heartRateZone: HeartRateZone {
        // Assuming average max heart rate (220 - age), using 30 as default age
        let maxHeartRate = 190 // This should be calculated based on user's age
        let percentage = Double(heartRate) / Double(maxHeartRate)
        
        switch percentage {
        case 0..<0.5: return .resting
        case 0.5..<0.6: return .warmup
        case 0.6..<0.7: return .fatBurn
        case 0.7..<0.8: return .cardio
        case 0.8..<0.9: return .peak
        default: return .maximum
        }
    }
    
    enum HeartRateZone {
        case resting
        case warmup
        case fatBurn
        case cardio
        case peak
        case maximum
        
        var color: Color {
            switch self {
            case .resting: return .blue
            case .warmup: return .green
            case .fatBurn: return .yellow
            case .cardio: return .orange
            case .peak: return .red
            case .maximum: return .purple
            }
        }
        
        var description: String {
            switch self {
            case .resting: return "Resting"
            case .warmup: return "Warm Up"
            case .fatBurn: return "Fat Burn"
            case .cardio: return "Cardio"
            case .peak: return "Peak"
            case .maximum: return "Maximum"
            }
        }
    }
    
    override init() {
        super.init()
        checkHealthKitAvailability()
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        
        // Define the types we want to write
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        isAuthorized = true
    }
    
    // MARK: - Workout Session Management
    
    func startWorkout() async throws {
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .soccer
        configuration.locationType = .outdoor
        
        // Create workout session
        workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        
        // Set up delegates
        workoutSession?.delegate = self
        workoutBuilder?.delegate = self
        
        // Configure data source
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        
        // Start the workout session and builder
        let startDate = Date()
        workoutSession?.startActivity(with: startDate)
        try await workoutBuilder?.beginCollection(at: startDate)
        
        isWorkoutActive = true
        
        // Start collecting heart rate data
        startHeartRateQuery()
    }
    
    func pauseWorkout() {
        workoutSession?.pause()
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
    }
    
    func endWorkout() async throws {
        workoutSession?.end()
        try await workoutBuilder?.endCollection(at: Date())
        
        // Save the workout
        try await workoutBuilder?.finishWorkout()
        
        isWorkoutActive = false
        heartRate = 0
        activeCalories = 0
        workoutDistance = 0
    }
    
    // MARK: - Heart Rate Monitoring
    
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        healthStore.execute(heartRateQuery)
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Get the most recent heart rate
            if let mostRecent = samples.last {
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let value = mostRecent.quantity.doubleValue(for: heartRateUnit)
                self.heartRate = Int(value)
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitService: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, 
                       didChangeTo toState: HKWorkoutSessionState, 
                       from fromState: HKWorkoutSessionState, 
                       date: Date) {
        
        DispatchQueue.main.async { [weak self] in
            switch toState {
            case .running:
                self?.isWorkoutActive = true
            case .paused:
                self?.isWorkoutActive = false
            case .ended:
                self?.isWorkoutActive = false
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, 
                       didFailWithError error: Error) {
        print("Workout session error: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitService: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, 
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async { [weak self] in
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    if let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                        self?.heartRate = Int(value)
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    if let value = statistics?.sumQuantity()?.doubleValue(for: energyUnit) {
                        self?.activeCalories = value
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    let distanceUnit = HKUnit.meter()
                    if let value = statistics?.sumQuantity()?.doubleValue(for: distanceUnit) {
                        self?.workoutDistance = value / 1000 // Convert to kilometers
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// Import SwiftUI for Color
import SwiftUI