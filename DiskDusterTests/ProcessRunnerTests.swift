//
//  ProcessRunnerTests.swift
//  DiskDusterTests
//

import Foundation
import Testing
@testable import DiskDuster

struct ProcessRunnerTests {
    @Test func collectsOutputAndStatus() async throws {
        let result = try await ProcessRunner.run("/bin/sh", ["-c", "echo hello; echo oops >&2; exit 3"])
        #expect(result.status == 3)
        #expect(result.output == "hello\n")
        #expect(result.errorOutput == "oops\n")
    }

    @Test func returnsWhenAProcessExitsImmediately() async throws {
        for _ in 0..<20 {
            let result = try await ProcessRunner.run("/usr/bin/true", [])
            #expect(result.status == 0)
        }
    }

    @Test func drainsLargeOutputOnBothStreams() async throws {
        // Far more than a pipe buffer holds, on both streams at once.
        let script = "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b >&2"
        let result = try await ProcessRunner.run("/bin/sh", ["-c", script])
        #expect(result.status == 0)
        #expect(result.output == String(repeating: "a", count: 300_000))
        #expect(result.errorOutput == String(repeating: "b", count: 300_000))
    }
}
