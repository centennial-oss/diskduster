//
//  AppIconImage.swift
//  DiskDuster
//

import AppKit
import SwiftUI

/// The app's own icon, for the About screen.
struct AppIconImage: View {
    var body: some View {
        appIcon
            .resizable()
    }

    private var appIcon: Image {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            Image(nsImage: iconImage)
        } else {
            Image(nsImage: NSApp.applicationIconImage)
        }
    }
}
