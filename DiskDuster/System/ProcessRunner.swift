//
//  ProcessRunner.swift
//  DiskDuster
//

import Foundation

nonisolated struct ProcessResult: Sendable {
    let status: Int32
    let output: String
    let errorOutput: String
}

/// Runs a command and collects its output without blocking a thread on it.
///
/// `Process.waitUntilExit()` depends on a run loop, and on the background threads Swift concurrency and GCD
/// use it can miss the exit and wait forever. This waits for the termination handler instead, and drains
/// standard output and standard error at the same time so a full pipe can never stall the child.
nonisolated enum ProcessRunner {
    static func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice

        let collected = Collected()
        let finished = DispatchGroup()
        finished.enter()
        process.terminationHandler = { _ in finished.leave() }
        try process.run()

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        finished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            collected.setOutput(outputHandle.readDataToEndOfFile())
            finished.leave()
        }
        finished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            collected.setErrorOutput(errorHandle.readDataToEndOfFile())
            finished.leave()
        }

        return await withCheckedContinuation { continuation in
            finished.notify(queue: .global(qos: .userInitiated)) {
                continuation.resume(returning: collected.result(status: process.terminationStatus))
            }
        }
    }

    /// Output gathered from the reader threads, guarded by a lock.
    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var output = Data()
        private var errorOutput = Data()

        func setOutput(_ data: Data) { lock.withLock { output = data } }
        func setErrorOutput(_ data: Data) { lock.withLock { errorOutput = data } }

        func result(status: Int32) -> ProcessResult {
            lock.withLock {
                ProcessResult(
                    status: status,
                    output: String(bytes: output, encoding: .utf8) ?? "",
                    errorOutput: String(bytes: errorOutput, encoding: .utf8) ?? ""
                )
            }
        }
    }
}
