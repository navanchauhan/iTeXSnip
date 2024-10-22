//
//  iTexSnipApp.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/13/24.
//

import SwiftUI
import SwiftData


@main
struct iTexSnipApp: App {
    var body: some Scene {
//        WindowGroup {
//            MenuBarView()
//            .modelContainer(for: ImageSnippet.self)
//        }
        MenuBarExtra("iTexSnip", systemImage: "function") {
                MenuBarView()
                .frame(width: 500, height: 600)
                .modelContainer(for: ImageSnippet.self)
        }.menuBarExtraStyle(.window)
        Settings {
            PreferencesView()
        }
    }
}



