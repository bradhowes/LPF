// Copyright © 2020 Brad Howes. All rights reserved.

import XCTest
import LowPassFilterFramework

class BundlePropertiesTests: XCTestCase {
  
  func testComponentAttributes() throws {
    let bundle = Bundle(for: LowPassFilterFramework.FilterAudioUnit.self)
    XCTAssertEqual("LPF", bundle.auBaseName)
    XCTAssertEqual("B-Ray: SimplyLowPass", bundle.auComponentName)
    XCTAssertEqual("aufx", bundle.auComponentType)
    XCTAssertEqual("lpas", bundle.auComponentSubtype)
    XCTAssertEqual("BRay", bundle.auComponentManufacturer)
    XCTAssertEqual("LowPassFilterFramework.FilterViewController", bundle.auFactoryFunction)
  }
}
