//
//  RobertaTokenizerFast.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/13/24.
//

import Foundation

class RobertaTokenizerFast {
  var vocab: [String: Int] = [:]
  var idToToken: [Int: String] = [:]
  var specialTokens: [String] = []
  var unkTokenId: Int?

  init(vocabFile: String, tokenizerFile: String) {
    if let vocabURL = Bundle.main.url(forResource: vocabFile, withExtension: "json"),
      let vocabData = try? Data(contentsOf: vocabURL),
      let vocabDict = try? JSONSerialization.jsonObject(with: vocabData, options: [])
        as? [String: Int]
    {
      self.vocab = vocabDict
    }

    if let tokenizerURL = Bundle.main.url(forResource: tokenizerFile, withExtension: "json"),
      let tokenizerData = try? Data(contentsOf: tokenizerURL),
      let tokenizerConfig = try? JSONSerialization.jsonObject(with: tokenizerData, options: [])
        as? [String: Any]
    {
      self.specialTokens = tokenizerConfig["added_tokens"] as? [String] ?? []
    }

    self.idToToken = vocab.reduce(into: [Int: String]()) { $0[$1.value] = $1.key }

    self.unkTokenId = vocab["<unk>"]
  }

  func encode(text: String) -> [Int] {
    let tokens = tokenize(text)
    return tokens.map { vocab[$0] ?? unkTokenId! }
  }

  func decode(tokenIds: [Int], skipSpecialTokens: Bool = true) -> String {
    let tokens = tokenIds.compactMap { idToToken[$0] }
    let filteredTokens =
      skipSpecialTokens ? tokens.filter { !specialTokens.contains($0) && $0 != "</s>" } : tokens
    return convertTokensToString(filteredTokens)
  }

  private func tokenize(_ text: String) -> [String] {
    let cleanedText = cleanText(text)
    let words = cleanedText.split(separator: " ").map { String($0) }

    var tokens: [String] = []
    for word in words {
      tokens.append(contentsOf: bpeEncode(word))
    }
    return tokens
  }

  private func bpeEncode(_ word: String) -> [String] {
    if vocab.keys.contains(word) {
      return [word]
    }

    let chars = Array(word)
    var tokens: [String] = []
    var i = 0

    while i < chars.count {
      if i < chars.count - 1 {
        let pair = String(chars[i]) + String(chars[i + 1])
        if vocab.keys.contains(pair) {
          tokens.append(pair)
          i += 2
          continue
        }
      }
      tokens.append(String(chars[i]))
      i += 1
    }
    return tokens
  }

  private func cleanText(_ text: String) -> String {
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func convertTokensToString(_ tokens: [String]) -> String {
    let text = tokens.joined().replacingOccurrences(of: "Ġ", with: " ")
    return text.replacingOccurrences(
      of: "\\s([?.!,\'\"](?:\\s|$))", with: "$1", options: .regularExpression, range: nil
    ).trimmingCharacters(in: .whitespaces)
  }
}
