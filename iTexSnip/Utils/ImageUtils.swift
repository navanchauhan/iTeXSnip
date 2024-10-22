//
//  ImageUtils.swift
//  iTexSnip
//
//  Created by Navan Chauhan on 10/13/24.
//

import AppKit
import CoreImage
import Foundation

let IMAGE_MEAN: CGFloat = 0.9545467
let IMAGE_STD: CGFloat = 0.15394445
let FIXED_IMG_SIZE: CGFloat = 448
let IMG_CHANNELS: Int = 1
let MIN_HEIGHT: CGFloat = 12
let MIN_WIDTH: CGFloat = 30

// Load image from URL
func loadImage(from urlString: String) -> NSImage? {
  guard let url = URL(string: urlString), let imageData = try? Data(contentsOf: url) else {
    return nil
  }
  return NSImage(data: imageData)
}

// Helper to convert NSImage to CIImage
func nsImageToCIImage(_ image: NSImage) -> CIImage? {
  guard let data = image.tiffRepresentation,
    let bitmapImage = NSBitmapImageRep(data: data),
    let cgImage = bitmapImage.cgImage
  else {
    return nil
  }
  return CIImage(cgImage: cgImage)
}

func trimWhiteBorder(image: CIImage) -> CIImage? {
  let context = CIContext()

  // Render the CIImage to a CGImage for pixel analysis
  guard let cgImage = context.createCGImage(image, from: image.extent) else {
    return nil
  }

  // Access the pixel data
  let width = cgImage.width
  let height = cgImage.height
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * width
  let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
  var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

  guard
    let contextRef = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    )
  else {
    return nil
  }

  contextRef.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

  // Define the white color in RGBA
  let whitePixel: [UInt8] = [255, 255, 255, 255]

  var minX = width
  var minY = height
  var maxX: Int = 0
  var maxY: Int = 0

  // Scan the pixels to find the bounding box of non-white content
  for y in 0..<height {
    for x in 0..<width {
      let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
      let pixel = Array(pixelData[pixelIndex..<(pixelIndex + 4)])

      if pixel != whitePixel {
        if x < minX { minX = x }
        if x > maxX { maxX = x }
        if y < minY { minY = y }
        if y > maxY { maxY = y }
      }
    }
  }

  // If no non-white content was found, return the original image
  if minX == width || minY == height || maxX == 0 || maxY == 0 {
    return image
  }

  // Compute the bounding box and crop the image
  let croppedRect = CGRect(
    x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
  return image.cropped(to: croppedRect)
}
// Padding image with white border
func addWhiteBorder(to image: CIImage, maxSize: CGFloat) -> CIImage {
  let randomPadding = (0..<4).map { _ in CGFloat(arc4random_uniform(UInt32(maxSize))) }
  var xPadding = randomPadding[0] + randomPadding[2]
  var yPadding = randomPadding[1] + randomPadding[3]

  // Ensure the minimum width and height
  if xPadding + image.extent.width < MIN_WIDTH {
    let compensateWidth = (MIN_WIDTH - (xPadding + image.extent.width)) * 0.5 + 1
    xPadding += compensateWidth
  }
  if yPadding + image.extent.height < MIN_HEIGHT {
    let compensateHeight = (MIN_HEIGHT - (yPadding + image.extent.height)) * 0.5 + 1
    yPadding += compensateHeight
  }

  // Adding padding with a constant white color
  let padFilter = CIFilter(name: "CICrop")!
  let paddedRect = CGRect(
    x: image.extent.origin.x - randomPadding[0],
    y: image.extent.origin.y - randomPadding[1],
    width: image.extent.width + xPadding,
    height: image.extent.height + yPadding)
  padFilter.setValue(image, forKey: kCIInputImageKey)
  padFilter.setValue(CIVector(cgRect: paddedRect), forKey: "inputRectangle")

  return padFilter.outputImage ?? image
}

// Padding images to a required size
func padding(images: [CIImage], requiredSize: CGFloat) -> [CIImage] {
  return images.map { image in
    let widthPadding = requiredSize - image.extent.width
    let heightPadding = requiredSize - image.extent.height
    return addWhiteBorder(to: image, maxSize: max(widthPadding, heightPadding))
  }
}

// Transform pipeline to apply resize, normalize, etc.
func inferenceTransform(images: [NSImage]) -> [CIImage] {
  let ciImages = images.compactMap { nsImageToCIImage($0) }

  let trimmedImages = ciImages.compactMap { trimWhiteBorder(image: $0) }
  let paddedImages = padding(images: trimmedImages, requiredSize: FIXED_IMG_SIZE)

  return paddedImages
}

func ciImageToFloatArray(_ image: CIImage, size: CGSize) -> [Float] {
  // Render the CIImage to a bitmap context
  let context = CIContext()
  guard let cgImage = context.createCGImage(image, from: image.extent) else {
    return []
  }

  let width = Int(size.width)
  let height = Int(size.height)
  var pixelData = [UInt8](repeating: 0, count: width * height)  // Use UInt8 for grayscale

  // Create bitmap context for rendering
  let colorSpace = CGColorSpaceCreateDeviceGray()
  guard
    let contextRef = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.none.rawValue
    )
  else {
    return []
  }

  contextRef.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

  // Normalize pixel values to [0, 1]
  return pixelData.map { Float($0) / 255.0 }
}
