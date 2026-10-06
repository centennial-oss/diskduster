//
//  AIFeature.swift
//  DiskDuster
//

import Foundation

/// A preference that macOS is told to hold at a fixed value while a feature is turned off.
nonisolated struct PinnedSetting: Hashable, Sendable {
    let domain: String
    let key: String
    let disabledValue: Bool
}

/// A bundle of on-device models that Apple's asset service downloads for Apple Intelligence.
nonisolated enum AIModelPack: String, CaseIterable, Identifiable, Sendable {
    case foundation = "com.apple.modelcatalog"
    case imageGeneration = "com.apple.MobileAsset.UAF.FM.Visual"
    case codeCompletion = "com.apple.MobileAsset.UAF.FM.CodeLM"
    case photosCleanUp = "com.apple.MobileAsset.UAF.Photos.MagicCleanup"
    case spatialScenes = "com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: "Apple Intelligence language models"
        case .imageGeneration: "Image Playground and Genmoji models"
        case .codeCompletion: "Xcode code completion model"
        case .photosCleanUp: "Photos Clean Up model"
        case .spatialScenes: "Spatial Photos model"
        }
    }

    /// The MobileAsset type this pack is expected to download. If macOS reports something else, DiskDuster
    /// leaves the pack alone rather than remove something it doesn't recognize.
    var expectedAssetType: String {
        self == .foundation ? "com.apple.MobileAsset.UAF.FM.GenerativeModels" : rawValue
    }

    /// The features that rely on this pack. It can only be removed when all of them are turned off.
    var dependents: [AIFeature] {
        AIFeature.allCases.filter { $0.modelPacks.contains(self) }
    }
}

/// An Apple Intelligence feature DiskDuster can turn off.
nonisolated enum AIFeature: String, CaseIterable, Identifiable, Sendable, Codable {
    case siri
    case writingTools
    case genmoji
    case imagePlayground
    case chatGPT
    case mailSummaries
    case mailSmartReplies
    case messagesSummaries
    case notificationSummaries
    case safariSummaries
    case notesSummaries
    case inlinePredictions
    case spatialPhotos
    case photosCleanUp
    case xcodeCompletion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .siri: "Siri"
        case .writingTools: "Writing Tools"
        case .genmoji: "Genmoji"
        case .imagePlayground: "Image Playground"
        case .chatGPT: "ChatGPT and other AI extensions"
        case .mailSummaries: "Mail summaries"
        case .mailSmartReplies: "Mail smart replies"
        case .messagesSummaries: "Messages summaries"
        case .notificationSummaries: "Notification summaries"
        case .safariSummaries: "Safari summaries"
        case .notesSummaries: "Notes recording summaries"
        case .inlinePredictions: "Inline text predictions"
        case .spatialPhotos: "Spatial Photos"
        case .photosCleanUp: "Photos Clean Up"
        case .xcodeCompletion: "Xcode predictive code completion"
        }
    }

    var symbol: String {
        switch self {
        case .siri: "waveform.circle"
        case .writingTools: "pencil.and.outline"
        case .genmoji: "face.smiling"
        case .imagePlayground: "photo.on.rectangle.angled"
        case .chatGPT: "puzzlepiece.extension"
        case .mailSummaries, .mailSmartReplies: "envelope"
        case .messagesSummaries: "message"
        case .notificationSummaries: "bell.badge"
        case .safariSummaries: "safari"
        case .notesSummaries: "note.text"
        case .inlinePredictions: "text.cursor"
        case .spatialPhotos: "cube.transparent"
        case .photosCleanUp: "wand.and.rays"
        case .xcodeCompletion: "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Keys in Apple's `com.apple.applicationaccess` restrictions payload that switch this feature off.
    var restrictionKeys: [String] {
        switch self {
        case .siri: ["allowAssistant"]
        case .writingTools: ["allowWritingTools"]
        case .genmoji: ["allowGenmoji"]
        case .imagePlayground: ["allowImagePlayground"]
        case .chatGPT: ["allowExternalIntelligenceIntegrations", "allowExternalIntelligenceIntegrationsSignIn"]
        case .mailSummaries: ["allowMailSummary"]
        case .mailSmartReplies: ["allowMailSmartReplies"]
        case .safariSummaries: ["allowSafariSummary"]
        case .notesSummaries: ["allowNotesTranscriptionSummary"]
        case .messagesSummaries, .notificationSummaries, .inlinePredictions, .spatialPhotos, .photosCleanUp,
             .xcodeCompletion: []
        }
    }

    /// Settings with no restriction key, pinned to their "off" value instead.
    var pinnedSettings: [PinnedSetting] {
        switch self {
        case .siri:
            [
                PinnedSetting(domain: "com.apple.assistant.support", key: "Assistant Enabled", disabledValue: false),
                PinnedSetting(domain: "com.apple.Siri", key: "StatusMenuVisible", disabledValue: false),
                PinnedSetting(domain: "com.apple.Siri", key: "VoiceTriggerUserEnabled", disabledValue: false)
            ]
        case .mailSummaries:
            [PinnedSetting(domain: "group.com.apple.mail", key: "DisableAutomaticMessageSummarization",
                           disabledValue: true)]
        case .mailSmartReplies:
            [PinnedSetting(domain: "group.com.apple.mail", key: "PersonalizedSmartReplies", disabledValue: false)]
        case .messagesSummaries:
            [PinnedSetting(domain: "com.apple.MobileSMS", key: "messageSummarizationEnabled", disabledValue: false)]
        case .notificationSummaries:
            [PinnedSetting(domain: "group.com.apple.usernoted", key: "summarize_previews", disabledValue: false)]
        case .inlinePredictions:
            [PinnedSetting(domain: ".GlobalPreferences", key: "NSAutomaticInlinePredictionEnabled",
                           disabledValue: false)]
        case .spatialPhotos:
            [PinnedSetting(domain: "com.apple.spatialphotosrelive", key: "LocallyDisabled", disabledValue: true)]
        case .writingTools, .genmoji, .imagePlayground, .chatGPT, .safariSummaries, .notesSummaries,
             .photosCleanUp, .xcodeCompletion:
            []
        }
    }

    var modelPacks: [AIModelPack] {
        switch self {
        case .siri, .writingTools, .mailSummaries, .mailSmartReplies, .messagesSummaries, .notificationSummaries,
             .safariSummaries, .notesSummaries:
            [.foundation]
        case .genmoji, .imagePlayground: [.foundation, .imageGeneration]
        case .spatialPhotos: [.spatialScenes]
        case .photosCleanUp: [.photosCleanUp]
        case .xcodeCompletion: [.codeCompletion]
        case .chatGPT, .inlinePredictions: []
        }
    }

    /// Features that are only their models: there is no switch, so they're "off" when the models are gone.
    var isModelOnly: Bool {
        restrictionKeys.isEmpty && pinnedSettings.isEmpty
    }

    /// Model packs that can go when exactly these features are turned off.
    static func removablePacks(turningOff features: Set<AIFeature>) -> [AIModelPack] {
        AIModelPack.allCases.filter { pack in
            let users = pack.dependents
            return !users.isEmpty && users.allSatisfy(features.contains)
        }
    }
}
