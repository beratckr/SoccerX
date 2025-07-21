//
//  ContentView.swift
//  SoccerW Watch App
//
//  Created by Furkan CAKIR on 7/20/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "sportscourt")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("SoccerW")
                    .font(.headline)
                Text("Track Your Game")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}