import SwiftUI
import Charts

struct StatChartView: View {
    let data: [ChartDataPoint]
    let chartType: ChartType
    let title: String
    let subtitle: String?
    let accentColor: Color
    let valueFormatter: (Double) -> String
    
    init(
        data: [ChartDataPoint],
        chartType: ChartType,
        title: String,
        subtitle: String? = nil,
        accentColor: Color = .green,
        valueFormatter: @escaping (Double) -> String = { String(format: "%.1f", $0) }
    ) {
        self.data = data
        self.chartType = chartType
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.valueFormatter = valueFormatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            chartSection
                .frame(height: 180)
        }
        .padding(20)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var chartSection: some View {
        switch chartType {
        case .line:
            lineChart
        case .bar:
            barChart
        case .area:
            areaChart
        }
    }
    
    private var lineChart: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Period", point.x),
                y: .value("Value", point.y)
            )
            .foregroundStyle(accentColor.gradient)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(valueFormatter(doubleValue))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartBackground { _ in
            Rectangle()
                .fill(.clear)
        }
    }
    
    private var barChart: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Period", point.x),
                y: .value("Value", point.y)
            )
            .foregroundStyle(accentColor.gradient)
            .cornerRadius(4, style: .continuous)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(valueFormatter(doubleValue))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartBackground { _ in
            Rectangle()
                .fill(.clear)
        }
    }
    
    private var areaChart: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Period", point.x),
                y: .value("Value", point.y)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [accentColor.opacity(0.6), accentColor.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            LineMark(
                x: .value("Period", point.x),
                y: .value("Value", point.y)
            )
            .foregroundStyle(accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(valueFormatter(doubleValue))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartBackground { _ in
            Rectangle()
                .fill(.clear)
        }
    }
}

// MARK: - Supporting Types
enum ChartType {
    case line
    case bar
    case area
}

public struct ChartDataPoint: Identifiable {
    public let id = UUID()
    public let x: String
    public let y: Double
    public let label: String?
    
    public init(x: String, y: Double, label: String? = nil) {
        self.x = x
        self.y = y
        self.label = label
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StatChartView(
            data: [
                ChartDataPoint(x: "Mon", y: 2.5),
                ChartDataPoint(x: "Tue", y: 3.2),
                ChartDataPoint(x: "Wed", y: 2.8),
                ChartDataPoint(x: "Thu", y: 4.1),
                ChartDataPoint(x: "Fri", y: 3.5),
                ChartDataPoint(x: "Sat", y: 5.2),
                ChartDataPoint(x: "Sun", y: 4.8)
            ],
            chartType: .line,
            title: "Distance This Week",
            subtitle: "Daily running distance",
            accentColor: .blue,
            valueFormatter: { "\(String(format: "%.1f", $0)) km" }
        )
        
        StatChartView(
            data: [
                ChartDataPoint(x: "Week 1", y: 12),
                ChartDataPoint(x: "Week 2", y: 18),
                ChartDataPoint(x: "Week 3", y: 15),
                ChartDataPoint(x: "Week 4", y: 22)
            ],
            chartType: .bar,
            title: "Games Per Week",
            subtitle: "Weekly game count",
            accentColor: .green,
            valueFormatter: { "\(Int($0)) games" }
        )
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}