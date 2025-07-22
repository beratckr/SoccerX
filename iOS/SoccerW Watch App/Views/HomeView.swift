//
//  HomeView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var showingActiveGame = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var isPressed = false
    
    // Mock data for last game - will be replaced with actual data
    @State private var lastGameStats = (
        distance: 5.2,
        duration: 68,
        mvpScore: 85
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // App Header - Smaller and more compact
                VStack(spacing: 4) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                        .symbolEffect(.pulse)
                    
                    Text("SoccerX")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                }
                .padding(.top, 8)
                
                // Start Button - Properly sized for watchOS
                Button(action: startGame) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.green, Color.green.opacity(0.7)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(isPressed ? 0.95 : 1.0)
                            .overlay(
                                Circle()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                                    .scaleEffect(1.1)
                                    .opacity(0.6)
                            )
                        
                        VStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("START")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .tracking(0.5)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPressed = pressing
                    }
                }, perform: {})
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: isPressed)
                
                // Last Game Summary - More compact
                if lastGameStats.distance > 0 {
                    VStack(spacing: 8) {
                        Text("LAST GAME")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        HStack(spacing: 0) {
                            // Distance
                            VStack(spacing: 1) {
                                Text("\(lastGameStats.distance, specifier: "%.1f")")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("km")
                                    .font(.system(.caption2))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Duration
                            VStack(spacing: 1) {
                                Text("\(lastGameStats.duration)")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("min")
                                    .font(.system(.caption2))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // MVP Score
                            VStack(spacing: 1) {
                                Text("\(lastGameStats.mvpScore)")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("MVP")
                                    .font(.system(.caption2))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
                
                // Quick Actions - Modern button design
                HStack(spacing: 8) {
                    Button(action: viewHistory) {
                        VStack(spacing: 2) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("History")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: viewSettings) {
                        VStack(spacing: 2) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Settings")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Connection Status - Subtle and modern
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectivityManager.connectionStatus.color)
                        .frame(width: 4, height: 4)
                    
                    Text(connectivityManager.connectionStatus.description)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .navigationDestination(isPresented: $showingActiveGame) {
                ActiveGameView()
            }
            .navigationDestination(isPresented: $showingHistory) {
                HistoryView()
            }
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private func startGame() {
        showingActiveGame = true
    }
    
    private func viewHistory() {
        showingHistory = true
    }
    
    private func viewSettings() {
        showingSettings = true
    }
}

#Preview {
    HomeView()
}