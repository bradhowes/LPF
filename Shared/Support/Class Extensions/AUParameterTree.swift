// Copyright © 2020 Brad Howes. All rights reserved.

import AVFoundation

public extension AUParameterTree {
  func parameter(withAddress address: FilterParameterAddress) -> AUParameter? {
    return parameter(withAddress: address.rawValue)
  }
}
