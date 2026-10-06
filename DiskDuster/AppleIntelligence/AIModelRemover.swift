//
//  AIModelRemover.swift
//  DiskDuster
//

import Foundation

nonisolated struct AIPackNote: Identifiable, Sendable, Hashable {
    let pack: AIModelPack
    let message: String
    var id: String { pack.id + message }
}

nonisolated struct AIRunReport: Sendable {
    enum Outcome: Sendable, Equatable {
        /// Features are off and every selected model is gone.
        case finished
        /// Features are off, but some models could not be removed or confirmed.
        case incomplete
        case profileNotInstalled
        case restored
        case profileStillInstalled
        case failed(String)
    }

    var outcome: Outcome
    var bytesBefore: Int64?
    var bytesAfter: Int64?
    var notes: [AIPackNote] = []

    var bytesRemoved: Int64? {
        guard let bytesBefore, let bytesAfter else { return nil }
        return max(0, bytesBefore - bytesAfter)
    }
}

/// Removes model packs through Apple's asset service, one pack per request, then waits for the inventory to
/// confirm they're gone.
nonisolated enum AIModelRemover {
    @concurrent
    static func remove(
        _ packs: [AIModelPack],
        progress: @escaping @MainActor @Sendable (String) -> Void
    ) async -> AIRunReport {
        guard !packs.isEmpty else { return AIRunReport(outcome: .finished, bytesBefore: 0, bytesAfter: 0) }
        guard AssetService.isAvailable else {
            return AIRunReport(outcome: .failed(
                "Apple's model service isn't responding, so no models were removed. The features stay off."
            ))
        }

        let before = AISnapshot.readPackSizes()
        var notes: [AIPackNote] = []
        var targets: [AIModelPack] = []
        for pack in packs {
            let reported = AssetService.currentAssetType(of: pack)
            if reported != pack.expectedAssetType {
                let why = reported.map { "macOS now calls it \($0), so it was left alone." }
                    ?? "This version of macOS doesn't have it, so it was left alone."
                notes.append(AIPackNote(pack: pack, message: why))
            } else if before[pack] != 0 {
                targets.append(pack)
            }
        }

        for (index, pack) in targets.enumerated() {
            await progress("Removing \(pack.title) (\(index + 1) of \(targets.count))…")
            do {
                try await AssetService.removeDownloadedFiles(of: pack)
            } catch {
                notes.append(AIPackNote(pack: pack, message: error.localizedDescription))
            }
        }

        await progress("Confirming the models are gone…")
        let after = await waitForRemoval(of: targets)
        return summarize(packs: packs, targets: targets, before: before, after: after, notes: notes)
    }

    /// The inventory can lag behind the request, so poll for a short while before reporting.
    private static func waitForRemoval(of packs: [AIModelPack]) async -> [AIModelPack: Int64] {
        var sizes = AISnapshot.readPackSizes()
        for _ in 0..<15 where !Task.isCancelled {
            let remaining = packs.map { sizes[$0] ?? 1 }.reduce(0, +)
            if remaining == 0 { break }
            try? await Task.sleep(for: .seconds(2))
            sizes = AISnapshot.readPackSizes()
        }
        return sizes
    }

    private static func summarize(
        packs: [AIModelPack],
        targets: [AIModelPack],
        before: [AIModelPack: Int64],
        after: [AIModelPack: Int64],
        notes: [AIPackNote]
    ) -> AIRunReport {
        func total(_ sizes: [AIModelPack: Int64]) -> Int64? {
            let known = packs.compactMap { sizes[$0] }
            return known.count == packs.count ? known.reduce(0, +) : nil
        }
        var allNotes = notes
        for pack in targets {
            if let left = after[pack], left > 0 {
                let size = left.formatted(.byteCount(style: .file))
                allNotes.append(AIPackNote(pack: pack, message: "\(size) is still on disk."))
            } else if after[pack] == nil {
                allNotes.append(AIPackNote(pack: pack, message: "Removal couldn't be confirmed."))
            }
        }
        let complete = allNotes.isEmpty
        return AIRunReport(
            outcome: complete ? .finished : .incomplete,
            bytesBefore: total(before),
            bytesAfter: total(after),
            notes: allNotes
        )
    }
}
