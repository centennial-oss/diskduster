//
//  PathSafetyTests.swift
//  DiskDusterTests
//

import Foundation
import Testing
@testable import DiskDuster

struct PathSafetyTests {
    @Test func shellQuotingKeepsValuesLiteral() {
        #expect(PathSafety.shellQuoted("/tmp/a b") == "'/tmp/a b'")
        #expect(PathSafety.shellQuoted("it's") == "'it'\\''s'")
        #expect(PathSafety.shellQuoted("$(rm -rf /)") == "'$(rm -rf /)'")
    }

    @Test func canonicalPaths() {
        #expect(PathSafety.isCanonicalAbsolute("/Library/Caches/foo"))
        #expect(!PathSafety.isCanonicalAbsolute("Library/Caches"))
        #expect(!PathSafety.isCanonicalAbsolute("/"))
        #expect(!PathSafety.isCanonicalAbsolute("/Library/Caches/"))
        #expect(!PathSafety.isCanonicalAbsolute("/Library/Caches/../.."))
        #expect(!PathSafety.isCanonicalAbsolute("/Library//Caches"))
        #expect(!PathSafety.isCanonicalAbsolute("/Library/./Caches"))
    }

    @Test func acceptsScannedItems() async throws {
        let home = try TempHome()
        defer { home.remove() }
        try home.makeFile("Library/Caches/com.example.app/data.bin")
        try home.makeFile("Library/Application Support/Slack/Cache/blob")
        let scanner = Scanner(
            locations: [location("~/Library/Caches"), location("~/Library/Application Support/*/Cache")],
            environment: home.environment()
        )
        let items = scanner.discoverCandidates().items
        #expect(items.count == 2)
        for item in items {
            #expect(throws: Never.self) { try PathSafety.validate(item, in: home.environment()) }
        }
    }

    @Test func rejectsTamperedItems() throws {
        let home = try TempHome()
        defer { home.remove() }
        let caches = try home.makeDirectory("Library/Caches")
        try home.makeDirectory("Documents")
        let env = home.environment()
        let valid = item(path: caches + "/com.example.app", root: caches)

        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: home.path + "/Documents", root: caches), in: env)
        }
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: caches + "/../../Documents", root: caches), in: env)
        }
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: home.path + "/Documents/x", root: home.path + "/Documents"), in: env)
        }
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: caches + "/a", root: caches, locationID: "/Users"), in: env)
        }
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: caches + "/CloudKit", root: caches, owner: "CloudKit"), in: env)
        }
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: caches, root: caches), in: env)
        }
        #expect(throws: Never.self) { try PathSafety.validate(valid, in: env) }
    }

    @Test func rejectsSymlinkedLocation() throws {
        let home = try TempHome()
        defer { home.remove() }
        let elsewhere = try home.makeDirectory("Important")
        try home.makeDirectory("Library")
        let root = home.path + "/Library/Caches"
        try FileManager.default.createSymbolicLink(atPath: root, withDestinationPath: elsewhere)
        #expect(throws: (any Error).self) {
            try PathSafety.validate(item(path: root + "/stuff", root: root), in: home.environment())
        }
    }

    private func item(
        path: String, root: String, locationID: String = "~/Library/Caches", owner: String? = nil
    ) -> CleanupItem {
        CleanupItem(
            path: path, rootPath: root, locationID: locationID, category: .userCaches, cleanMode: .removeItem,
            ownerName: owner ?? (path as NSString).lastPathComponent, locationLabel: "User Cache", size: 1,
            sizeIsPartial: false, requiresAdmin: false, alwaysPermanent: false, selectedByDefault: true, note: nil
        )
    }
}
