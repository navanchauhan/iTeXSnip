//
//  iTexSnipApp.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/13/24.
//

import SwiftData
import SwiftUI

@main
struct iTexSnipApp: App {
  var body: some Scene {
    //        WindowGroup {
    //            MenuBarView()
    //            .modelContainer(for: ImageSnippet.self)
    //        }
    MenuBarExtra {
      MenuBarView()
        .frame(width: 500, height: 600)
        .modelContainer(for: ImageSnippet.self)
    } label: {
      Image("menubarIcon")
    }
    .menuBarExtraStyle(.window)
    Settings {
      PreferencesView()
    }
  }
}
