//
//  SettingsWindow.swift
//  Pacific Pomodoro
//
//  Created by Давид Касаев on 14.10.2025.
//


import SwiftUI

struct SettingsWindow: View {
    @AppStorage("workDuration") private var workDuration: Double = 25
    @AppStorage("breakDuration") private var breakDuration: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pomodoro Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Work duration: \(Int(workDuration)) min")
                Slider(value: $workDuration, in: 5...60, step: 1)
                    .accentColor(.red)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Break duration: \(Int(breakDuration)) min")
                Slider(value: $breakDuration, in: 1...30, step: 1)
                    .accentColor(.blue)
            }

            Spacer()

            Text("Changes save automatically.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300, height: 180)
    }
}
