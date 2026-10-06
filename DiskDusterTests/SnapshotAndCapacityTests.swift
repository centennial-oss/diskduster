//
//  SnapshotAndCapacityTests.swift
//  DiskDusterTests
//
//  Pure logic only: nothing here lists, deletes or backs up real snapshots.
//

import Foundation
import Testing
@testable import DiskDuster

struct SnapshotAndCapacityTests {
    @Test func parsesTimeMachineSnapshotNamesOnly() {
        let output = """
            Snapshots for disk /:
            com.apple.TimeMachine.2026-10-06-060235.local
            com.apple.TimeMachine.2026-10-05-180000.local
            com.apple.os.update-9A91EDBD1402
            com.apple.TimeMachine.2026-10-06-060235.local
            """
        let snapshots = SnapshotService.parseList(output)
        #expect(snapshots.map(\.dateStamp) == ["2026-10-06-060235", "2026-10-05-180000"])
    }

    @Test func rejectsAnythingThatIsNotADateStamp() {
        #expect(LocalSnapshot(name: "com.apple.TimeMachine.2026-10-06-060235.local") != nil)
        #expect(LocalSnapshot(dateStamp: "2026-10-06-060235; rm -rf /") == nil)
        #expect(LocalSnapshot(dateStamp: "2026-10-06") == nil)
        #expect(LocalSnapshot(name: "com.apple.TimeMachine.2026-10-06-060235.local.extra") == nil)
        #expect(!LocalSnapshot.isValidDateStamp("$(reboot)"))
    }

    @Test func deletionScriptNamesEachSnapshot() throws {
        let first = try #require(LocalSnapshot(dateStamp: "2026-10-06-060235"))
        let second = try #require(LocalSnapshot(dateStamp: "2026-10-05-180000"))
        let script = try #require(SnapshotService.deletionScript(for: [first, second]))
        #expect(script.contains("/usr/bin/tmutil deletelocalsnapshots '2026-10-06-060235'"))
        #expect(script.contains("echo 'ok 1'"))
        #expect(SnapshotService.deletionScript(for: []) == nil)
    }

    @Test func deletionUsesOnePrivilegedCall() async throws {
        let first = try #require(LocalSnapshot(dateStamp: "2026-10-06-060235"))
        let second = try #require(LocalSnapshot(dateStamp: "2026-10-05-180000"))
        let runner = FakePrivilegedRunner(result: .success("ok 0\rfail 1\r"))
        let result = await SnapshotService.delete([first, second], runner: runner)
        #expect(runner.calls.count == 1)
        #expect(result.deleted == [first])
        #expect(result.failed == [second])

        let cancelRunner = FakePrivilegedRunner(result: .failure(.cancelled))
        let cancelled = await SnapshotService.delete([first], runner: cancelRunner)
        #expect(cancelled.adminCancelled)
        #expect(cancelled.deleted.isEmpty)
    }

    @Test func capacityPartsAddUpToTheDisk() {
        let volume = VolumeInfo(name: "HD", totalBytes: 1_000, availableBytes: 250, reservedBytes: 110)
        let breakdown = CapacityBreakdown(volume: volume, fullySelected: 300, partlySelected: 40)
        #expect(breakdown.inUse == 300)
        #expect(breakdown.available == 360)
        #expect(breakdown.inUse + breakdown.fullySelected + breakdown.partlySelected + breakdown.reserved
            + breakdown.free == 1_000)

        // Selections larger than the space actually in use are clamped, never negative.
        let oversized = CapacityBreakdown(volume: volume, fullySelected: 900, partlySelected: 900)
        #expect(oversized.fullySelected == 640)
        #expect(oversized.partlySelected == 0)
        #expect(oversized.inUse == 0)
    }
}
