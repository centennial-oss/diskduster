//
//  DiskDusterApp.swift
//  DiskDuster
//

import AppKit
import SwiftUI

@main
struct DiskDusterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel(settings: AppSettings()))
    }

    var body: some Scene {
        Window("DiskDuster", id: "main") {
            ContentView()
                .environment(model)
                .environment(model.settings)
                .frame(minWidth: 900, minHeight: 580)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Scan") { model.startScan() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
                Button("Clean Selected…") { model.requestClean() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .disabled(model.isBusy || model.selectedItems.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .environment(model.settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
