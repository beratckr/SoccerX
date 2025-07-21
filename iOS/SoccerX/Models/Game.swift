import Foundation
import FirebaseFirestore
import CoreLocation

struct Game: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    var groupIds: [String] = []
    @ServerTimestamp var startTime: Timestamp?
    var endTime: Timestamp?
    var duration: Int = 0 // in seconds
    var distance: Double = 0 // in kilometers
    var avgSpeed: Double = 0 // in km/h
    var maxSpeed: Double = 0 // in km/h
    var mvpScore: Double?
    var scoreBreakdown: MVPScoreBreakdown?
    var gpsRouteUrl: String? // Cloud Storage URL
    var heartRateData: HeartRateData?
    var events: [GameEvent] = []
    var weather: WeatherData?
    var isCompleted: Bool = false
    @ServerTimestamp var processedAt: Timestamp?
    
    // Computed properties
    var durationFormatted: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var distanceFormatted: String {
        String(format: "%.2f km", distance)
    }
    
    var avgSpeedFormatted: String {
        String(format: "%.1f km/h", avgSpeed)
    }
    
    var maxSpeedFormatted: String {
        String(format: "%.1f km/h", maxSpeed)
    }
    
    var dateFormatted: String? {
        guard let startTime = startTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime.dateValue())
    }
}

struct MVPScoreBreakdown: Codable {
    let distanceScore: Double
    let avgSpeedScore: Double
    let maxSpeedScore: Double
    let heartRateEfficiencyScore: Double
    let consistencyScore: Double
    let totalScore: Double
    let weatherBonus: Double?
    
    // Weights for each metric
    static let weights = (
        distance: 0.3,
        avgSpeed: 0.2,
        maxSpeed: 0.15,
        heartRateEfficiency: 0.2,
        consistency: 0.15
    )
}

struct HeartRateData: Codable {
    let average: Int
    let max: Int
    let min: Int
    let zones: HeartRateZones
    var samples: [HeartRateSample] = []
    
    // Calculate efficiency based on time in optimal zone
    var efficiency: Double {
        let optimalPercentage = zones.aerobic + zones.anaerobic
        return Swift.min(optimalPercentage / 0.8, 1.0) // 80% in aerobic/anaerobic is optimal
    }
}

struct HeartRateZones: Codable {
    let resting: Double // % of time
    let warmup: Double
    let aerobic: Double
    let anaerobic: Double
    let maximum: Double
}

struct HeartRateSample: Codable {
    let timestamp: Date
    let value: Int
}

struct GameEvent: Codable {
    let id: String
    let type: EventType
    let timestamp: Date
    let location: GeoPoint?
    let metadata: [String: String]?
    
    enum EventType: String, Codable {
        case start = "start"
        case pause = "pause"
        case resume = "resume"
        case end = "end"
        case goal = "goal"
        case assist = "assist"
        case save = "save"
        case foul = "foul"
        case yellowCard = "yellow_card"
        case redCard = "red_card"
        case substitution = "substitution"
        case injury = "injury"
        case hydration = "hydration"
    }
}

struct WeatherData: Codable {
    let temperature: Double // Celsius
    let humidity: Double // Percentage
    let windSpeed: Double // km/h
    let condition: String // e.g., "clear", "rain", "cloudy"
    let uvIndex: Int?
    
    // Calculate weather impact on performance
    var performanceModifier: Double {
        var modifier = 1.0
        
        // Temperature impact
        if temperature < 5 || temperature > 35 {
            modifier -= 0.1
        } else if temperature < 10 || temperature > 30 {
            modifier -= 0.05
        }
        
        // Wind impact
        if windSpeed > 30 {
            modifier -= 0.1
        } else if windSpeed > 20 {
            modifier -= 0.05
        }
        
        // Rain bonus (playing in tough conditions)
        if condition == "rain" {
            modifier += 0.05
        }
        
        return max(0.8, min(1.1, modifier))
    }
}

// MARK: - Firestore Extensions
extension Game {
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "groupIds": groupIds,
            "duration": duration,
            "distance": distance,
            "avgSpeed": avgSpeed,
            "maxSpeed": maxSpeed,
            "events": events.map { $0.toDictionary() },
            "isCompleted": isCompleted
        ]
        
        if startTime == nil {
            data["startTime"] = FieldValue.serverTimestamp()
        }
        
        if let endTime = endTime {
            data["endTime"] = endTime
        }
        
        if let mvpScore = mvpScore {
            data["mvpScore"] = mvpScore
        }
        
        if let scoreBreakdown = scoreBreakdown {
            data["scoreBreakdown"] = scoreBreakdown.toFirestore()
        }
        
        if let gpsRouteUrl = gpsRouteUrl {
            data["gpsRouteUrl"] = gpsRouteUrl
        }
        
        if let heartRateData = heartRateData {
            data["heartRateData"] = heartRateData.toFirestore()
        }
        
        if let weather = weather {
            data["weather"] = weather.toFirestore()
        }
        
        if let processedAt = processedAt {
            data["processedAt"] = processedAt
        }
        
        return data
    }
}

extension GameEvent {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "timestamp": Timestamp(date: timestamp)
        ]
        
        if let location = location {
            dict["location"] = location
        }
        
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        
        return dict
    }
}

extension MVPScoreBreakdown {
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "distanceScore": distanceScore,
            "avgSpeedScore": avgSpeedScore,
            "maxSpeedScore": maxSpeedScore,
            "heartRateEfficiencyScore": heartRateEfficiencyScore,
            "consistencyScore": consistencyScore,
            "totalScore": totalScore
        ]
        
        if let weatherBonus = weatherBonus {
            data["weatherBonus"] = weatherBonus
        }
        
        return data
    }
}

extension HeartRateData {
    func toFirestore() -> [String: Any] {
        return [
            "average": average,
            "max": max,
            "min": min,
            "zones": [
                "resting": zones.resting,
                "warmup": zones.warmup,
                "aerobic": zones.aerobic,
                "anaerobic": zones.anaerobic,
                "maximum": zones.maximum
            ],
            "efficiency": efficiency
        ]
    }
}

extension WeatherData {
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "temperature": temperature,
            "humidity": humidity,
            "windSpeed": windSpeed,
            "condition": condition,
            "performanceModifier": performanceModifier
        ]
        
        if let uvIndex = uvIndex {
            data["uvIndex"] = uvIndex
        }
        
        return data
    }
}