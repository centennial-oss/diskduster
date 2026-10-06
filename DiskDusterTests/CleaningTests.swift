//
//  CleaningTests.swift
//  DiskDusterTests
//

import Foundation
import Testing
@testable import DiskDuster

struct CleaningTests {
    @Test func permanentCleanRemovesItemsAndEmptiesFolders() async throws {
        let home = try TempHome()
        defer { home.remove() }
        try home.makeFile("Library/Caches/com.example.app/a.bin")
        try home.makeFile("Library/Application Support/Slack/Cache/one")
        try home.makeFile("Library/Application Support/Slack/Cache/two/three")
        let env = home.environment()
        let items = await scan(home, ["~/Library/Caches", "~/Library/Application Support/*/Cache"])
        let runner = FakePrivilegedRunner(result: .success(""))
        var cleaner = Cleaner(mode: .permanent, environment: env)
        cleaner.privilegedRunner = runner

        let outcome = await cleaner.clean(items) { _ in }

        #expect(outcome.failures.isEmpty)
        #expect(outcome.cleaned.count == 2)
        #expect(!outcome.usedTrash)
        #expect(!home.exists("Library/Caches/com.example.app"))
        #expect(home.exists("Library/Application Support/Slack/Cache"))
        #expect(!home.exists("Library/Application Support/Slack/Cache/one"))
        #expect(runner.calls.isEmpty, "No administrator prompt without system items")
    }

    @Test func trashItemsAreAlwaysPermanent() async throws {
        let home = try TempHome()
        defer { home.remove() }
        try home.makeFile(".Trash/old.zip")
        let items = await scan(home, ["~/.Trash"])
        let outcome = await Cleaner(mode: .trash, environment: home.environment()).clean(items) { _ in }
        #expect(outcome.cleaned.count == 1)
        #expect(!outcome.usedTrash)
        #expect(!home.exists(".Trash/old.zip"))
    }

    @Test func systemItemsUseOnePrivilegedCall() async throws {
        let home = try TempHome()
        defer { home.remove() }
        let items = [systemItem("/Library/Caches/com.example.one"), systemItem("/Library/Caches/com.example.two")]
        let runner = FakePrivilegedRunner(result: .success("ok 0\rfail 1\r"))
        var cleaner = Cleaner(mode: .trash, environment: home.environment())
        cleaner.privilegedRunner = runner

        let outcome = await cleaner.clean(items) { _ in }

        #expect(runner.calls.count == 1)
        #expect(runner.calls.first?.contains("/bin/rm -rf -- '/Library/Caches/com.example.one'") == true)
        #expect(outcome.cleaned.map(\.path) == ["/Library/Caches/com.example.one"])
        #expect(outcome.failures.map(\.item.path) == ["/Library/Caches/com.example.two"])
    }

    @Test func cancelledAdminPromptSkipsSystemItems() async throws {
        let home = try TempHome()
        defer { home.remove() }
        var cleaner = Cleaner(mode: .trash, environment: home.environment())
        cleaner.privilegedRunner = FakePrivilegedRunner(result: .failure(.cancelled))
        let outcome = await cleaner.clean([systemItem("/Library/Caches/com.example.one")]) { _ in }
        #expect(outcome.adminCancelled)
        #expect(outcome.cleaned.isEmpty)
        #expect(outcome.failures.count == 1)
    }

    @Test func privilegedScriptQuotesPathsAndParsesResults() {
        let script = PrivilegedRemover.script(for: [systemItem("/Library/Caches/it's here")])
        #expect(script.contains("'/Library/Caches/it'\\''s here'"))
        #expect(PrivilegedRemover.succeededIndexes(from: "ok 0\rfail 1\rok 2\n") == [0, 2])
        #expect(PrivilegedRemover.succeededIndexes(from: "ok x\nnope") == [])
    }

    private func scan(_ home: TempHome, _ patterns: [String]) async -> [CleanupItem] {
        let scanner = Scanner(locations: patterns.map(location), environment: home.environment())
        return await scanner.scan { _ in }.items
    }

    private func systemItem(_ path: String) -> CleanupItem {
        CleanupItem(
            path: path, rootPath: "/Library/Caches", locationID: "/Library/Caches", category: .systemCaches,
            cleanMode: .removeItem, ownerName: (path as NSString).lastPathComponent, locationLabel: "System Cache",
            size: 100, sizeIsPartial: false, requiresAdmin: true, alwaysPermanent: false, selectedByDefault: false,
            note: nil
        )
    }
}
