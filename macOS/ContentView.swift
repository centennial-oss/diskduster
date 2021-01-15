//
//  ContentView.swift
//  DiskDuster
//
//  Created by James Ranson on 12/5/20.
//

import SwiftUI

struct ContentView: View {
    
    @State private var scanButtonDisabled = false
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                HStack{
                Text("DiskDuster")
                    .font(/*@START_MENU_TOKEN@*/.largeTitle/*@END_MENU_TOKEN@*/)
                    .fontWeight(.heavy)
                    Text("v1.0.0")
                        .font(.title3)
                        .multilineTextAlignment(.leading)
                }
                Text("Drive Cleaner for macOS")
                    .font(/*@START_MENU_TOKEN@*/.title2/*@END_MENU_TOKEN@*/)
                Text("DiskDuster identifies and cleans files on your Mac that are")
                    .padding(.top)
                Text("safe to delete, like temporary files, caches and application logs.")
            }
            VStack(alignment: .leading) {
                Text("100% free - forever, with no ads.")
                    .padding(.top)
                Text("100% private - voluntary crash reports are the only data we collect.")
                    .padding(.top, 1.0)
                Text("100% open - view our source code.")
                    .padding(.top, 1.0)
            }
            .padding(.leading, 30.0)
            VStack(alignment: .center) {
                Text("To get started, we'll do a quick scan of your filesystem.")
                .padding(.top, 25)
                Button( action: {
                    scanButtonDisabled = true
                    if openHomeDirectory(initialDir: "file://" + homeDir) {
                        print("\n\nPanel Closed\n\n")
                        doScan()
                    } else {
                        alertUnableToAccess()
                    }
                    scanButtonDisabled = false
                }){
                    Text("Start Filesystem Scan")
                }
                .padding(.top, 20)
                .disabled(scanButtonDisabled)
                Text("See and customize what is scanned")
                .padding(.top, 25)
            }
            Spacer()
            Spacer()
        }
        .frame(width: 1024 , height: 768)
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
