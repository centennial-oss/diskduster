//
//  Cleaner.swift
//  DiskDuster
//

import Foundation

nonisolated enum DeletionMode: String, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trash: "Move to Trash"
        case .permanent: "Delete Permanently"
        }
    }
}

nonisolated struct CleanFailure: Identifiable, Sendable, Hashable {
    let item: CleanupItem
    let reason: String
    var id: String { item.id }
}

nonisolated struct CleanOutcome: Sendable {
    var cleaned: [CleanupItem] = []
    var failures: [CleanFailure] = []
    /// The user dismissed the administrator password prompt, so system items were left alone.
    var adminCancelled = false
    /// At least one item went to the Trash, so its space is not freed until the Trash is emptied.
    var usedTrash = false

    var bytesCleaned: Int64 { cleaned.reduce(0) { $0 + $1.size } }
}

/// Removes cleanup items. User items are moved to the Trash or deleted; system items are deleted as root
/// after a single administrator prompt, which is only shown when system items are part of the clean.
nonisolated struct Cleaner: Sendable {
    let mode: DeletionMode
    let environment: ScanEnvironment
    var privilegedRunner: any PrivilegedRunning = OsascriptRunner()

    @concurrent
    func clean(
        _ items: [CleanupItem],
        progress: @escaping @MainActor @Sendable (String) -> Void
    ) async -> CleanOutcome {
        var outcome = CleanOutcome()
        var userItems: [CleanupItem] = []
        var adminItems: [CleanupItem] = []
        for item in items {
            do {
                try PathSafety.validate(item, in: environment)
                if item.requiresAdmin { adminItems.append(item) } else { userItems.append(item) }
            } catch {
                outcome.failures.append(CleanFailure(item: item, reason: error.reason))
            }
        }

        for (index, item) in userItems.enumerated() {
            if index.isMultiple(of: 4) {
                await progress("Cleaning \(index + 1) of \(userItems.count): \(item.displayPath)")
            }
            if let reason = removeUserItem(item) {
                outcome.failures.append(CleanFailure(item: item, reason: reason))
            } else {
                outcome.cleaned.append(item)
                if mode == .trash && !item.alwaysPermanent { outcome.usedTrash = true }
            }
        }

        if !adminItems.isEmpty {
            await progress("Waiting for administrator password…")
            await removeAdminItems(adminItems, into: &outcome)
        }
        return outcome
    }

    /// Returns nil on success, or a reason the item could not be cleaned.
    func removeUserItem(_ item: CleanupItem) -> String? {
        let permanent = mode == .permanent || item.alwaysPermanent
        switch item.cleanMode {
        case .removeItem:
            do {
                try remove(item.url, permanently: permanent)
                return nil
            } catch {
                return error.localizedDescription
            }
        case .removeContents:
            let children: [String]
            do {
                children = try FileManager.default.contentsOfDirectory(atPath: item.path)
            } catch {
                return error.localizedDescription
            }
            var failed = 0
            var firstError: String?
            for child in children {
                do {
                    try remove(URL(filePath: item.path + "/" + child), permanently: permanent)
                } catch {
                    failed += 1
                    firstError = firstError ?? error.localizedDescription
                }
            }
            guard failed > 0 else { return nil }
            return "\(failed) of \(children.count) items could not be removed. \(firstError ?? "")"
        }
    }

    private func remove(_ url: URL, permanently: Bool) throws {
        if permanently {
            try FileManager.default.removeItem(at: url)
        } else {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    private func removeAdminItems(_ items: [CleanupItem], into outcome: inout CleanOutcome) async {
        let noun = items.count == 1 ? "item" : "items"
        let prompt = "DiskDuster needs an administrator password to permanently delete \(items.count) "
            + "system \(noun)."
        do {
            let output = try await privilegedRunner.run(
                shellScript: PrivilegedRemover.script(for: items), prompt: prompt
            )
            let succeeded = PrivilegedRemover.succeededIndexes(from: output)
            for (index, item) in items.enumerated() {
                if succeeded.contains(index) {
                    outcome.cleaned.append(item)
                } else {
                    let reason = "Could not be removed. It may be in use or protected by macOS."
                    outcome.failures.append(CleanFailure(item: item, reason: reason))
                }
            }
        } catch {
            if error == .cancelled { outcome.adminCancelled = true }
            let reason = switch error {
            case .cancelled: "Skipped because the administrator prompt was cancelled."
            case .tooLarge: "Too many system items at once. Clean fewer system items at a time."
            case .failed(let message): message.isEmpty ? "The administrator command failed." : message
            }
            outcome.failures += items.map { CleanFailure(item: $0, reason: reason) }
        }
    }
}
