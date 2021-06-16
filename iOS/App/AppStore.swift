// Copyright © 2020 Brad Howes. All rights reserved.

import UIKit

/// Collection of URLs and actions for this application in the app store.
public struct AppStore {
  
  static var appStoreUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    return URL(string: "https://itunes.apple.com/app/id\(appStoreId)")!
  }
  
  static var reviewUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    return URL(string: "https://itunes.apple.com/app/id\(appStoreId)?action=write-review")!
  }
  
  static var supportUrl: URL {
    return URL(string: "https://github.com/bradhowes/LPF")!
  }
  
  static func visitAppStore() {
    UIApplication.shared.open(appStoreUrl, options: [:], completionHandler: nil)
  }
  
  static func reviewApp() {
    UIApplication.shared.open(reviewUrl, options: [:], completionHandler: nil)
  }
  
  static func visitSupportUrl() {
    UIApplication.shared.open(supportUrl, options: [:], completionHandler: nil)
  }
}

