//
//  AppPreservationTests.swift
//  DiskDusterTests
//

import Foundation
import Testing
@testable import DiskDuster

struct AppPreservationTests {
    private let chat = InstalledApp(bundleID: "com.openai.chat", name: "ChatGPT", path: "/Applications/ChatGPT.app")
    private let music = InstalledApp(bundleID: "com.apple.Music", name: "Music", path: "/System/Applications/Music.app")
    private let slack = InstalledApp(
        bundleID: "com.tinyspeck.slackmacgap", name: "Slack", path: "/Applications/Slack.app"
    )

    private var directory: AppDirectory {
        var directory = AppDirectory()
        [chat, music, slack].forEach { directory.add($0) }
        return directory
    }

    @Test func matchesFolderNamesToApps() {
        #expect(directory.owner(of: "com.openai.chat") == chat)
        #expect(directory.owner(of: "com.apple.Music") == music)
        #expect(directory.owner(of: "com.apple.music") == music)
        #expect(directory.owner(of: "com.openai.chat.ShipIt") == chat)
        #expect(directory.owner(of: "group.com.apple.Music") == music)
        #expect(directory.owner(of: "ABCDE12345.com.tinyspeck.slackmacgap") == slack)
        #expect(directory.owner(of: "Slack") == slack)
        #expect(directory.owner(of: "go-build") == nil)
        #expect(directory.owner(of: "com.apple") == nil)
        #expect(directory.owner(of: "com.openai") == nil)
    }

    @Test func preservedAppsAreNeverSelected() throws {
        let suite = "DiskDusterTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(settings: AppSettings(defaults: defaults))
        let chatCache = item("~/Library/Caches/com.openai.chat", .userCaches, app: chat)
        let chatLogs = item("~/Library/Logs/ChatGPT", .logs, app: chat)
        let musicCache = item("~/Library/Caches/com.apple.Music", .userCaches, app: music)
        model.apply(ScanResult(items: [chatCache, chatLogs, musicCache]), categories: [.userCaches, .logs])
        #expect(model.selectedItems.count == 3)

        let chatGroup = try #require(model.appGroups.first { $0.name == "ChatGPT" })
        #expect(chatGroup.categories == [.userCaches, .logs])
        model.setPreserved(true, group: chatGroup)

        #expect(model.selectedItems.map(\.path) == [musicCache.path])
        model.setSelected(true, item: chatCache)
        model.setSelected(true, category: .logs)
        #expect(model.selectedItems.map(\.path) == [musicCache.path])
        #expect(model.selectionState(of: .logs) == .none)

        // The choice survives a rescan and a fresh settings instance.
        let reloaded = AppModel(settings: AppSettings(defaults: defaults))
        reloaded.apply(ScanResult(items: [chatCache, chatLogs, musicCache]), categories: [.userCaches, .logs])
        #expect(reloaded.selectedItems.map(\.path) == [musicCache.path])

        model.setPreserved(false, group: chatGroup)
        #expect(model.selectedItems.count == 3)
    }

    private func item(_ path: String, _ category: CleanupCategory, app: InstalledApp?) -> CleanupItem {
        CleanupItem(
            path: path, rootPath: (path as NSString).deletingLastPathComponent, locationID: "~/Library/Caches",
            category: category, cleanMode: .removeItem, ownerName: (path as NSString).lastPathComponent,
            locationLabel: "Test", size: 1000, sizeIsPartial: false, requiresAdmin: false, alwaysPermanent: false,
            selectedByDefault: true, note: nil, owningApp: app
        )
    }
}
