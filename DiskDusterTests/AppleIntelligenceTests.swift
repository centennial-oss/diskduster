//
//  AppleIntelligenceTests.swift
//  DiskDusterTests
//
//  Pure logic only: nothing here talks to Apple's model service or installs a profile.
//

import Foundation
import Testing
@testable import DiskDuster

struct AppleIntelligenceTests {
    @Test func onlyOfferedOnMacOS27AndLater() {
        #expect(!AISnapshot.supportsOS(majorVersion: 26))
        #expect(AISnapshot.supportsOS(majorVersion: 27))
        #expect(AISnapshot.supportsOS(majorVersion: 28))
    }

    @Test func mainButtonFollowsWhatIsInstalled() {
        let all = Set(AIFeature.allCases)
        typealias Controller = AppleIntelligenceController
        #expect(Controller.primaryAction(installed: nil, selection: all, bytesToFree: 100) == .turnOff)
        #expect(Controller.primaryAction(installed: all, selection: all, bytesToFree: 0) == .restore)
        #expect(Controller.primaryAction(installed: all, selection: all, bytesToFree: 100) == .removeModels)
        #expect(Controller.primaryAction(installed: all, selection: [.siri], bytesToFree: 0) == .applyChanges)
        #expect(Controller.primaryAction(installed: all, selection: [], bytesToFree: 0) == .restore)
    }

    @Test func everyPackGoesWhenEverythingIsOff() {
        let packs = AIFeature.removablePacks(turningOff: Set(AIFeature.allCases))
        #expect(packs == AIModelPack.allCases)
    }

    @Test func packsStayWhileAnyFeatureNeedsThem() {
        var off = Set(AIFeature.allCases)
        off.remove(.siri)
        off.remove(.spatialPhotos)
        let packs = Set(AIFeature.removablePacks(turningOff: off))
        #expect(!packs.contains(.foundation), "Siri still needs the language models")
        #expect(!packs.contains(.spatialScenes))
        #expect(packs.contains(.imageGeneration))
        #expect(packs.contains(.codeCompletion))
        #expect(AIFeature.removablePacks(turningOff: [.chatGPT, .inlinePredictions]).isEmpty)
    }

    @Test func everyPackHasAFeatureThatUsesIt() {
        for pack in AIModelPack.allCases {
            #expect(!pack.dependents.isEmpty, "\(pack.rawValue) could never be removed")
        }
    }

    @Test func profileTurnsOffOnlyTheChosenFeatures() throws {
        let profile = AIProfile.makeProfile(disabling: [.writingTools, .spatialPhotos])
        let payloads = try #require(profile["PayloadContent"] as? [[String: Any]])
        let restrictions = try #require(payloads.first {
            $0["PayloadType"] as? String == "com.apple.applicationaccess"
        })
        #expect(restrictions["allowWritingTools"] as? Bool == false)
        #expect(restrictions["allowAssistant"] == nil)

        // Every pinned domain gets its own managed-preferences payload, with DiskDuster's marker first.
        let managed = payloads.filter { $0["PayloadType"] as? String == "com.apple.ManagedClient.preferences" }
        var domains: [String: Any] = [:]
        for payload in managed {
            let content = try #require(payload["PayloadContent"] as? [String: Any])
            #expect(content.count == 1)
            domains.merge(content) { first, _ in first }
        }
        let firstDomain = (managed.first?["PayloadContent"] as? [String: Any])?.keys.first
        #expect(firstDomain == AIProfile.markerDomain)
        #expect(Set(managed.compactMap { $0["PayloadUUID"] as? String }).count == managed.count)
        for payload in payloads {
            let payloadID = try #require(payload["PayloadIdentifier"] as? String)
            #expect(!payloadID.contains(".."), "\(payloadID) has an empty component")
        }
        #expect(forced(domains, "com.apple.spatialphotosrelive")?["LocallyDisabled"] as? Bool == true)
        #expect(forced(domains, "com.apple.Siri") == nil)

        let marker = try #require(forced(domains, AIProfile.markerDomain))
        #expect(marker[AIProfile.markerFeaturesKey] as? [String] == ["writingTools", "spatialPhotos"])

        // Writing Tools shares the language models with features left on, so only Spatial Photos is blocked.
        let downloads = try #require(forced(domains, AIProfile.assetDomain))
        #expect(downloads.keys.sorted() == [AIProfile.downloadOverrideKey(for: .spatialScenes)])
        #expect(profile["PayloadIdentifier"] as? String == AIProfile.identifier)
        #expect(profile["PayloadRemovalDisallowed"] as? Bool == false)
    }

    @Test func profileSerializesAndKeepsStableIdentifiers() throws {
        let data = try AIProfile.makeData(disabling: Set(AIFeature.allCases))
        #expect(!data.isEmpty)
        let first = AIProfile.stableUUID(for: "a")
        #expect(first == AIProfile.stableUUID(for: "a"))
        #expect(first != AIProfile.stableUUID(for: "b"))
        #expect(UUID(uuidString: first) != nil)
    }

    @Test func refusedRequestsForPacksAlreadyGoneAreNotFailures() {
        let errors: [AIModelPack: String] = [.imageGeneration: "error -1", .codeCompletion: "error -1"]
        let after: [AIModelPack: Int64] = [.foundation: 0, .imageGeneration: 0, .codeCompletion: 500]
        let notes = AIModelRemover.outcomeNotes(
            targets: [.foundation, .imageGeneration, .codeCompletion, .spatialScenes],
            after: after,
            requestErrors: errors
        )
        #expect(notes.map(\.pack) == [.codeCompletion, .spatialScenes])
        #expect(notes.first?.message.contains("still on disk") == true)
        #expect(notes.first?.message.contains("error -1") == true)
        #expect(notes.last?.message.contains("couldn't be confirmed") == true)
    }

    @Test func inventoryCountsOnlyAssetsOnThisMac() {
        let assets: [[String: Any]] = [
            ["isPresentOnDevice": true, "metadata": [
                "AssetType": "com.apple.MobileAsset.UAF.FM.CodeLM",
                "com.apple.UnifiedAssetFramework.UnarchivedSize": NSNumber(value: 1_000)
            ]],
            ["isPresentOnDevice": true, "metadata": [
                "AssetType": "com.apple.MobileAsset.UAF.FM.CodeLM", "_UnarchivedSize": "500"
            ]],
            ["isPresentOnDevice": false, "metadata": [
                "AssetType": "com.apple.MobileAsset.UAF.FM.Visual", "_UnarchivedSize": "9999"
            ]],
            ["isPresentOnDevice": true]
        ]
        let totals = AssetService.tallyPresentAssets(assets)
        #expect(totals == ["com.apple.MobileAsset.UAF.FM.CodeLM": 1_500])
    }

    private func forced(_ domains: [String: Any], _ domain: String) -> [String: Any]? {
        let entry = domains[domain] as? [String: Any]
        let forced = entry?["Forced"] as? [[String: Any]]
        return forced?.first?["mcx_preference_settings"] as? [String: Any]
    }
}
