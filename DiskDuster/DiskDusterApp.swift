//
//  DiskDusterApp.swift
//  DiskDuster
//
//  Created by James Ranson on 12/17/20.
//

import SwiftUI

@main
struct DiskDusterApp: App {
    //@StateObject private var modelData = ModelData()

    var body: some Scene {
        let mainWindow = WindowGroup {
            ContentView()
        //        .environmentObject(modelData)
        }

        #if os(macOS)
        mainWindow
//            .commands {
//                DiskDusterCommands()
//            }
        #else
        mainWindow
        #endif
        

        #if os(macOS)
//        Settings {
//            DiskDusterSettings()
//        }
        #endif
    }
}

