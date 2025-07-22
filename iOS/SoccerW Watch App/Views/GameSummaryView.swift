//
//  GameSummaryView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import SwiftUI
import WatchKit

struct GameSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveConfirmation = false
    @State private var isSaving = false
    
    // Game data - will be passed in from ActiveGameView
    let gameData: GameSummaryData
    
    // Mock MVP score calculation
    private var mvpScore: Int {
        let distanceScore = min(gameData.distance * 10, 30)
        let durationScore = min(Double(gameData.duration) / 60 * 15, 30)
        let speedScore = min(gameData.avgSpeed * 2, 20)
        let consistencyScore = 20.0 // Mock consistency
        
        return Int(distanceScore + durationScore + speedScore + consistencyScore)
    }
    
    private var mvpScoreColor: Color {
        switch mvpScore {
        case 0..<50: return .red
        case 50..<70: return .orange
        case 70..<85: return .yellow
        default: return .green
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Game Complete Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                            .symbolEffect(.bounce)
                        
                        Text("Game Complete!")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 10)
                    
                    // MVP Score
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(mvpScore) / 100)
                            .stroke(mvpScoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: mvpScore)
                        
                        VStack(spacing: 4) {
                            Text("\(mvpScore)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("MVP SCORE")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                        }
                    }
                    
                    // Key Stats
                    VStack(spacing: 12) {
                        // Distance & Duration
                        HStack(spacing: 12) {
                            StatBox(
                                value: String(format: "%.2f", gameData.distance),
                                unit: "km",
                                label: "DISTANCE",
                                icon: "location.fill"
                            )
                            
                            StatBox(
                                value: formatDuration(gameData.duration),
                                unit: "",
                                label: "DURATION",
                                icon: "clock.fill"
                            )
                        }
                        
                        // Speed Stats
                        HStack(spacing: 12) {
                            StatBox(
                                value: String(format: "%.1f", gameData.avgSpeed),
                                unit: "km/h",
                                label: "AVG SPEED",
                                icon: "speedometer"
                            )
                            
                            StatBox(
                                value: String(format: "%.1f", gameData.maxSpeed),
                                unit: "km/h",
                                label: "MAX SPEED",
                                icon: "bolt.fill"
                            )
                        }
                        
                        // Calories
                        StatBox(
                            value: "\(gameData.calories)",
                            unit: "cal",
                            label: "CALORIES",
                            icon: "flame.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Personal Best Indicator
                    if gameData.isPersonalBest {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("New Personal Best!")
                                .font(.system(.footnote, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(20)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: saveGame) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Game")
                                        .font(.system(.footnote, design: .rounded))
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .disabled(isSaving)
                        
                        HStack(spacing: 12) {
                            Button(action: shareGame) {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                            }
                            
                            Button(action: startNewGame) {
                                Text("New Game")
                                    .font(.system(.footnote, design: .rounded))
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .alert("Save Game?", isPresented: $showingSaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    performSave()
                }
            } message: {
                Text("This will save your game data and sync with your iPhone.")
            }
        }
        .navigationBarHidden(true)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func saveGame() {
        showingSaveConfirmation = true
    }
    
    private func performSave() {
        isSaving = true
        
        // Simulate saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaving = false
            dismiss()
        }
    }
    
    private func shareGame() {
        // TODO: Implement share functionality
        WKInterfaceDevice.current().play(.click)
    }
    
    private func startNewGame() {
        // TODO: Navigate to new game
        dismiss()
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(.caption2))
                .foregroundColor(.green)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Data Model

struct GameSummaryData {
    let distance: Double
    let duration: Int // seconds
    let avgSpeed: Double
    let maxSpeed: Double
    let calories: Int
    let isPersonalBest: Bool
    
    // Mock data for preview
    static let mock = GameSummaryData(
        distance: 5.42,
        duration: 3720, // 62 minutes
        avgSpeed: 12.3,
        maxSpeed: 22.5,
        calories: 485,
        isPersonalBest: true
    )
}

#Preview {
    GameSummaryView(gameData: .mock)
}