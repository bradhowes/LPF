// Copyright © 2022 Brad Howes. All rights reserved.

import Foundation
import UI

final class ViewController: FilterViewController {

  @IBOutlet weak var filterView: FilterView!

  override public func viewDidLoad() {
    setFilterView(filterView)
    super.viewDidLoad()
  }
}
