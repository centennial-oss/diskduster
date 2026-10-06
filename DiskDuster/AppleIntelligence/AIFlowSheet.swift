//
//  AIFlowSheet.swift
//  DiskDuster
//

import SwiftUI

/// Walks the user through the parts macOS won't let an app do on its own: approving or removing a profile.
struct AIFlowSheet: View {
    @Environment(AppleIntelligenceController.self) private var controller

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch controller.step {
            case .waitingForInstall:
                installSteps(removing: nil)
            case .removingModels(let message):
                installSteps(removing: message)
            case .waitingForRemoval:
                restoreSteps
            case .finished:
                if let report = controller.report { AIReportView(report: report) }
            case .idle:
                EmptyView()
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func installSteps(removing message: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turning Off Apple Intelligence")
                .font(.title2.weight(.bold))
            StepRow(
                number: 1,
                title: "Install the profile in System Settings",
                detail: "Double-click “\(AIProfile.displayName)”, click Install, then enter your password.",
                status: message == nil ? .active : .done
            )
            StepRow(
                number: 2,
                title: "Remove the models",
                detail: message ?? "DiskDuster does this as soon as the profile is installed.",
                status: message == nil ? .pending : .active
            )
            HStack {
                if message == nil {
                    ProgressView().controlSize(.small)
                    Text("Waiting for System Settings…").foregroundStyle(.secondary)
                    Spacer()
                    Button("Open System Settings") { controller.openProfileSettings() }
                    Button("Cancel", role: .cancel) { controller.cancelFlow() }
                        .keyboardShortcut(.cancelAction)
                } else {
                    ProgressView().controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    private var restoreSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turning Apple Intelligence Back On")
                .font(.title2.weight(.bold))
            StepRow(
                number: 1,
                title: "Remove the profile in System Settings",
                detail: "Select “\(AIProfile.displayName)”, click the minus (−) button, then enter your password.",
                status: .active
            )
            Text("Your previous settings come back right away. macOS downloads models again when a feature needs them.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                ProgressView().controlSize(.small)
                Text("Waiting for System Settings…").foregroundStyle(.secondary)
                Spacer()
                Button("Open System Settings") { controller.openProfileSettings() }
                Button("Cancel", role: .cancel) { controller.cancelFlow() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }
}

private struct StepRow: View {
    enum Status { case pending, active, done }

    let number: Int
    let title: String
    let detail: String
    let status: Status

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(status == .pending ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.tint))
                if status == .done {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.weight(.bold))
                        .foregroundStyle(status == .pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
                }
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                    .foregroundStyle(status == .pending ? .secondary : .primary)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AIReportView: View {
    @Environment(AppleIntelligenceController.self) private var controller
    let report: AIRunReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(succeeded ? .green : .orange)
                Text(headline).font(.title2.weight(.bold))
            }
            Text(detail)
                .fixedSize(horizontal: false, vertical: true)
            if !report.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.notes) { note in
                        Label {
                            Text("\(note.pack.title): \(note.message)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                }
                .font(.callout)
            }
            HStack {
                Spacer()
                Button("Done") { controller.dismissReport() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var succeeded: Bool {
        report.outcome == .finished || report.outcome == .restored
    }

    private var headline: String {
        switch report.outcome {
        case .finished: "Apple Intelligence Is Off"
        case .incomplete: "Features Off, Some Models Remain"
        case .profileNotInstalled: "Profile Not Installed"
        case .restored: "Apple Intelligence Is Back On"
        case .profileStillInstalled: "Profile Still Installed"
        case .failed: "Something Went Wrong"
        }
    }

    private var detail: String {
        switch report.outcome {
        case .finished, .incomplete:
            let removed = report.bytesRemoved.map { "Removed \(ByteFormat.string($0)) of models. " } ?? ""
            return removed + "macOS deletes the files on its own schedule, so Storage settings may count them "
                + "for a while."
        case .profileNotInstalled:
            return "Nothing was changed. Try again when you're ready to approve the profile in System Settings."
        case .restored:
            return "Your own settings apply again. macOS downloads models again when a feature needs them."
        case .profileStillInstalled:
            return "The profile is still installed. You can remove it in System Settings at any time."
        case .failed(let message):
            return message
        }
    }
}
