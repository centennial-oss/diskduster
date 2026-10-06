//
//  SnapshotService.swift
//  DiskDuster
//

import Foundation

/// A Time Machine local snapshot on the startup disk.
nonisolated struct LocalSnapshot: Identifiable, Hashable, Sendable {
    /// The date stamp Time Machine uses to name the snapshot, such as `2026-10-06-060235`.
    let dateStamp: String
    let date: Date

    var id: String { dateStamp }
    var name: String { "com.apple.TimeMachine.\(dateStamp).local" }

    /// Parses a snapshot name as `tmutil listlocalsnapshots` prints it. Anything else is ignored.
    init?(name: String) {
        guard let match = name.wholeMatch(of: /com\.apple\.TimeMachine\.(\d{4}-\d{2}-\d{2}-\d{6})\.local/) else {
            return nil
        }
        self.init(dateStamp: String(match.1))
    }

    init?(dateStamp: String) {
        guard Self.isValidDateStamp(dateStamp) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        guard let date = formatter.date(from: dateStamp) else { return nil }
        self.dateStamp = dateStamp
        self.date = date
    }

    /// Date stamps are the only snapshot data that reaches a root shell, so they must match exactly.
    static func isValidDateStamp(_ stamp: String) -> Bool {
        stamp.wholeMatch(of: /\d{4}-\d{2}-\d{2}-\d{6}/) != nil
    }
}

nonisolated struct SnapshotDeletion: Sendable {
    var deleted: [LocalSnapshot] = []
    var failed: [LocalSnapshot] = []
    var adminCancelled = false
    var errorMessage: String?
}

/// Lists, deletes and backs up Time Machine local snapshots by calling `/usr/bin/tmutil`.
nonisolated enum SnapshotService {
    private static let tmutil = "/usr/bin/tmutil"

    @concurrent
    static func list() async -> [LocalSnapshot] {
        guard let output = await run(tmutil, ["listlocalsnapshots", "/"]) else { return [] }
        return parseList(output)
    }

    static func parseList(_ output: String) -> [LocalSnapshot] {
        let snapshots = output.components(separatedBy: .newlines).compactMap { line in
            LocalSnapshot(name: line.trimmingCharacters(in: .whitespaces))
        }
        return Array(Set(snapshots)).sorted { $0.date > $1.date }
    }

    /// True when a backup disk is set up, so "Back Up Now" can work.
    @concurrent
    static func hasBackupDestination() async -> Bool {
        guard let output = await run(tmutil, ["destinationinfo"]) else { return false }
        return output.contains("Name")
    }

    /// Starts a Time Machine backup in the background, like choosing Back Up Now from the menu bar.
    @concurrent
    static func startBackup() async -> Bool {
        await run(tmutil, ["startbackup"]) != nil
    }

    @concurrent
    static func isBackupRunning() async -> Bool {
        guard let output = await run(tmutil, ["status"]) else { return false }
        return output.contains("Running = 1")
    }

    /// Builds the root script: one `tmutil deletelocalsnapshots` per snapshot, reporting `ok N` or `fail N`.
    static func deletionScript(for snapshots: [LocalSnapshot]) -> String? {
        guard !snapshots.isEmpty, snapshots.allSatisfy({ LocalSnapshot.isValidDateStamp($0.dateStamp) }) else {
            return nil
        }
        var lines = ["export PATH=/usr/bin:/bin:/usr/sbin:/sbin"]
        for (index, snapshot) in snapshots.enumerated() {
            let command = "\(tmutil) deletelocalsnapshots \(PathSafety.shellQuoted(snapshot.dateStamp))"
            lines.append("if \(command) >/dev/null 2>&1; then echo 'ok \(index)'; else echo 'fail \(index)'; fi")
        }
        return lines.joined(separator: "\n")
    }

    /// Deletes snapshots as root after one administrator prompt.
    @concurrent
    static func delete(
        _ snapshots: [LocalSnapshot],
        runner: any PrivilegedRunning = OsascriptRunner()
    ) async -> SnapshotDeletion {
        var result = SnapshotDeletion()
        guard let script = deletionScript(for: snapshots) else {
            result.failed = snapshots
            result.errorMessage = "No valid snapshots were selected."
            return result
        }
        let noun = snapshots.count == 1 ? "snapshot" : "snapshots"
        let prompt = "DiskDuster needs an administrator password to delete \(snapshots.count) Time Machine \(noun)."
        do {
            let output = try await runner.run(shellScript: script, prompt: prompt)
            let succeeded = PrivilegedRemover.succeededIndexes(from: output)
            for (index, snapshot) in snapshots.enumerated() {
                if succeeded.contains(index) { result.deleted.append(snapshot) } else { result.failed.append(snapshot) }
            }
        } catch {
            result.failed = snapshots
            result.adminCancelled = error == .cancelled
            if case .failed(let message) = error { result.errorMessage = message }
        }
        return result
    }

    /// Runs a command and returns its output, or nil if it couldn't run or exited with an error.
    private static func run(_ executable: String, _ arguments: [String]) async -> String? {
        guard let result = try? await ProcessRunner.run(executable, arguments), result.status == 0 else {
            return nil
        }
        return result.output
    }
}
