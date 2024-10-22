//
//  TexTellerModel.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/20/24.
//

import AppKit
import OnnxRuntimeBindings

public enum ModelError: Error {
  case encoderModelNotFound
  case decoderModelNotFound
  case imageError
}

public struct TexTellerModel {
  public let encoderSession: ORTSession
  public let decoderSession: ORTSession
  private let tokenizer: RobertaTokenizerFast

  public init() throws {
    guard let encoderModelPath = Bundle.main.path(forResource: "encoder_model", ofType: "onnx")
    else {
      print("Encoder model not found...")
      throw ModelError.encoderModelNotFound
    }
    guard let decoderModelPath = Bundle.main.path(forResource: "decoder_model", ofType: "onnx")
    else {
      print("Decoder model not found...")
      throw ModelError.decoderModelNotFound
    }
    let env = try ORTEnv(loggingLevel: .warning)
    let coreMLOptions = ORTCoreMLExecutionProviderOptions()
    coreMLOptions.enableOnSubgraphs = true
    coreMLOptions.createMLProgram = false
    let options = try ORTSessionOptions()
    //        try options.appendCoreMLExecutionProvider(with: coreMLOptions)
    encoderSession = try ORTSession(env: env, modelPath: encoderModelPath, sessionOptions: options)
    decoderSession = try ORTSession(env: env, modelPath: decoderModelPath, sessionOptions: options)

    self.tokenizer = RobertaTokenizerFast(vocabFile: "vocab", tokenizerFile: "tokenizer")
  }

  public static func asyncInit() async throws -> TexTellerModel {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let model = try TexTellerModel()
          continuation.resume(returning: model)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  public func texIt(_ image: NSImage, rawString: Bool = false, debug: Bool = false) throws -> String
  {
    let transformedImage = inferenceTransform(images: [image])
    if let firstTransformedImage = transformedImage.first {
      let pixelValues = ciImageToFloatArray(
        firstTransformedImage, size: CGSize(width: FIXED_IMG_SIZE, height: FIXED_IMG_SIZE))
      if debug {
        print("First few pixel inputs: \(pixelValues.prefix(10))")
      }
      let inputTensor = try ORTValue(
        tensorData: NSMutableData(
          data: Data(bytes: pixelValues, count: pixelValues.count * MemoryLayout<Float>.stride)
        ),
        elementType: .float,
        shape: [
          1, 1, NSNumber(value: FIXED_IMG_SIZE), NSNumber(value: FIXED_IMG_SIZE),
        ]
      )
      let encoderInput: [String: ORTValue] = [
        "pixel_values": inputTensor
      ]
      let encoderOutputNames = try self.encoderSession.outputNames()
      let encoderOutputs: [String: ORTValue] = try self.encoderSession.run(
        withInputs: encoderInput,
        outputNames: Set(encoderOutputNames),
        runOptions: nil
      )

      if debug {
        print("Encoder output: \(encoderOutputs)")
      }

      var decodedTokenIds: [Int] = []
      let startTokenId = 0  // TODO: Move to tokenizer directly?
      let endTokenId = 2
      let maxDecoderLength: Int = 300
      var decoderInputIds: [Int] = [startTokenId]
      let vocabSize = 15000

      if debug {
        let encoderHiddenStatesData = try encoderOutputs["last_hidden_state"]!.tensorData() as Data
        let encoderHiddenStatesArray = encoderHiddenStatesData.withUnsafeBytes {
          Array(
            UnsafeBufferPointer<Float>(
              start: $0.baseAddress!.assumingMemoryBound(to: Float.self),
              count: encoderHiddenStatesData.count / MemoryLayout<Float>.stride
            ))
        }

        print("First few values of encoder hidden states: \(encoderHiddenStatesArray.prefix(10))")
      }

      let decoderOutputNames = try self.decoderSession.outputNames()

      for step in 0..<maxDecoderLength {
        if debug {
          print("Step \(step)")
        }

        let decoderInputIdsTensor = try ORTValue(
          tensorData: NSMutableData(
            data: Data(
              bytes: decoderInputIds, count: decoderInputIds.count * MemoryLayout<Int64>.stride)),
          elementType: .int64,
          shape: [1, NSNumber(value: decoderInputIds.count)]
        )
        let decoderInputs: [String: ORTValue] = [
          "input_ids": decoderInputIdsTensor,
          "encoder_hidden_states": encoderOutputs["last_hidden_state"]!,
        ]
        let decoderOutputs: [String: ORTValue] = try self.decoderSession.run(
          withInputs: decoderInputs, outputNames: Set(decoderOutputNames), runOptions: nil)
        let logitsTensor = decoderOutputs["logits"]!
        let logitsData = try logitsTensor.tensorData() as Data
        let logits = logitsData.withUnsafeBytes {
          Array(
            UnsafeBufferPointer<Float>(
              start: $0.baseAddress!.assumingMemoryBound(to: Float.self),
              count: logitsData.count / MemoryLayout<Float>.stride
            ))
        }
        let sequenceLength = decoderInputIds.count
        let startIndex = (sequenceLength - 1) * vocabSize
        let endIndex = startIndex + vocabSize
        let lastTokenLogits = Array(logits[startIndex..<endIndex])
        let nextTokenId =
          lastTokenLogits.enumerated().max(by: { $0.element < $1.element })?.offset ?? 9  // TODO: Should I track if this fails
        if debug {
          print("Next token id: \(nextTokenId)")
        }
        if nextTokenId == endTokenId {
          break
        }
        decodedTokenIds.append(nextTokenId)
        decoderInputIds.append(nextTokenId)
      }

      if rawString {
        return tokenizer.decode(tokenIds: decodedTokenIds)
      }

      return toKatex(formula: tokenizer.decode(tokenIds: decodedTokenIds))

    }
    throw ModelError.imageError
  }

  public func texIt(_ image: NSImage, rawString: Bool = false, debug: Bool = false) async throws
    -> String
  {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try self.texIt(image, rawString: rawString, debug: debug)
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

}
