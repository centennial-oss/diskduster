//
//  BuildInfo.swift
//  DiskDuster
//
//  Version and build metadata. BuildInfoGenerated.swift supplies commit, date, configuration and architecture;
//  CI rewrites it with `make generate-build-info`.
//

import Foundation

enum BuildInfo {
    /// Semantic version from Info.plist (MARKETING_VERSION). Release builds set it with TAGVER.
    nonisolated static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "localdev"
    }

    static var commit: String { BuildInfoGenerated.buildCommit }
    static var buildDate: String { BuildInfoGenerated.buildDate }
    static var buildType: String { BuildInfoGenerated.buildConfiguration }
    static var buildArch: String { BuildInfoGenerated.buildArch }

    /// The architecture this copy is running as, which can differ from a universal build's label.
    nonisolated static var runningArch: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    nonisolated static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// Copyable blob for support and bug reports.
    static var copyableBlob: String {
        """
        Version: \(version) (macOS \(macOSVersion), \(runningArch))
        Commit: \(commit)
        Date: \(buildDate)
        Build Type: \(buildType) (\(buildArch))
        """
    }
}
