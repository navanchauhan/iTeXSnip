//
//  PreferencesView.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/21/24.
//

import SwiftUI

struct PreferencesView: View {
  @AppStorage("apiEndpoint") var apiEndpoint: String =
    "https://snippetfeedback.itexsnip.navan.dev/rate_snippet"
  @AppStorage("loadModelOnStart") var loadModelOnStart: Bool = true
  @AppStorage("showOriginalImage") var showOriginalImage: Bool = false

  var body: some View {
    Form {
      Section(header: Text("API Settings")) {
        TextField("Rating API Endpoint", text: $apiEndpoint)
          .textFieldStyle(RoundedBorderTextFieldStyle())
      }

      Section(header: Text("Application Settings")) {
        Toggle("Load model on app start", isOn: $loadModelOnStart)
        Toggle("Show original image by default", isOn: $showOriginalImage)
      }
    }
    .padding(20)
    .frame(width: 400, height: 200)
  }
}
