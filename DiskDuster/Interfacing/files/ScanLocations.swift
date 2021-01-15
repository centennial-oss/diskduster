//
//  ScanLocations.swift
//  DiskDuster
//
//  Created by James Ranson on 12/5/20.
//

import Foundation

// the list of allowed log locations
let logsLocations: Set<String> = [
    "/private/var/log",
    "/Library/Logs",
    "~/Library/Developer/CoreSimulator/Devices",
    "~/Library/Developer/Xcode/DerivedData/*",
    "~/Library/Developer/Xcode/iOS Device Logs",
    "~/Library/Logs",
    "~/Library/Application Support/$appName/Log",
    "~/Library/Application Support/$appName/Logs",
    "~/Library/Application Support/$appName/log",
    "~/Library/Application Support/$appName/logs"
]

// the default list of log locations to scan
var logsScanLocations: Set<String> = [
    "/private/var/log",
    "/Library/Logs",
    "~/Library/Developer/CoreSimulator/Devices",
    "~/Library/Developer/Xcode/DerivedData/*",
    "~/Library/Developer/Xcode/iOS Device Logs",
    "~/Library/Logs",
    "~/Library/Application Support/$appName/Log",
    "~/Library/Application Support/$appName/Logs",
    "~/Library/Application Support/$appName/log",
    "~/Library/Application Support/$appName/logs"
]

// the list of allowed cache locations
let cacheLocations: Set<String> = [
    "/private/var/folders/$userHashDir/C/",
    "/Library/Caches",
    "/System/Library/Caches",
    "~/Library/Caches",
    "~/Library/Containers/$appName/Data/Library/Caches",
    "~/Library/Containers/$appName/Data/Library/Application Support/$appName/Cache",
    "~/Library/Application Support/$appName/Cache",
    "~/Library/Application Support/$appName/Caches",
    "~/Library/Application Support/$appName/cache",
    "~/Library/Application Support/$appName/caches",
    "~/Library/Application Support/$appName/Code Cache",
    "~/Library/Application Support/$appName/GPUCache"
]

// the default list of cache locations to scan
let cacheScanLocations: Set<String> = [
    "/private/var/folders/$userHashDir/C/",
    "/Library/Caches",
    "/System/Library/Caches",
    "~/Library/Caches",
    "~/Library/Containers/$appName/Data/Library/Caches",
    "~/Library/Containers/$appName/Data/Library/Application Support/$appName/Cache",
    "~/Library/Application Support/$appName/Cache",
    "~/Library/Application Support/$appName/Caches",
    "~/Library/Application Support/$appName/cache",
    "~/Library/Application Support/$appName/caches",
    "~/Library/Application Support/$appName/Code Cache",
    "~/Library/Application Support/$appName/GPUCache"
]

// the list of allowed langauge locations
let langLocations: Set<String> = [
    "/Applications/$appDir/Contents/Resources/$foreignLang.lproj"
]

// the default list of language locations to scan
let langScanLocations: Set<String> = [
    "/Applications/$appDir/Contents/Resources/$foreignLang.lproj"
]
