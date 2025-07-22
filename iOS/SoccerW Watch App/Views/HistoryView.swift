//
//  HistoryView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Mock data for demonstration
    @State private var recentGames = [
        (date: "Today", distance: 5.2, duration: 68, mvp: 85),
        (date: "Yesterday", distance: 4.8, duration: 55, mvp: 78),
        (date: "2 days ago", distance: 6.1, duration: 72, mvp: 92),
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Button("Back") {
                            dismiss()
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("History")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Recent Games
                    VStack(spacing: 8) {
                        ForEach(Array(recentGames.enumerated()), id: \.offset) { index, game in
                            VStack(spacing: 6) {
                                HStack {
                                    Text(game.date)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("MVP: \(game.mvp)")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                
                                HStack(spacing: 0) {
                                    VStack(spacing: 2) {
                                        Text("\(game.distance, specifier: "%.1f")")
                                            .font(.system(.callout, design: .rounded))
                                            .fontWeight(.semibold)
                                        Text("km")
                                            .font(.system(.caption2))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(spacing: 2) {
                                        Text("\(game.duration)")
                                            .font(.system(.callout, design: .rounded))
                                            .fontWeight(.semibold)
                                        Text("min")
                                            .font(.system(.caption2))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    HistoryView()
}