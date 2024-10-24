//
//  DetailedSnippetView.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/21/24.
//

import Foundation
import LaTeXSwiftUI
import SwiftUI

struct DetailedSnippetView: View {
  @Environment(\.modelContext) var modelContext
  @Environment(\.dismiss) private var dismiss

  @AppStorage("apiEndpoint") var apiEndpoint: String =
    "https://api.itexsnip.navan.dev/rate_snippet"
  @State var showOriginal = false

  var snippet: ImageSnippet
  var body: some View {
    VStack {
      HStack {
        Toggle("Show Original", isOn: $showOriginal)
          .toggleStyle(.switch)
          .padding()
        Spacer()
        HStack {
          Button {
            if snippet.rating == true {
              updateRating(nil)
            } else {
              updateRating(true)
            }
          } label: {
            if snippet.rating == true {
              Image(systemName: "hand.thumbsup")
                .foregroundStyle(.green)
                .imageScale(.large)
            } else {
              Image(systemName: "hand.thumbsup")
                .imageScale(.large)
            }
          }.buttonStyle(PlainButtonStyle())

          Button {
            if snippet.rating == false {
              updateRating(nil)
            } else {
              updateRating(false)
            }
          } label: {
            if snippet.rating == false {
              Image(systemName: "hand.thumbsdown")
                .foregroundStyle(.red)
                .imageScale(.large)
            } else {
              Image(systemName: "hand.thumbsdown")
                .imageScale(.large)
            }
          }.buttonStyle(PlainButtonStyle())

          Button(role: .destructive) {
            withAnimation {
              modelContext.delete(snippet)
              do {
                try modelContext.save()
                dismiss()
              } catch {
                print("Failed to delete snippet: \(error)")
              }
            }
          } label: {
            Image(systemName: "trash")
              .imageScale(.large)
          }
          .padding()
          .buttonStyle(PlainButtonStyle())
        }.padding()
      }
      ScrollView {
        if showOriginal {
          HStack {
            Spacer()
            Image(nsImage: NSImage(data: snippet.image)!)
              .resizable()
              .clipped()
              .cornerRadius(10)
              .scaledToFit()
              .frame(height: 100)
            Spacer()
          }.padding()
        }
        HStack {
          Spacer()
          LaTeXEquationView(equation: snippet.transcribedText!)
            .clipped()
            .scaledToFit()
            .frame(height: 100)
          Spacer()
        }
        VStack {
          LaTeXCopyView(latex: snippet.transcribedText!, textStart: "", textEnd: "")
          LaTeXCopyView(latex: snippet.transcribedText!, textStart: "$", textEnd: "$")
          LaTeXCopyView(latex: snippet.transcribedText!, textStart: "$$", textEnd: "$$")
          LaTeXCopyView(
            latex: snippet.transcribedText!, textStart: "\\begin{equation}",
            textEnd: "\\end{equation}")
        }
      }.frame(height: 450)
      Spacer()
    }
  }

  func updateRating(_ rating: Bool?) {
    withAnimation {
      self.snippet.rate(rating)
      do {
        if let rating = rating {
          if var url = URL(string: "\(self.apiEndpoint)") {
            let queryItem = URLQueryItem(name: "good", value: "\(rating)")
            url.append(queryItems: [queryItem])
            let boundary = "Boundary-\(UUID().uuidString)"

            let headers = [
              "accept": "application/json",
              "Content-Type": "multipart/form-data; boundary=\(boundary)",
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers

            var body = Data()

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"good\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(rating)\r\n".data(using: .utf8)!)

            let data = self.snippet.image
            let mimeType = "image/jpeg"  // We detect the filetype on the server anyway
            let filename = "image"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
              "Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(
                using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
              if let error = error {
                print(error)
              } else if let data = data {
                let str = String(data: data, encoding: .utf8)
                print(str ?? "")
              }
            }

            task.resume()
          }
        } else {
          print("Could not create URLRequest")
        }

        try modelContext.save()
      } catch {
        print("Error saving rating: \(error)")
      }
    }
  }
}

struct LaTeXCopyView: View {
  var latex: String
  var textStart: String
  var textEnd: String
  var body: some View {
    HStack {
      ScrollView(.horizontal) {
        Text("\(textStart) \(latex) \(textEnd)")
          .frame(height: 20)
          .textSelection(.enabled)
          .padding()
      }
      .frame(width: 400)
      .border(Color.accentColor)
      Button {
        print("Should Copy")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(textStart) \(latex) \(textEnd)", forType: .string)
      } label: {
        Image(systemName: "document.on.clipboard")
      }
      .buttonStyle(PlainButtonStyle())
      .imageScale(.large)
    }
  }
}

struct LaTeXEquationView: View {
  var equation: String
  var body: some View {
    LaTeX(equation)
      .parsingMode(.all)
      .font(.system(size: 28, weight: .bold))
  }
}
