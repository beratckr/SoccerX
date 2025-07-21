#!/usr/bin/env swift

// Simple test to check core watchOS Swift compilation without Firebase
import Foundation

#if os(watchOS)
import WatchKit
import HealthKit
import CoreMotion
import CoreLocation
#endif

// Test struct compilation
struct TestGameDataPoint: Codable {
    let id = UUID()
    let timestamp: Date
    let speed: Double
    
    init(timestamp: Date = Date(), speed: Double = 0) {
        self.timestamp = timestamp
        self.speed = speed
    }
}

// Test enum compilation
enum TestActivityLevel: String, Codable {
    case low = "Low"
    case medium = "Medium" 
    case high = "High"
}

// Test protocol compilation
protocol TestObservableObject {
    var isTracking: Bool { get set }
}

// Test main compilation  
print("✅ Core Swift syntax compiles successfully")
print("✅ Foundation imports work")
print("✅ Basic data structures compile")

#if os(watchOS)
print("✅ watchOS-specific imports compile")
print("✅ HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
#endif

print("🎉 Basic compilation test passed!")