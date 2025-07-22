import SwiftUI
import Combine

struct SyncStatusView: View {
    @StateObject private var connectivityManager = SharedWatchConnectivityManager.shared
    @StateObject private var offlineQueue = OfflineDataQueue.shared
    @StateObject private var optimizationEngine = SyncOptimizationEngine.shared
    @State private var showingDetails = false
    @State private var showingErrorRecovery = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection Status Header
            ConnectionStatusCard()
            
            // Queue Status
            QueueStatusCard()
            
            // Data Usage and Optimization
            OptimizationCard()
            
            // Action Buttons
            ActionButtonsView()
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sync Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Details") {
                    showingDetails = true
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            SyncDetailsView()
        }
        .sheet(isPresented: $showingErrorRecovery) {
            ErrorRecoveryView()
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @StateObject private var connectivityManager = SharedWatchConnectivityManager.shared
    @StateObject private var optimizationEngine = SyncOptimizationEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                connectionStatusIcon
                Text("Connection")
                    .font(.headline)
                Spacer()
                connectionBadge
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ConnectionInfoRow(
                    title: "Status",
                    value: connectivityManager.connectionState.displayText,
                    color: connectionColor
                )
                
                ConnectionInfoRow(
                    title: "Network",
                    value: optimizationEngine.connectionType.rawValue,
                    color: .secondary
                )
                
                if connectivityManager.isReachable {
                    ConnectionInfoRow(
                        title: "Last Sync",
                        value: lastSyncText,
                        color: .secondary
                    )
                }
                
                if optimizationEngine.bandwidth.download > 0 {
                    ConnectionInfoRow(
                        title: "Bandwidth",
                        value: String(format: "↓ %.1f Mbps ↑ %.1f Mbps", 
                                     optimizationEngine.bandwidth.downloadMbps,
                                     optimizationEngine.bandwidth.uploadMbps),
                        color: .secondary
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var connectionStatusIcon: some View {
        Image(systemName: connectionIconName)
            .font(.title2)
            .foregroundColor(connectionColor)
    }
    
    private var connectionIconName: String {
        switch connectivityManager.connectionState {
        case .reachable:
            return "wifi"
        case .activated:
            return "antenna.radiowaves.left.and.right"
        case .notReachable:
            return "wifi.slash"
        case .notActivated:
            return "exclamationmark.triangle"
        case .activating:
            return "antenna.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var connectionColor: Color {
        switch connectivityManager.connectionState {
        case .reachable:
            return .green
        case .activated:
            return .orange
        case .notReachable:
            return .red
        case .notActivated:
            return .red
        case .activating:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var connectionBadge: some View {
        Text(connectivityManager.isReachable ? "Connected" : "Offline")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(connectionColor.opacity(0.2))
            .foregroundColor(connectionColor)
            .cornerRadius(8)
    }
    
    private var lastSyncText: String {
        guard let lastSync = connectivityManager.lastSyncTime else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}

// MARK: - Queue Status Card

struct QueueStatusCard: View {
    @StateObject private var offlineQueue = OfflineDataQueue.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.full")
                    .font(.title2)
                    .foregroundColor(queueHealthColor)
                
                Text("Sync Queue")
                    .font(.headline)
                
                Spacer()
                
                queueHealthBadge
            }
            
            let status = offlineQueue.getQueueStatus()
            
            VStack(alignment: .leading, spacing: 6) {
                QueueInfoRow(
                    title: "Items",
                    value: "\(status.totalItems) total, \(status.pendingItems) pending",
                    icon: "doc.text"
                )
                
                QueueInfoRow(
                    title: "Size",
                    value: "\(status.formattedSize) / \(Int(status.usagePercentage))%",
                    icon: "internaldrive"
                )
                
                if status.failedItems > 0 {
                    QueueInfoRow(
                        title: "Failed",
                        value: "\(status.failedItems) items need attention",
                        icon: "exclamationmark.triangle",
                        color: .red
                    )
                }
                
                if status.isProcessing {
                    QueueInfoRow(
                        title: "Status",
                        value: "Processing queue...",
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue
                    )
                }
            }
            
            // Progress bar for queue usage
            if status.totalItems > 0 {
                ProgressView(value: status.usagePercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: queueHealthColor))
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var queueHealthColor: Color {
        switch offlineQueue.queueHealth {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var queueHealthBadge: some View {
        Text(offlineQueue.queueHealth.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(queueHealthColor.opacity(0.2))
            .foregroundColor(queueHealthColor)
            .cornerRadius(8)
    }
}

// MARK: - Optimization Card

struct OptimizationCard: View {
    @StateObject private var optimizationEngine = SyncOptimizationEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Optimization")
                    .font(.headline)
                
                Spacer()
                
                Text(optimizationEngine.optimizationLevel.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                OptimizationInfoRow(
                    title: "Compression",
                    value: String(format: "%.1f%% reduction", optimizationEngine.compressionRatio * 100),
                    icon: "archivebox"
                )
                
                OptimizationInfoRow(
                    title: "Data Used",
                    value: formatBytes(optimizationEngine.dataUsage.totalToday),
                    icon: "chart.bar"
                )
                
                if optimizationEngine.connectionType == .cellular {
                    OptimizationInfoRow(
                        title: "Cellular",
                        value: "\(formatBytes(optimizationEngine.dataUsage.cellularUsageToday)) / \(formatBytes(optimizationEngine.dataUsage.cellularDailyLimit))",
                        icon: "antenna.radiowaves.left.and.right",
                        color: cellularUsageColor
                    )
                }
            }
            
            // Recommendations
            let recommendations = optimizationEngine.getOptimizationRecommendations()
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendations, id: \.rawValue) { recommendation in
                        Text("• \(recommendation.rawValue)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var cellularUsageColor: Color {
        let usage = optimizationEngine.dataUsage.cellularUsageToday
        let limit = optimizationEngine.dataUsage.cellularDailyLimit
        let percentage = Double(usage) / Double(limit)
        
        if percentage > 0.9 {
            return .red
        } else if percentage > 0.7 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Action Buttons

struct ActionButtonsView: View {
    @StateObject private var connectivityManager = SharedWatchConnectivityManager.shared
    @StateObject private var offlineQueue = OfflineDataQueue.shared
    @State private var showingErrorRecovery = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SyncActionButton(
                    title: "Force Sync",
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    disabled: !connectivityManager.isReachable || offlineQueue.isProcessing
                ) {
                    forceSyncAction()
                }
                
                SyncActionButton(
                    title: "Clear Failed",
                    icon: "trash",
                    color: .red,
                    disabled: offlineQueue.getQueueStatus().failedItems == 0
                ) {
                    clearFailedAction()
                }
            }
            
            HStack(spacing: 12) {
                SyncActionButton(
                    title: "Test Connection",
                    icon: "wifi.circle",
                    color: .green,
                    disabled: false
                ) {
                    testConnectionAction()
                }
                
                SyncActionButton(
                    title: "Error Recovery",
                    icon: "wrench.and.screwdriver",
                    color: .orange,
                    disabled: false
                ) {
                    showingErrorRecovery = true
                }
            }
        }
        .sheet(isPresented: $showingErrorRecovery) {
            ErrorRecoveryView()
        }
    }
    
    private func forceSyncAction() {
        Task {
            await offlineQueue.forceProcessQueue()
        }
    }
    
    private func clearFailedAction() {
        Task {
            await offlineQueue.clearFailedItems()
        }
    }
    
    private func testConnectionAction() {
        connectivityManager.checkConnectionHealth()
    }
}

// MARK: - Supporting Views

struct ConnectionInfoRow: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct QueueInfoRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct OptimizationInfoRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct SyncActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(disabled ? Color.gray.opacity(0.3) : color.opacity(0.2))
            .foregroundColor(disabled ? .gray : color)
            .cornerRadius(8)
        }
        .disabled(disabled)
    }
}

// MARK: - Detail Views (Placeholder)

struct SyncDetailsView: View {
    var body: some View {
        NavigationView {
            Text("Detailed sync information would go here")
                .navigationTitle("Sync Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Done") {
                            // Dismiss
                        }
                    }
                }
        }
    }
}

struct ErrorRecoveryView: View {
    var body: some View {
        NavigationView {
            Text("Error recovery options would go here")
                .navigationTitle("Error Recovery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Done") {
                            // Dismiss
                        }
                    }
                }
        }
    }
}

#Preview {
    NavigationView {
        SyncStatusView()
    }
}