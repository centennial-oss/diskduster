//
//  AppIdentifier.swift
//  DiskDuster
//

import Foundation

enum AppIdentifier {
    nonisolated static let name = "DiskDuster"
    nonisolated static let trademarkClassification = "™"
    nonisolated static let nameTM = name + trademarkClassification
    nonisolated static let nameSlug = name.lowercased()
    nonisolated static let copyrightHolder = "Centennial OSS Inc."
    nonisolated static let copyright = "Copyright © 2026 \(copyrightHolder)"

    nonisolated static let repoDomain = "github.com"
    nonisolated static let repoOrg = "centennial-oss"
    nonisolated static let repoPath = "\(repoOrg)/\(nameSlug)"
    nonisolated static let repoURL = URL(string: "https://\(repoDomain)/\(repoPath)")!
    /// DiskDuster makes no network calls, so updates are checked by visiting the releases page.
    nonisolated static let releasesURL = URL(string: "https://\(repoDomain)/\(repoPath)/releases")!
    nonisolated static let privacyURL = URL(string: "https://\(repoDomain)/\(repoPath)/blob/main/PRIVACY.md")!
}
