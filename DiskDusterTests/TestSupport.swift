//
//  TestSupport.swift
//  DiskDusterTests
//

import Foundation
@testable import DiskDuster

/// A throwaway fake home folder so tests never touch the real one.
struct TempHome {
    let path: String

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "DiskDusterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        path = ScanEnvironment.realPath(base.path(percentEncoded: false)) ?? base.path(percentEncoded: false)
    }

    func environment(fullDiskAccess: Bool = true, ignored: Set<String> = []) -> ScanEnvironment {
        ScanEnvironment(homePath: path, darwinCachePath: nil, hasFullDiskAccess: fullDiskAccess, ignoredPaths: ignored)
    }

    @discardableResult
    func makeDirectory(_ relative: String) throws -> String {
        let full = path + "/" + relative
        try FileManager.default.createDirectory(atPath: full, withIntermediateDirectories: true)
        return full
    }

    @discardableResult
    func makeFile(_ relative: String, bytes: Int = 8192) throws -> String {
        let full = path + "/" + relative
        let parent = (full as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: URL(filePath: full))
        return full
    }

    func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: path + "/" + relative)
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }
}

func location(_ pattern: String) -> ScanLocation {
    guard let found = LocationCatalog.location(withID: pattern) else {
        fatalError("Test references unknown catalog location \(pattern)")
    }
    return found
}

/// Records privileged calls instead of running them.
final class FakePrivilegedRunner: PrivilegedRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [String] = []
    let result: Result<String, PrivilegedRunError>

    init(result: Result<String, PrivilegedRunError>) {
        self.result = result
    }

    var calls: [String] {
        lock.withLock { scripts }
    }

    func run(shellScript: String, prompt: String) async throws(PrivilegedRunError) -> String {
        lock.withLock { scripts.append(shellScript) }
        return try result.get()
    }
}

/// UserDefaults kept in memory only, so settings tests never write to the real ~/Library/Preferences.
nonisolated final class InMemoryDefaults: UserDefaults, @unchecked Sendable {
    private var values: [String: Any] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? { values[defaultName] }
    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    override func set(_ value: Bool, forKey defaultName: String) { values[defaultName] = value }
    override func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}
