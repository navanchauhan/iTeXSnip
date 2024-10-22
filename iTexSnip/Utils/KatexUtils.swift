//
//  KatexUtils.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/13/24.
//

import Foundation

func change(
  _ inputStr: String, oldInst: String, newInst: String, oldSurrL: Character, oldSurrR: Character,
  newSurrL: String, newSurrR: String
) -> String {
  var result = ""
  var i = 0
  let n = inputStr.count
  let inputArray = Array(inputStr)  // Convert string to array of characters for easier access

  while i < n {
    // Get the range for the substring equivalent to oldInst
    if i + oldInst.count <= n
      && inputStr[
        inputStr.index(
          inputStr.startIndex, offsetBy: i)..<inputStr.index(
            inputStr.startIndex, offsetBy: i + oldInst.count)] == oldInst
    {
      // Check if the old_inst is followed by old_surr_l
      let start = i + oldInst.count
      if start < n && inputArray[start] == oldSurrL {
        var count = 1
        var j = start + 1
        var escaped = false

        while j < n && count > 0 {
          if inputArray[j] == "\\" && !escaped {
            escaped = true
            j += 1
            continue
          }

          if inputArray[j] == oldSurrR && !escaped {
            count -= 1
            if count == 0 {
              break
            }
          } else if inputArray[j] == oldSurrL && !escaped {
            count += 1
          }

          escaped = false
          j += 1
        }

        if count == 0 {
          let innerContent = String(inputArray[(start + 1)..<j])
          result += newInst + newSurrL + innerContent + newSurrR
          i = j + 1
          continue
        } else {
          result += newInst + newSurrL
          i = start + 1
          continue
        }
      }
    }
    result.append(inputArray[i])
    i += 1
  }

  if oldInst != newInst && result.contains(oldInst + String(oldSurrL)) {
    return change(
      result, oldInst: oldInst, newInst: newInst, oldSurrL: oldSurrL, oldSurrR: oldSurrR,
      newSurrL: newSurrL, newSurrR: newSurrR)
  }

  return result
}

func findSubstringPositions(_ string: String, substring: String) -> [Int] {
  var positions: [Int] = []
  var searchRange = string.startIndex..<string.endIndex

  while let range = string.range(of: substring, options: [], range: searchRange) {
    let position = string.distance(from: string.startIndex, to: range.lowerBound)
    positions.append(position)
    searchRange = range.upperBound..<string.endIndex
  }

  return positions
}

func rmDollarSurr(content: String) -> String {
  let pattern = try! NSRegularExpression(pattern: "\\\\[a-zA-Z]+\\$.*?\\$|\\$.*?\\$", options: [])
  var newContent = content
  let matches = pattern.matches(
    in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content))

  for match in matches.reversed() {
    let matchedString = (content as NSString).substring(with: match.range)
    if !matchedString.starts(with: "\\") {
      let strippedMatch = matchedString.replacingOccurrences(of: "$", with: "")
      newContent = newContent.replacingOccurrences(of: matchedString, with: " \(strippedMatch) ")
    }
  }

  return newContent
}

func changeAll(
  inputStr: String, oldInst: String, newInst: String, oldSurrL: Character, oldSurrR: Character,
  newSurrL: String, newSurrR: String
) -> String {
  let positions = findSubstringPositions(inputStr, substring: oldInst + String(oldSurrL))
  var result = inputStr

  for pos in positions.reversed() {
    let startIndex = result.index(result.startIndex, offsetBy: pos)
    let substring = String(result[startIndex..<result.endIndex])
    let changedSubstring = change(
      substring, oldInst: oldInst, newInst: newInst, oldSurrL: oldSurrL, oldSurrR: oldSurrR,
      newSurrL: newSurrL, newSurrR: newSurrR)
    result.replaceSubrange(startIndex..<result.endIndex, with: changedSubstring)
  }

  return result
}

func toKatex(formula: String) -> String {
  var res = formula
  // Remove mbox surrounding
  res = changeAll(
    inputStr: res, oldInst: "\\mbox ", newInst: " ", oldSurrL: "{", oldSurrR: "}", newSurrL: "",
    newSurrR: "")
  res = changeAll(
    inputStr: res, oldInst: "\\mbox", newInst: " ", oldSurrL: "{", oldSurrR: "}", newSurrL: "",
    newSurrR: "")

  // Additional processing similar to the Python version...
  res = res.replacingOccurrences(of: "\\[", with: "")
  res = res.replacingOccurrences(of: "\\]", with: "")
  res = res.replacingOccurrences(
    of: "\\\\[?.!,\'\"](?:\\s|$)", with: "", options: .regularExpression)

  // Merge consecutive `text`
  res = rmDollarSurr(content: res)

  // Remove extra spaces
  res = res.replacingOccurrences(of: " +", with: " ", options: .regularExpression)

  return res.trimmingCharacters(in: .whitespacesAndNewlines)
}
