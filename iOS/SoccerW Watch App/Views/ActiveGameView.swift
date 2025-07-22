//
//  ActiveGameView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import SwiftUI
import WatchKit

struct ActiveGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var trackingService = TrackingService.shared
    @StateObject private var locationService = LocationService.shared
    @StateObject private var healthKitService = HealthKitService.shared
    
    @State private var showingStopConfirmation = false
    @State private var showingGameSummary = false
    @State private var currentStatPage = 0
    @State private var isWaterLocked = false
    
    // Computed properties for UI
    private var heartRateZoneColor: Color {
        healthKitService.heartRateZone.color
    }
    
    private var heartRateZoneHeight: CGFloat {
        switch healthKitService.heartRateZone {
        case .resting: return 0.2
        case .warmup: return 0.4
        case .fatBurn: return 0.6
        case .cardio: return 0.8
        case .peak: return 0.9
        case .maximum: return 1.0
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main Content
                VStack(spacing: 0) {
                    // Status Bar
                    HStack {
                        Image(systemName: "sportscourt.fill")
                            .foregroundColor(.green)
                            .symbolEffect(.pulse)
                        
                        Spacer()
                        
                        Text(Date(), style: .time)
                            .font(.system(.footnote, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    
                    // Water Lock Indicator
                    if isWaterLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .padding(.top, 10)
                    }
                    
                    // Main Stats
                    TabView(selection: $currentStatPage) {
                        // Page 1: Main Stats
                        VStack(spacing: 12) {
                            // Duration
                            VStack(spacing: 2) {
                                Text(formatTime(trackingService.elapsedTime))
                                    .font(.system(size: 32, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                Text("DURATION")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .tracking(0.5)
                            }
                            
                            // Stats Grid - More compact
                            VStack(spacing: 8) {
                                // Distance - Primary stat
                                HStack {
                                    Text("\(locationService.distance / 1000, specifier: "%.2f")")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                    Text("km")
                                        .font(.system(.callout, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                
                                HStack(spacing: 8) {
                                    // Heart Rate
                                    VStack(spacing: 2) {
                                        Text("\(healthKitService.heartRate)")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundColor(heartRateZoneColor)
                                        Text("BPM")
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                    
                                    // Speed
                                    VStack(spacing: 2) {
                                        Text("\(locationService.currentSpeed, specifier: "%.1f")")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                        Text("km/h")
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                }
                            }
                            
                            // Heart Rate Zone Indicator
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 4, height: 40)
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(heartRateZoneColor)
                                                .frame(width: 4, height: 40 * heartRateZoneHeight)
                                        }
                                    )
                                    .position(x: geometry.size.width - 20, y: 20)
                            }
                            .frame(height: 40)
                        }
                        .padding(.horizontal)
                        .tag(0)
                        
                        // Page 2: Detailed Stats (placeholder for now)
                        VStack {
                            Text("Detailed Stats")
                                .font(.title3)
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                        .tag(1)
                        
                        // Page 3: Map View (placeholder for now)
                        VStack {
                            Text("Route Map")
                                .font(.title3)
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                        .tag(2)
                    }
                    .tabViewStyle(.verticalPage)
                    
                    Spacer()
                    
                    // Control Buttons - Modern watchOS design
                    HStack(spacing: 8) {
                        Button(action: togglePause) {
                            HStack(spacing: 6) {
                                Image(systemName: trackingService.isPaused ? "play.fill" : "pause.fill")
                                    .font(.body)
                                Text(trackingService.isPaused ? "Resume" : "Pause")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(trackingService.isPaused ? .green : .orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(trackingService.isPaused ? .green.opacity(0.15) : .orange.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isWaterLocked)
                        
                        Button(action: { showingStopConfirmation = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                    .font(.body)
                                Text("Stop")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.red.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isWaterLocked)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                
                // Page Indicator - More subtle and modern
                if currentStatPage != 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            if index == currentStatPage {
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 4)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.6))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 80)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: currentStatPage)
                }
            }
            .fullScreenCover(isPresented: $showingGameSummary) {
                if let session = trackingService.currentSession {
                    GameSummaryView(gameData: GameSummaryData(
                        distance: session.totalDistance / 1000, // Convert to km
                        duration: Int(session.duration),
                        avgSpeed: session.averageSpeed,
                        maxSpeed: session.maxSpeed,
                        calories: Int(session.totalCalories),
                        isPersonalBest: false
                    ))
                }
            }
            .alert("Stop Game?", isPresented: $showingStopConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Stop", role: .destructive) {
                    stopGame()
                }
            } message: {
                Text("Are you sure you want to stop tracking this game?")
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startTracking()
        }
        .onDisappear {
            // Clean up if needed
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func togglePause() {
        if trackingService.isPaused {
            trackingService.resumeTracking()
        } else {
            trackingService.pauseTracking()
        }
        WKInterfaceDevice.current().play(.click)
    }
    
    private func stopGame() {
        Task {
            do {
                try await trackingService.stopTracking()
                
                // Prepare game summary data
                guard let session = trackingService.currentSession else { return }
                
                showingGameSummary = true
            } catch {
                print("Error stopping game: \(error)")
            }
        }
    }
    
    private func startTracking() {
        Task {
            do {
                // Request permissions first if needed
                try await trackingService.requestPermissions()
                
                // Start tracking
                try await trackingService.startTracking()
            } catch {
                print("Error starting tracking: \(error)")
                // Show error alert to user
            }
        }
    }
}

#Preview {
    ActiveGameView()
}