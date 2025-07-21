import SwiftUI
import Charts
import FirebaseFirestore

struct PerformanceChartView: View {
    let games: [Game]
    let timeRange: TimeRange
    
    @State private var selectedMetric: PerformanceMetric = .distance
    
    enum PerformanceMetric: String, CaseIterable {
        case distance = "Distance"
        case speed = "Avg Speed"
        case mvpScore = "MVP Score"
        case duration = "Duration"
        
        var color: Color {
            switch self {
            case .distance: return .blue
            case .speed: return .orange
            case .mvpScore: return .green
            case .duration: return .purple
            }
        }
        
        var unit: String {
            switch self {
            case .distance: return "km"
            case .speed: return "km/h"
            case .mvpScore: return "pts"
            case .duration: return "min"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "3M"
        case allTime = "All"
        
        var description: String {
            switch self {
            case .week: return "Last 7 days"
            case .month: return "Last 30 days"
            case .threeMonths: return "Last 3 months"
            case .allTime: return "All time"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            metricSelector
            chartSection
            summarySection
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(timeRange.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let average = currentAverage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("AVG")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatValue(average, for: selectedMetric))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedMetric.color)
                }
            }
        }
    }
    
    private var metricSelector: some View {
        HStack(spacing: 12) {
            ForEach(PerformanceMetric.allCases, id: \.self) { metric in
                Button(action: {
                    selectedMetric = metric
                }) {
                    Text(metric.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMetric == metric ? metric.color : Color(.systemGray5))
                                .opacity(selectedMetric == metric ? 1.0 : 0.3)
                        )
                        .foregroundColor(selectedMetric == metric ? .white : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var chartSection: some View {
        if chartData.isEmpty {
            emptyStateView
        } else {
            Chart(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .symbolSize(25)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatValue(doubleValue, for: selectedMetric, compact: true))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedMetric)
                .frame(height: 200)
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: 16) {
            if let best = currentBest {
                summaryItem(title: "BEST", value: formatValue(best, for: selectedMetric), color: .green)
            }
            
            if let recent = currentRecent {
                summaryItem(title: "RECENT", value: formatValue(recent, for: selectedMetric), color: .blue)
            }
            
            summaryItem(title: "GAMES", value: "\(filteredGames.count)", color: .secondary)
        }
    }
    
    private func summaryItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Play some games to see your performance trends")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    private var filteredGames: [Game] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate: Date = {
            switch timeRange {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: now) ?? now
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .allTime:
                return Date.distantPast
            }
        }()
        
        return games
            .filter { game in
                guard let startTime = game.startTime else { return false }
                return startTime.dateValue() >= cutoffDate && game.isCompleted
            }
            .sorted { game1, game2 in
                guard let date1 = game1.startTime, let date2 = game2.startTime else { return false }
                return date1.dateValue() < date2.dateValue()
            }
    }
    
    private var chartData: [PerformanceDataPoint] {
        return filteredGames.compactMap { game in
            guard let startTime = game.startTime else { return nil }
            
            let value: Double = {
                switch selectedMetric {
                case .distance: return game.distance
                case .speed: return game.avgSpeed
                case .mvpScore: return game.mvpScore ?? 0
                case .duration: return Double(game.duration) / 60.0 // Convert to minutes
                }
            }()
            
            return PerformanceDataPoint(date: startTime.dateValue(), value: value)
        }
    }
    
    private var currentAverage: Double? {
        guard !chartData.isEmpty else { return nil }
        let sum = chartData.reduce(0) { $0 + $1.value }
        return sum / Double(chartData.count)
    }
    
    private var currentBest: Double? {
        return chartData.map(\.value).max()
    }
    
    private var currentRecent: Double? {
        return chartData.last?.value
    }
    
    private func formatValue(_ value: Double, for metric: PerformanceMetric, compact: Bool = false) -> String {
        switch metric {
        case .distance:
            return compact ? String(format: "%.1f", value) : String(format: "%.1f %@", value, metric.unit)
        case .speed:
            return compact ? String(format: "%.1f", value) : String(format: "%.1f %@", value, metric.unit)
        case .mvpScore:
            return compact ? String(format: "%.0f", value) : String(format: "%.0f %@", value, metric.unit)
        case .duration:
            return compact ? String(format: "%.0f", value) : String(format: "%.0f %@", value, metric.unit)
        }
    }
}

// MARK: - Supporting Types
struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Preview
#Preview {
    let sampleGames = [
        Game(userId: "user1", distance: 2.5, avgSpeed: 12.3, maxSpeed: 18.5, duration: 3600),
        Game(userId: "user1", distance: 3.1, avgSpeed: 13.1, maxSpeed: 19.2, duration: 4200),
        Game(userId: "user1", distance: 2.8, avgSpeed: 11.8, maxSpeed: 17.9, duration: 3900),
        Game(userId: "user1", distance: 3.5, avgSpeed: 14.2, maxSpeed: 20.1, duration: 4500)
    ]
    
    PerformanceChartView(games: sampleGames, timeRange: .week)
        .padding()
        .background(.black)
        .preferredColorScheme(.dark)
}

// MARK: - Game Extension for Preview
extension Game {
    init(userId: String, distance: Double, avgSpeed: Double, maxSpeed: Double, duration: Int) {
        self.userId = userId
        self.distance = distance
        self.avgSpeed = avgSpeed
        self.maxSpeed = maxSpeed
        self.duration = duration
        self.isCompleted = true
        
        // Set a mock start time for preview
        let calendar = Calendar.current
        let daysAgo = Int.random(in: 1...7)
        self.startTime = Timestamp(date: calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date())
    }
}