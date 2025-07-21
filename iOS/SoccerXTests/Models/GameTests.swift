import XCTest
@testable import SoccerX
import CoreLocation
import FirebaseFirestore

class GameTests: XCTestCase {
    
    var sut: Game!
    
    override func setUp() {
        super.setUp()
        sut = Game(userId: "user123")
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testGameInitialization() {
        XCTAssertEqual(sut.userId, "user123")
        XCTAssertEqual(sut.groupIds.count, 0)
        XCTAssertNil(sut.startTime)
        XCTAssertNil(sut.endTime)
        XCTAssertEqual(sut.duration, 0)
        XCTAssertEqual(sut.distance, 0)
        XCTAssertEqual(sut.avgSpeed, 0)
        XCTAssertEqual(sut.maxSpeed, 0)
        XCTAssertNil(sut.mvpScore)
        XCTAssertNil(sut.scoreBreakdown)
        XCTAssertNil(sut.gpsRouteUrl)
        XCTAssertNil(sut.heartRateData)
        XCTAssertEqual(sut.events.count, 0)
        XCTAssertNil(sut.weather)
        XCTAssertFalse(sut.isCompleted)
        XCTAssertNil(sut.processedAt)
    }
    
    // MARK: - Computed Properties Tests
    
    func testDurationFormattedUnderHour() {
        sut.duration = 2700 // 45 minutes
        XCTAssertEqual(sut.durationFormatted, "45:00")
    }
    
    func testDurationFormattedWithSeconds() {
        sut.duration = 3665 // 61 minutes 5 seconds
        XCTAssertEqual(sut.durationFormatted, "61:05")
    }
    
    func testAvgSpeedFormatted() {
        sut.avgSpeed = 12.567
        XCTAssertEqual(sut.avgSpeedFormatted, "12.6 km/h")
    }
    
    func testMaxSpeedFormatted() {
        sut.maxSpeed = 25.123
        XCTAssertEqual(sut.maxSpeedFormatted, "25.1 km/h")
    }
    
    func testDistanceFormatted() {
        sut.distance = 5.678
        XCTAssertEqual(sut.distanceFormatted, "5.68 km")
    }
    
    func testDateFormattedWhenNil() {
        XCTAssertNil(sut.dateFormatted)
    }
    
    // MARK: - Game Event Tests
    
    func testAddingGameEvent() {
        let event = GameEvent(
            id: "event1",
            type: .goal,
            timestamp: Date(),
            location: GeoPoint(latitude: 40.7128, longitude: -74.0060),
            metadata: ["assistedBy": "player2"]
        )
        
        sut.events.append(event)
        
        XCTAssertEqual(sut.events.count, 1)
        XCTAssertEqual(sut.events.first?.type, .goal)
        XCTAssertEqual(sut.events.first?.metadata?["assistedBy"], "player2")
    }
    
    func testMultipleGameEvents() {
        let events = [
            GameEvent(id: "1", type: .start, timestamp: Date(), location: nil, metadata: nil),
            GameEvent(id: "2", type: .goal, timestamp: Date(), location: nil, metadata: nil),
            GameEvent(id: "3", type: .assist, timestamp: Date(), location: nil, metadata: nil),
            GameEvent(id: "4", type: .yellowCard, timestamp: Date(), location: nil, metadata: nil),
            GameEvent(id: "5", type: .end, timestamp: Date(), location: nil, metadata: nil)
        ]
        
        sut.events = events
        
        XCTAssertEqual(sut.events.count, 5)
        XCTAssertEqual(sut.events.filter { $0.type == .goal }.count, 1)
        XCTAssertEqual(sut.events.filter { $0.type == .assist }.count, 1)
        XCTAssertEqual(sut.events.filter { $0.type == .yellowCard }.count, 1)
    }
    
    // MARK: - Heart Rate Data Tests
    
    func testHeartRateDataEfficiency() {
        let zones = HeartRateZones(
            resting: 0.1,
            warmup: 0.15,
            aerobic: 0.45,
            anaerobic: 0.25,
            maximum: 0.05
        )
        
        let heartRateData = HeartRateData(
            average: 145,
            max: 180,
            min: 60,
            zones: zones,
            samples: []
        )
        
        sut.heartRateData = heartRateData
        
        // Efficiency should be (0.45 + 0.25) / 0.8 = 0.875
        XCTAssertEqual(sut.heartRateData?.efficiency, 0.875, accuracy: 0.001)
    }
    
    func testHeartRateDataMaxEfficiency() {
        let zones = HeartRateZones(
            resting: 0.05,
            warmup: 0.05,
            aerobic: 0.5,
            anaerobic: 0.35,
            maximum: 0.05
        )
        
        let heartRateData = HeartRateData(
            average: 155,
            max: 185,
            min: 65,
            zones: zones,
            samples: []
        )
        
        sut.heartRateData = heartRateData
        
        // Efficiency should be capped at 1.0
        XCTAssertEqual(sut.heartRateData?.efficiency, 1.0)
    }
    
    // MARK: - MVP Score Tests
    
    func testMVPScoreBreakdown() {
        let breakdown = MVPScoreBreakdown(
            distanceScore: 85,
            avgSpeedScore: 80,
            maxSpeedScore: 75,
            heartRateEfficiencyScore: 90,
            consistencyScore: 88,
            totalScore: 84.5,
            weatherBonus: 5
        )
        
        sut.mvpScore = 84.5
        sut.scoreBreakdown = breakdown
        
        XCTAssertEqual(sut.mvpScore, 84.5)
        XCTAssertEqual(sut.scoreBreakdown?.totalScore, 84.5)
        XCTAssertEqual(sut.scoreBreakdown?.weatherBonus, 5)
    }
    
    // MARK: - Weather Data Tests
    
    func testWeatherDataPerformanceModifier() {
        // Test ideal conditions
        let idealWeather = WeatherData(
            temperature: 20,
            humidity: 60,
            windSpeed: 10,
            condition: "clear",
            uvIndex: 5
        )
        XCTAssertEqual(idealWeather.performanceModifier, 1.0)
        
        // Test cold weather
        let coldWeather = WeatherData(
            temperature: 3,
            humidity: 80,
            windSpeed: 5,
            condition: "cloudy",
            uvIndex: 1
        )
        XCTAssertEqual(coldWeather.performanceModifier, 0.9, accuracy: 0.01)
        
        // Test hot weather with strong wind
        let extremeWeather = WeatherData(
            temperature: 38,
            humidity: 90,
            windSpeed: 35,
            condition: "clear",
            uvIndex: 10
        )
        XCTAssertEqual(extremeWeather.performanceModifier, 0.8, accuracy: 0.01)
        
        // Test rain bonus
        let rainyWeather = WeatherData(
            temperature: 18,
            humidity: 85,
            windSpeed: 15,
            condition: "rain",
            uvIndex: 2
        )
        XCTAssertEqual(rainyWeather.performanceModifier, 1.05, accuracy: 0.01)
    }
    
    // MARK: - Firestore Conversion Tests
    
    func testToFirestoreWithCompleteData() {
        sut.groupIds = ["group123", "group456"]
        sut.duration = 3600
        sut.distance = 8.5
        sut.avgSpeed = 8.5
        sut.maxSpeed = 22.0
        sut.mvpScore = 85.5
        sut.isCompleted = true
        sut.gpsRouteUrl = "https://storage.googleapis.com/game123.json"
        
        let firestoreData = sut.toFirestore()
        
        XCTAssertEqual(firestoreData["userId"] as? String, "user123")
        XCTAssertEqual(firestoreData["groupIds"] as? [String], ["group123", "group456"])
        XCTAssertEqual(firestoreData["duration"] as? Int, 3600)
        XCTAssertEqual(firestoreData["distance"] as? Double, 8.5)
        XCTAssertEqual(firestoreData["avgSpeed"] as? Double, 8.5)
        XCTAssertEqual(firestoreData["maxSpeed"] as? Double, 22.0)
        XCTAssertEqual(firestoreData["mvpScore"] as? Double, 85.5)
        XCTAssertEqual(firestoreData["isCompleted"] as? Bool, true)
        XCTAssertEqual(firestoreData["gpsRouteUrl"] as? String, "https://storage.googleapis.com/game123.json")
    }
    
    func testToFirestoreWithMinimalData() {
        let firestoreData = sut.toFirestore()
        
        XCTAssertEqual(firestoreData["userId"] as? String, "user123")
        XCTAssertEqual(firestoreData["groupIds"] as? [String], [])
        XCTAssertEqual(firestoreData["duration"] as? Int, 0)
        XCTAssertEqual(firestoreData["distance"] as? Double, 0)
        XCTAssertFalse(firestoreData["isCompleted"] as? Bool ?? true)
        XCTAssertNil(firestoreData["mvpScore"])
        XCTAssertNil(firestoreData["scoreBreakdown"])
    }
    
    // MARK: - Edge Cases
    
    func testGameWithZeroDuration() {
        sut.duration = 0
        XCTAssertEqual(sut.durationFormatted, "0:00")
    }
    
    func testGameWithVeryHighSpeed() {
        sut.maxSpeed = 99.99
        XCTAssertEqual(sut.maxSpeedFormatted, "100.0 km/h")
    }
    
    func testGameEventTypes() {
        let eventTypes: [GameEvent.EventType] = [
            .start, .pause, .resume, .end,
            .goal, .assist, .save, .foul,
            .yellowCard, .redCard, .substitution,
            .injury, .hydration
        ]
        
        // Test all event types can be created
        for (index, eventType) in eventTypes.enumerated() {
            let event = GameEvent(
                id: "event\(index)",
                type: eventType,
                timestamp: Date(),
                location: nil,
                metadata: nil
            )
            XCTAssertEqual(event.type, eventType)
        }
    }
}