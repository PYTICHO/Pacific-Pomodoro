//
//  Pacific_PomodoroApp.swift
//  Pacific Pomodoro
//
//  Created by Давид Касаев on 14.10.2025.
//

import SwiftUI

@main
struct Pacific_PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() } // не показываем окно
    }
}

