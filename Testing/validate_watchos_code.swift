#!/usr/bin/env swift

import Foundation

// Validation script for watchOS SoccerX implementation
// This script checks for common compilation issues without requiring Xcode

struct ValidationResult {
    let filename: String
    let issues: [String]
    var hasErrors: Bool { !issues.isEmpty }
}

class CodeValidator {
    private var results: [ValidationResult] = []
    
    func validateWatchOSImplementation() {
        print("🔍 Validating watchOS SoccerX Implementation...")
        print(String(repeating: "=", count: 50))
        
        let watchOSPath = "/Users/furkan/SoccerX/iOS/SoccerXWatch"
        
        // Check if watchOS directory exists
        guard FileManager.default.fileExists(atPath: watchOSPath) else {
            print("❌ ERROR: watchOS directory not found at \(watchOSPath)")
            return
        }
        
        // Validate each created file
        validateFile("\(watchOSPath)/Services/HealthKitManager.swift")
        validateFile("\(watchOSPath)/Services/WorkoutManager.swift") 
        validateFile("\(watchOSPath)/Services/LocationManager.swift")
        validateFile("\(watchOSPath)/Services/DataAggregationManager.swift")
        validateFile("\(watchOSPath)/Services/BatteryOptimizationManager.swift")
        validateFile("\(watchOSPath)/Services/LocalStorageManager.swift")
        validateFile("\(watchOSPath)/Models/GameDataPoint.swift")
        validateFile("\(watchOSPath)/Models/GameSession.swift")
        validateFile("\(watchOSPath)/Views/Tracking/GameTrackingView.swift")
        validateFile("\(watchOSPath)/Views/Tracking/MainTrackingView.swift")
        validateFile("\(watchOSPath)/Views/Home/PermissionRequestView.swift")
        validateFile("\(watchOSPath)/Views/Home/WatchHomeView.swift")
        validateFile("\(watchOSPath)/Views/Details/CountdownView.swift")
        validateFile("\(watchOSPath)/Views/Details/HeartRateDetailView.swift")
        validateFile("\(watchOSPath)/Views/Details/SpeedDetailView.swift")
        validateFile("\(watchOSPath)/Views/Details/SplitsView.swift")
        validateFile("\(watchOSPath)/Views/Details/CaloriesDetailView.swift")
        validateFile("\(watchOSPath)/SoccerXWatchApp.swift")
        validateFile("\(watchOSPath)/SoccerXWatch-Info.plist")
        
        // Print summary
        printSummary()
    }
    
    private func validateFile(_ filepath: String) {
        let filename = URL(fileURLWithPath: filepath).lastPathComponent
        var issues: [String] = []
        
        guard FileManager.default.fileExists(atPath: filepath) else {
            issues.append("File does not exist")
            results.append(ValidationResult(filename: filename, issues: issues))
            return
        }
        
        guard let content = try? String(contentsOfFile: filepath) else {
            issues.append("Cannot read file content")
            results.append(ValidationResult(filename: filename, issues: issues))
            return
        }
        
        // Check for common Swift compilation issues
        if filename.hasSuffix(".swift") {
            issues.append(contentsOf: validateSwiftSyntax(content, filename: filename))
        } else if filename.hasSuffix(".plist") {
            issues.append(contentsOf: validatePlistSyntax(content, filename: filename))
        }
        
        results.append(ValidationResult(filename: filename, issues: issues))
    }
    
    private func validateSwiftSyntax(_ content: String, filename: String) -> [String] {
        var issues: [String] = []
        
        // Check imports
        let requiredImports = [
            "HealthKit": ["HealthKitManager.swift", "WorkoutManager.swift"],
            "CoreLocation": ["LocationManager.swift"],
            "CoreMotion": ["LocationManager.swift", "HealthKitManager.swift"],
            "SwiftUI": ["GameTrackingView.swift", "MainTrackingView.swift", "PermissionRequestView.swift"],
            "Combine": ["DataAggregationManager.swift", "GameTrackingView.swift"]
        ]
        
        for (importName, files) in requiredImports {
            if files.contains(filename) && !content.contains("import \(importName)") {
                issues.append("Missing required import: \(importName)")
            }
        }
        
        // Check for common syntax errors
        let openBraces = content.components(separatedBy: "{").count - 1
        let closeBraces = content.components(separatedBy: "}").count - 1
        if openBraces != closeBraces {
            issues.append("Mismatched braces: \(openBraces) open, \(closeBraces) close")
        }
        
        let openParens = content.components(separatedBy: "(").count - 1
        let closeParens = content.components(separatedBy: ")").count - 1
        if openParens != closeParens {
            issues.append("Mismatched parentheses: \(openParens) open, \(closeParens) close")
        }
        
        // Check for incomplete function definitions
        if content.contains("func ") {
            let funcCount = content.components(separatedBy: "func ").count - 1
            let funcBodyCount = content.components(separatedBy: "func ").dropFirst().filter { 
                $0.contains("{") 
            }.count
            if funcCount != funcBodyCount {
                issues.append("Possible incomplete function definitions")
            }
        }
        
        // Check for @MainActor usage with proper context
        if content.contains("@MainActor") && !content.contains("class") && !content.contains("func") {
            issues.append("@MainActor used without proper context")
        }
        
        // Check for proper ObservableObject conformance
        if content.contains("ObservableObject") && !content.contains("@Published") {
            issues.append("ObservableObject class without @Published properties")
        }
        
        return issues
    }
    
    private func validatePlistSyntax(_ content: String, filename: String) -> [String] {
        var issues: [String] = []
        
        // Check basic XML structure
        if !content.contains("<?xml") {
            issues.append("Missing XML declaration")
        }
        
        if !content.contains("<!DOCTYPE plist") {
            issues.append("Missing plist DOCTYPE")
        }
        
        if !content.contains("<plist version=\"1.0\">") {
            issues.append("Missing or incorrect plist version")
        }
        
        // Check for required Info.plist keys for watchOS
        let requiredKeys = [
            "NSHealthShareUsageDescription",
            "NSHealthUpdateUsageDescription", 
            "NSMotionUsageDescription",
            "NSLocationWhenInUseUsageDescription"
        ]
        
        for key in requiredKeys {
            if !content.contains(key) {
                issues.append("Missing required key: \(key)")
            }
        }
        
        return issues
    }
    
    private func printSummary() {
        print("\n📊 Validation Summary")
        print(String(repeating: "=", count: 30))
        
        let totalFiles = results.count
        let filesWithErrors = results.filter { $0.hasErrors }.count
        let totalIssues = results.flatMap { $0.issues }.count
        
        print("📁 Total files checked: \(totalFiles)")
        print("❌ Files with issues: \(filesWithErrors)")
        print("⚠️  Total issues found: \(totalIssues)")
        
        if filesWithErrors == 0 {
            print("\n✅ No compilation issues detected!")
            print("🎉 Implementation appears ready for build testing")
        } else {
            print("\n⚠️  Issues found:")
            for result in results.filter({ $0.hasErrors }) {
                print("\n📄 \(result.filename):")
                for issue in result.issues {
                    print("   • \(issue)")
                }
            }
            print("\n🔧 Please fix these issues before proceeding")
        }
        
        print("\n🏗️  Next Steps:")
        if filesWithErrors == 0 {
            print("1. Open project in Xcode")
            print("2. Add watchOS target if not present")
            print("3. Build for watchOS Simulator")
            print("4. Test on physical Apple Watch")
        } else {
            print("1. Fix the issues listed above")
            print("2. Re-run this validation")
            print("3. Proceed with build testing")
        }
    }
}

// Run validation
let validator = CodeValidator()
validator.validateWatchOSImplementation()