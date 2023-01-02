// Copyright © 2021 Brad Howes. All rights reserved.

import AudioUnit

public struct Configuration {
  public let cutoff: AUValue
  public let resonance: AUValue

  public init(cutoff: AUValue, resonance: AUValue) {
    self.cutoff = cutoff
    self.resonance = resonance
  }
}
