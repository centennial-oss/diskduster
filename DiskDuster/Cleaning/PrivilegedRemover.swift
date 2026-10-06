//
//  PrivilegedRemover.swift
//  DiskDuster
//

import Foundation

nonisolated enum PrivilegedRunError: Error, Equatable {
    case cancelled
    case tooLarge
    case failed(String)
}

/// Runs a shell script as root after the user authenticates.
nonisolated protocol PrivilegedRunning: Sendable {
    func run(shellScript: String, prompt: String) async throws(PrivilegedRunError) -> String
}

/// Removes system items with one administrator prompt per clean.
nonisolated enum PrivilegedRemover {
    /// `do shell script` passes the command to `sh -c`, so it must stay well under ARG_MAX.
    static let maxScriptBytes = 256 * 1024

    /// Builds a script that removes each item and prints `ok N` or `fail N` for the item at index N.
    static func script(for items: [CleanupItem]) -> String {
        var lines = ["export PATH=/usr/bin:/bin:/usr/sbin:/sbin"]
        for (index, item) in items.enumerated() {
            let quoted = PathSafety.shellQuoted(item.path)
            let command = switch item.cleanMode {
            case .removeItem: "/bin/rm -rf -- \(quoted)"
            case .removeContents: "/usr/bin/find \(quoted) -mindepth 1 -delete"
            }
            lines.append("if \(command) 2>/dev/null; then echo 'ok \(index)'; else echo 'fail \(index)'; fi")
        }
        return lines.joined(separator: "\n")
    }

    /// Parses the script's output into the set of item indexes that were removed.
    static func succeededIndexes(from output: String) -> Set<Int> {
        var indexes = Set<Int>()
        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ")
            if parts.count == 2, parts[0] == "ok", let index = Int(parts[1]) {
                indexes.insert(index)
            }
        }
        return indexes
    }
}

/// Uses AppleScript's `do shell script ... with administrator privileges`, which shows the standard macOS
/// authentication dialog. The script and prompt are passed as arguments, never spliced into AppleScript source.
nonisolated struct OsascriptRunner: PrivilegedRunning {
    func run(shellScript: String, prompt: String) async throws(PrivilegedRunError) -> String {
        guard shellScript.utf8.count <= PrivilegedRemover.maxScriptBytes else { throw .tooLarge }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "on run argv",
            "-e", "do shell script (item 1 of argv) with prompt (item 2 of argv) with administrator privileges",
            "-e", "end run",
            shellScript, prompt
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            throw .failed(error.localizedDescription)
        }
        let (status, stdout, stderr) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let outData = output.fileHandleForReading.readDataToEndOfFile()
                let errData = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: (
                    process.terminationStatus,
                    String(bytes: outData, encoding: .utf8) ?? "",
                    String(bytes: errData, encoding: .utf8) ?? ""
                ))
            }
        }
        guard status == 0 else {
            // -128 is AppleScript's "User canceled."
            if stderr.contains("-128") { throw .cancelled }
            throw .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return stdout
    }
}
