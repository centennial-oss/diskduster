//
//  AboutView.swift
//  DiskDuster
//

import AppKit
import SwiftUI

struct AboutView: View {
    let onClose: () -> Void

    @State private var hoveredLink: URL?
    @State private var didCopyBuildInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    aboutDescription
                    appLinks
                    buildInfoSection
                    trademarkNotice
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 24)
                .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BasicButton(context: BasicButtonContext(
                        action: onClose,
                        label: "Close",
                        keyboardShortcut: .defaultAction
                    ))
                }
            }
        }
        .frame(width: 560)
        .presentationSizing(.fitted)
        .background(AboutEscapeKeyHandler(onEscape: onClose))
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconImage()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(AppIdentifier.nameTM)
                        .font(.system(size: 30, weight: .semibold))
                    Text("v" + BuildInfo.version)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                Text(AppIdentifier.copyright)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutDescription: some View {
        Group {
            descriptionLabel(
                "\(AppIdentifier.name) finds caches, logs, developer leftovers and other files that are safe to "
                    + "remove, shows how much space each one uses, and cleans only what you choose.",
                systemImage: "sparkles"
            )
            descriptionLabel(
                "Files go to the Trash by default, and \(AppIdentifier.name) never touches anything outside its "
                    + "fixed list of cache, log and developer locations.",
                systemImage: "checkmark.shield"
            )
            descriptionLabel(
                "\(AppIdentifier.name) is 100% private. It makes no network connections and collects no "
                    + "analytics. Nothing ever leaves your Mac. Period.",
                systemImage: "hand.raised"
            )
            descriptionLabel("This software is completely free and open source for you to enjoy.",
                             systemImage: "heart")
        }
    }

    private var appLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            link("GitHub: \(AppIdentifier.repoPath)", systemImage: "arrow.up.right.square",
                 destination: AppIdentifier.repoURL)
            link("Check for updates on GitHub", systemImage: "arrow.down.circle",
                 destination: AppIdentifier.releasesURL)
            link("Privacy Policy", systemImage: "hand.raised.square", destination: AppIdentifier.privacyURL)
        }
    }

    private func link(_ title: String, systemImage: String, destination: URL) -> some View {
        Link(destination: destination) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Color(nsColor: .linkColor))
                .underline(hoveredLink == destination, color: Color(nsColor: .linkColor).opacity(0.8))
        }
        .font(.system(size: 15))
        .onHover { isHovering in
            hoveredLink = isHovering ? destination : (hoveredLink == destination ? nil : hoveredLink)
        }
    }

    private var buildInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Build info (copy for support)", systemImage: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                Text(BuildInfo.copyableBlob)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                Spacer()
                BasicButton(context: BasicButtonContext(
                    action: copyBuildInfo,
                    label: didCopyBuildInfo ? "✓ Copied" : "Copy"
                ))
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var trademarkNotice: some View {
        Text(
            "\(AppIdentifier.name) and the \(AppIdentifier.name) logo are trademarks of "
                + "\(AppIdentifier.copyrightHolder)\nAll rights reserved."
        )
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func descriptionLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func copyBuildInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(BuildInfo.copyableBlob, forType: .string)
        didCopyBuildInfo = true
    }
}

#Preview {
    AboutView {}
}

/// Closes the About sheet when Escape is pressed, since its only button is the default (Return) action.
private struct AboutEscapeKeyHandler: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> EscapeMonitorView {
        let view = EscapeMonitorView()
        view.onEscape = onEscape
        view.startMonitoring()
        return view
    }

    func updateNSView(_ nsView: EscapeMonitorView, context: Context) {
        nsView.onEscape = onEscape
    }

    static func dismantleNSView(_ nsView: EscapeMonitorView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

private final class EscapeMonitorView: NSView {
    var onEscape: (() -> Void)?
    private var monitor: Any?

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.onEscape?()
            return nil
        }
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    isolated deinit {
        stopMonitoring()
    }
}
