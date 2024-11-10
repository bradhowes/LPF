// Copyright © 2024 Brad Howes. All rights reserved.

import AppKit
import Foundation
import UI

@objc final class ViewController: FilterViewController {

  @IBOutlet private weak var version: NSTextField!
  @IBOutlet private weak var filterView: FilterView!

  override func viewDidLoad() {
    version.stringValue = "v" + Bundle.main.releaseVersionNumber
    setFilterView(filterView)
    super.viewDidLoad()
  }
}
