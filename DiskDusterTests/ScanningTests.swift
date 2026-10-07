//
//  ScanningTests.swift
//  DiskDusterTests
//

import Foundation
import Testing
@testable import DiskDuster

struct ScanningTests {
    @Test func expandsWildcardsToRealDirectoriesOnly() throws {
        let home = try TempHome()
        defer { home.remove() }
        try home.makeDirectory("Library/Application Support/Slack/Cache")
        try home.makeDirectory("Library/Application Support/Discord/Cache")
        try home.makeDirectory("Library/Application Support/NoCache")
        try home.makeFile("Library/Application Support/FileApp/Cache")
        let elsewhere = try home.makeDirectory("Elsewhere")
        try home.makeDirectory("Elsewhere/Cache")
        try FileManager.default.createSymbolicLink(
            atPath: home.path + "/Library/Application Support/Linked", withDestinationPath: elsewhere
        )
        let roots = PathResolver.expand("~/Library/Application Support/*/Cache", in: home.environment())
        #expect(roots.map(\.ownerName) == ["Discord", "Slack"])
        #expect(roots.allSatisfy { $0.path.hasPrefix(home.path + "/Library/Application Support/") })
    }

    @Test func matchesPatterns() throws {
        let home = try TempHome()
        defer { home.remove() }
        let env = home.environment()
        let pattern = "~/Library/Containers/*/Data/Library/Caches"
        let containers = home.path + "/Library/Containers"
        #expect(PathResolver.matches(containers + "/com.a/Data/Library/Caches", pattern: pattern, in: env))
        #expect(!PathResolver.matches(containers + "/../Data/Library/Caches", pattern: pattern, in: env))
        #expect(!PathResolver.matches(home.path + "/Library/Containers/Data/Library/Caches", pattern: pattern, in: env))
        #expect(!PathResolver.matches("/Library/Caches", pattern: "~/Library/Caches", in: env))
    }

    @Test func sizesCountBlocksNotSymlinkTargets() throws {
        let home = try TempHome()
        defer { home.remove() }
        let dir = try home.makeDirectory("measure")
        let big = try home.makeFile("outside/big.bin", bytes: 1_000_000)
        try home.makeFile("measure/small.bin", bytes: 64 * 1024)
        try FileManager.default.createSymbolicLink(atPath: dir + "/link", withDestinationPath: big)
        try FileManager.default.linkItem(atPath: dir + "/small.bin", toPath: dir + "/hardlink.bin")
        let size = DirectorySizer.allocatedSize(atPath: dir)
        #expect(size.bytes >= 64 * 1024)
        #expect(size.bytes < 200 * 1024)
        #expect(!size.isPartial)
    }

    @Test func scanFindsItemsAndHonorsExclusions() async throws {
        let home = try TempHome()
        defer { home.remove() }
        try home.makeFile("Library/Caches/com.example.one/a.bin", bytes: 20_000)
        try home.makeFile("Library/Caches/com.example.two/b.bin", bytes: 40_000)
        try home.makeFile("Library/Caches/CloudKit/c.bin")
        try home.makeFile("Library/Caches/ignored/d.bin")
        try home.makeDirectory("Library/Caches/empty")
        try home.makeFile(".Trash/old.zip")
        let ignored = home.path + "/Library/Caches/ignored"
        let scanner = Scanner(
            locations: [location("~/Library/Caches"), location("~/.Trash")],
            environment: home.environment(fullDiskAccess: false, ignored: [ignored])
        )
        let result = await scanner.scan { _ in }
        let names = result.items.map(\.ownerName)
        #expect(names == ["com.example.two", "com.example.one"])
        #expect(result.skippedLocations.map(\.id) == ["~/.Trash"])
    }

    /// Background services keep files open in these, so trashing them leaves a Trash that can't be emptied.
    @Test func perUserCacheSkipsFoldersInUseByMacOS() async throws {
        let home = try TempHome()
        defer { home.remove() }
        let darwinCache = try home.makeDirectory("var/C")
        try home.makeFile("var/C/com.example.app/a.bin")
        try home.makeFile("var/C/com.apple.quicklook.ThumbnailsAgent/b.bin")
        try home.makeFile("var/C/com.apple.WorkflowKit.BackgroundShortcutRunner/c.bin")
        let environment = ScanEnvironment(
            homePath: home.path, darwinCachePath: darwinCache, hasFullDiskAccess: true, ignoredPaths: []
        )
        let scanner = Scanner(locations: [location(ScanLocation.darwinCacheToken)], environment: environment)
        let result = await scanner.scan { _ in }
        #expect(result.items.map(\.ownerName) == ["com.example.app"])
    }

    @Test func catalogNeverTargetsAppBundlesOrSimulators() {
        for entry in LocationCatalog.all {
            #expect(!entry.pattern.hasPrefix("/Applications"))
            #expect(!entry.pattern.hasPrefix("/System"))
            #expect(!entry.pattern.contains("CoreSimulator/Devices"))
            #expect(entry.requiresAdmin == !(entry.pattern.hasPrefix("~/") || entry.pattern.hasPrefix("$")))
        }
    }
}
