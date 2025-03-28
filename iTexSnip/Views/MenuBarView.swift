//
//  MenuBarView.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/20/24.
//

import AppKit
import LaTeXSwiftUI
import SwiftData
import SwiftUI

@Model
class ImageSnippet {
  var dateCreated: Date
  var dateModifed: Date
  var image: Data
  var transcribedText: String?
  var rating: Bool?

  init(image: NSImage, transcribedText: String? = nil) {
    self.dateCreated = Date()
    self.image = image.tiffRepresentation!
    self.transcribedText = transcribedText
    self.dateModifed = Date()
  }

  func updateModifiedDate() {
    self.dateModifed = Date()
  }

  func rate(_ rating: Bool?) {
    self.rating = rating
  }
}

struct MenuBarView: View {
  @Environment(\.modelContext) var modelContext
  @State var model: TexTellerModel?
  @State var processingImage: Bool = false
  @Query(sort: \ImageSnippet.dateModifed, order: .reverse) var snippets: [ImageSnippet]
  @AppStorage("loadModelOnStart") var loadModelOnStart: Bool = true
  @AppStorage("showOriginalImage") var showOriginalImage: Bool = false

  let columns = [
    GridItem(.flexible(), spacing: 16),
    GridItem(.flexible(), spacing: 16),
  ]

  var body: some View {
    NavigationStack {
      VStack {
        HStack {
          Text("iTeXSnip")
            .font(.title)
          Spacer()
          Button {
            pickImageFilesAndAddSnippet()
          } label: {
            Image(systemName: "photo.badge.plus")
              .imageScale(.large)
          }
          .accessibilityLabel("Load Image File")
          .buttonStyle(PlainButtonStyle())

          Button {
            Task {
              await takeScreenshotAndAddSnippet()
              processingImage = false
            }
          } label: {
            Image(systemName: "scissors")
              .imageScale(.large)
          }
          .accessibilityLabel("Screenshot")
          .buttonStyle(PlainButtonStyle())
          Menu {
            SettingsLink {
              Text("Open Preferences")
            }
            NavigationLink(destination: AcknowledgementsView()) {
              Text("Acknowledgements")
            }
            Button("Quit") {
              NSApplication.shared.terminate(nil)
            }
          } label: {
            Image(systemName: "gear")
              .imageScale(.large)
          }
          .buttonStyle(PlainButtonStyle())
          .accessibilityLabel("Preferences")
        }.padding()

        if processingImage {
          ProgressView()
        }

        ScrollView {
          LazyVGrid(columns: columns, spacing: 16) {
            ForEach(snippets) { snippet in
              NavigationLink(
                destination: DetailedSnippetView(showOriginal: showOriginalImage, snippet: snippet)
              ) {
                SnippetView(snippet: snippet, deleteSnippet: deleteSnippet)
                  .frame(height: 200)
                  .padding()
              }
              //                            .frame(height: 300)
            }
          }
          .padding()
        }

        Spacer()
      }.task {
        if loadModelOnStart {
          do {
            if self.model == nil {
              let mymodel = try await TexTellerModel.asyncInit()
              self.model = mymodel
              print("Loaded da model")
            }
          } catch {
            print("Failed to load da model: \(error)")
          }
        }
      }
    }
  }

  func pickImageFilesAndAddSnippet() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.title = "Choose an image"

    if panel.runModal() == .OK {
      if let url = panel.url, let image = NSImage(contentsOf: url) {
        let newSnippet = ImageSnippet(image: image)
        if self.loadModelOnStart == false {
          do {
            if self.model == nil {
              let mymodel = try TexTellerModel()
              self.model = mymodel
              print("Loaded model on demand")
            }
          } catch {
            print("Failed to load da model: \(error)")
          }
        }
        do {
          if self.model != nil {
            let latex = try self.model!.texIt(image)
            newSnippet.transcribedText = latex
          }
          modelContext.insert(newSnippet)
          try modelContext.save()
        } catch {
          print("Failed to save new snippet: \(error)")
        }
        if self.loadModelOnStart == false {
          self.model = nil
        }
      }
    }
  }

  func takeScreenshotAndAddSnippet() async {
    // Check for screen capture permission
    if !CGPreflightScreenCaptureAccess() {
      // App doesn't have permission, request permission
      if !CGRequestScreenCaptureAccess() {
        // Permission was denied, show alert to the user
        await MainActor.run {
          let alert = NSAlert()
          alert.messageText = "Screen Recording Permission Denied"
          alert.informativeText =
            "Please grant screen recording permissions in System Preferences > Security & Privacy."
          alert.addButton(withTitle: "OK")
          alert.runModal()
        }
        return
      }
    }

    let tempPath = NSTemporaryDirectory() + "temp_itexsnip_ss.png"

    let task = Process()
    task.launchPath = "/usr/sbin/screencapture"
    task.arguments = ["-i", tempPath]

    do {
      try await runScreencaptureTask(task)

      guard FileManager.default.fileExists(atPath: tempPath) else {
        print("Screenshot was cancelled or failed")
        return
      }

      await MainActor.run {
        processingImage = true
      }

      if let screenshotImage = NSImage(contentsOfFile: tempPath) {
        let newSnippet = ImageSnippet(image: screenshotImage)

        if self.loadModelOnStart == false {
          do {
            if self.model == nil {
              let mymodel = try TexTellerModel()
              self.model = mymodel
              print("Loaded model on demand")
            }
          } catch {
            print("Failed to load the model: \(error)")
          }
        }

        do {
          if self.model != nil {
            guard let imageData = screenshotImage.tiffRepresentation else {
              print("Failed to convert screenshot to data")
              return
            }
            let latex = try await self.model!.texIt(imageData)
            newSnippet.transcribedText = latex
          }
          self.modelContext.insert(newSnippet)
          try self.modelContext.save()
        } catch {
          print("Failed to add snippet: \(error)")
        }

        if self.loadModelOnStart == false {
          self.model = nil
        }
      } else {
        print("Failed to get image...")
      }

      try FileManager.default.removeItem(atPath: tempPath)
      print("Temp screenshot cleaned up")

    } catch {
      print("Failed to launch screencapture process: \(error)")
    }
  }

  func runScreencaptureTask(_ task: Process) async throws {
    try await withCheckedThrowingContinuation { continuation in
      task.terminationHandler = { process in
        if process.terminationStatus == 0 {
          continuation.resume()
        } else {
          continuation.resume(
            throwing: NSError(
              domain: "ScreenCapture", code: Int(process.terminationStatus), userInfo: nil))
        }
      }
      do {
        try task.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  func deleteSnippet(snippet: ImageSnippet) {
    do {
      modelContext.delete(snippet)
      try modelContext.save()
    } catch {
      print("Failed to delete snippet: \(error)")
    }
  }
}

struct SnippetView: View {
  var snippet: ImageSnippet
  var deleteSnippet: (ImageSnippet) -> Void

  var body: some View {
    VStack {
      if let nsImage = NSImage(data: snippet.image) {
        GeometryReader { geometry in
          Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()
            .cornerRadius(10)
        }
        .contextMenu {
          Button(role: .destructive) {
            deleteSnippet(snippet)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
      ScrollView(.horizontal) {
        HStack {
          Spacer()
          LaTeX(snippet.transcribedText ?? "")
            .parsingMode(.all)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .layoutPriority(1)
            .font(.system(size: 28, weight: .bold))
          Spacer()
        }
      }.scrollBounceBehavior(.basedOnSize, axes: [.horizontal])

    }
  }
}

#Preview {
  MenuBarView()
}
