//
//  FilePickerGrantPrivs.swift
//  DiskDuster
//
//  Created by James Ranson on 12/6/20.
//

import SwiftUI

let fm = FileManager.default

// openHomeDirectory will keep opening the panel until closed or
func openHomeDirectory(initialDir: String) -> Bool {
    alertNeedsAccess()
    var i: Int8 = 0
    var j: Int8 = 0
    while i == 0 && j < 3 {
       i = openPanel(initialDir: "file:///")
       j += 1
    }
    return i == 1
}

func alertUnableToAccess() {
    let alert = NSAlert()
    alert.messageText = "Unable to Access Filesystem"
    alert.informativeText = "We did not get permission to access your filesystem and could not proceed."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func alertNeedsAccess() {
    let alert = NSAlert()
    alert.messageText = "Grant Filesystem Access"
    alert.informativeText = "On the next screen, click the button labeled \"Grant Access\" to let us access the filesystem."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func openPanel(initialDir: String) -> Int8 {
    let panel = NSOpenPanel()
    panel.canChooseDirectories  = true
    panel.canChooseFiles = false
    panel.resolvesAliases = false
    panel.title = "Grant Access to Home Directory"
    panel.isAccessoryViewDisclosed = false
    panel.canDownloadUbiquitousContents = false
    panel.canResolveUbiquitousConflicts = false
    panel.directoryURL = URL(fileURLWithPath: initialDir)
    panel.prompt = "Grant Access"
    
    let response = panel.runModal()
    if response == NSApplication.ModalResponse.OK, let fileURL = panel.url {
        print("?????", fileURL, initialDir)
        if panel.url?.absoluteString == initialDir {
            print("user granted access to home directory @ ", fileURL)
            return 1
        }
        return 0
    }
    if response == NSApplication.ModalResponse.cancel {
        return -1
    }
    return 0
}

