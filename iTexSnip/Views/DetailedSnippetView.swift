//
//  DetailedSnippetView.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/21/24.
//

import LaTeXSwiftUI
import SwiftUI

struct DetailedSnippetView: View {
  @Environment(\.modelContext) var modelContext
  @Environment(\.dismiss) private var dismiss

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
