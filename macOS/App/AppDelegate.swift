// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  
  @IBOutlet weak var playMenuItem: NSMenuItem!
  @IBOutlet weak var bypassMenuItem: NSMenuItem!
  @IBOutlet weak var savePresetMenuItem: NSMenuItem!
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  
  var appStoreUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    return URL(string: "https://itunes.apple.com/app/id\(appStoreId)")!
  }
  
  func visitAppStore() {
    NSWorkspace.shared.open(appStoreUrl)
  }
}
