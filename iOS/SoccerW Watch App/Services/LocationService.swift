//
//  LocationService.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locations: [CLLocation] = []
    @Published var distance: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var isTracking = false
    @Published var gpsSignalStrength: GPSSignalStrength = .good
    
    enum GPSSignalStrength {
        case excellent
        case good
        case fair
        case poor
        case none
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .green
            case .fair: return .yellow
            case .poor: return .orange
            case .none: return .red
            }
        }
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .none: return "No Signal"
            }
        }
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        #endif
        
        // Set initial accuracy
        updateLocationAccuracy(for: .stationary)
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Location permission not granted")
            return
        }
        
        isTracking = true
        locations.removeAll()
        distance = 0
        currentSpeed = 0
        
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func pauseTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        if isTracking {
            locationManager.startUpdatingLocation()
        }
    }
    
    // MARK: - Adaptive Accuracy
    
    enum ActivityLevel {
        case stationary
        case walking
        case running
        case sprinting
    }
    
    private func updateLocationAccuracy(for activity: ActivityLevel) {
        switch activity {
        case .stationary:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 20
        case .walking:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
        case .running:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 5
        case .sprinting:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.distanceFilter = 2
        }
    }
    
    private func determineActivityLevel(from speed: Double) -> ActivityLevel {
        switch speed {
        case 0..<1: return .stationary
        case 1..<6: return .walking
        case 6..<20: return .running
        default: return .sprinting
        }
    }
    
    // MARK: - GPS Signal Strength
    
    private func updateGPSSignalStrength(from location: CLLocation) {
        let accuracy = location.horizontalAccuracy
        
        switch accuracy {
        case 0..<5:
            gpsSignalStrength = .excellent
        case 5..<10:
            gpsSignalStrength = .good
        case 10..<20:
            gpsSignalStrength = .fair
        case 20..<50:
            gpsSignalStrength = .poor
        default:
            gpsSignalStrength = .none
        }
    }
    
    // MARK: - Distance Calculation
    
    private func calculateDistance() {
        guard locations.count >= 2 else { return }
        
        var totalDistance: Double = 0
        for i in 1..<locations.count {
            let previousLocation = locations[i-1]
            let currentLocation = locations[i]
            totalDistance += currentLocation.distance(from: previousLocation)
        }
        
        distance = totalDistance
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // Start monitoring location if we have permission
            if isTracking {
                startTracking()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out invalid locations
        guard newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy < 50 else { return }
        
        // Update current location
        currentLocation = newLocation
        
        // Add to locations array
        self.locations.append(newLocation)
        
        // Update speed
        currentSpeed = max(0, newLocation.speed * 3.6) // Convert m/s to km/h
        
        // Update GPS signal strength
        updateGPSSignalStrength(from: newLocation)
        
        // Update accuracy based on activity
        let activity = determineActivityLevel(from: currentSpeed)
        updateLocationAccuracy(for: activity)
        
        // Calculate total distance
        calculateDistance()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        gpsSignalStrength = .none
    }
}

// Make sure to import SwiftUI for Color
import SwiftUI