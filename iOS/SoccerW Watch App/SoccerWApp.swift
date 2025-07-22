//
//  SoccerWApp.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 7/20/25.
//

import SwiftUI
import WatchKit

@main
struct SoccerWApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Register background tasks
        BackgroundTaskScheduler.shared.registerBackgroundTasks()
        
        // Initialize WatchConnectivity
        _ = WatchConnectivityManager.shared
        
        // Initialize SyncCoordinator
        _ = SyncCoordinator.shared
        
        print("Watch app launched, background tasks registered")
    }
    
    func applicationDidBecomeActive() {
        // App became active
        print("Watch app became active")
    }
    
    func applicationWillResignActive() {
        // App will resign active
        print("Watch app will resign active")
        
        // If tracking is active, ensure background tasks are scheduled
        if TrackingService.shared.trackingState == .tracking {
            BackgroundTaskScheduler.shared.scheduleBackgroundRefresh()
        }
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Handle system background tasks
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Handle app refresh
                BackgroundTaskScheduler.shared.scheduleBackgroundRefresh()
                backgroundTask.setTaskCompletedWithSnapshot(true)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Handle snapshot refresh
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date(timeIntervalSinceNow: 3600), userInfo: nil)
                
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Handle watch connectivity
                connectivityTask.setTaskCompletedWithSnapshot(true)
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Handle URL session
                urlSessionTask.setTaskCompletedWithSnapshot(true)
                
            default:
                // Handle other tasks
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
