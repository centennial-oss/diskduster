#!/usr/bin/env swift
// Composite transparent foreground over background; write PNG to output.
// Usage: swift composite-app-icon.swift <background.png> <foreground.png> <output.png> [size] [y-offset]
//   size:     width and height to draw the foreground at, in pixels of the 1024x1024 output (default 860)
//   y-offset: pixels above center to place the foreground; negative moves it below center (default 20)
// No extra deps; uses AppKit on macOS.

import AppKit
import Foundation

guard (4...6).contains(CommandLine.arguments.count) else {
    fputs("Usage: \(CommandLine.arguments[0]) <background.png> <foreground.png> <output.png> [size] [y-offset]\n",
          stderr)
    exit(1)
}

let bgPath = CommandLine.arguments[1]
let fgPath = CommandLine.arguments[2]
let outPath = CommandLine.arguments[3]

guard FileManager.default.fileExists(atPath: bgPath) else {
    fputs("Missing: \(bgPath)\n", stderr)
    exit(1)
}
guard FileManager.default.fileExists(atPath: fgPath) else {
    fputs("Missing: \(fgPath)\n", stderr)
    exit(1)
}

guard let bgImage = NSImage(contentsOfFile: bgPath),
      let fgImage = NSImage(contentsOfFile: fgPath) else {
    fputs("Failed to load images\n", stderr)
    exit(1)
}

// Background is drawn at 1024x1024; the transparent foreground is drawn at `size` and centered horizontally,
// `y-offset` pixels above center.
let bgWidth = 1024.0
let bgHeight = 1024.0
let fgSize = CommandLine.arguments.count > 4 ? Double(CommandLine.arguments[4]) ?? 860 : 860
let fgYOffsetAboveCenter = CommandLine.arguments.count > 5 ? Double(CommandLine.arguments[5]) ?? 20 : 20
let width = Int(bgWidth)
let height = Int(bgHeight)

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32) else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Draw the background at full size, then the foreground on top of it.
let bgRect = NSRect(x: 0, y: 0, width: bgWidth, height: bgHeight)
let fgDestX = (bgWidth - fgSize) / 2
let fgDestY = (bgHeight - fgSize) / 2 + fgYOffsetAboveCenter
let fgDestRect = NSRect(x: fgDestX, y: fgDestY, width: fgSize, height: fgSize)
let fgSrcRect = NSRect(x: 0, y: 0, width: fgImage.size.width, height: fgImage.size.height)
bgImage.draw(in: bgRect)
fgImage.draw(in: fgDestRect, from: fgSrcRect, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outPath))
} catch {
    fputs("Failed to write: \(error)\n", stderr)
    exit(1)
}

print("Wrote \(outPath)")
