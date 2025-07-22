//
//  SettingsView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 1/21/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hapticFeedback = true
    @State private var voiceAnnouncements = false
    @State private var autoLock = true
    
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
                        
                        Text("Settings")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Settings Options
                    VStack(spacing: 8) {
                        // Haptic Feedback
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic Feedback")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.medium)
                                Text("Vibration during workouts")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $hapticFeedback)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                        )
                        
                        // Voice Announcements
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voice Updates")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.medium)
                                Text("Audio progress updates")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $voiceAnnouncements)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                        )
                        
                        // Auto Lock
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto Water Lock")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.medium)
                                Text("Prevent accidental touches")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $autoLock)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                        )
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABOUT")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Version")
                                        .font(.system(.callout, design: .rounded))
                                    Spacer()
                                    Text("1.0.0")
                                        .font(.system(.callout, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Build")
                                        .font(.system(.callout, design: .rounded))
                                    Spacer()
                                    Text("1")
                                        .font(.system(.callout, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    SettingsView()
}