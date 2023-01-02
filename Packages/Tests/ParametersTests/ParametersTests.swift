import XCTest
import AUv3Support
import Kernel
@testable import ParameterAddress
import Parameters

final class ParametersTests: XCTestCase {

  func testParameterAddress() throws {
    XCTAssertEqual(ParameterAddress.cutoff.rawValue, 0)
    XCTAssertEqual(ParameterAddress.resonance.rawValue, 1)

    XCTAssertEqual(ParameterAddress.allCases.count, 2)
    XCTAssertTrue(ParameterAddress.allCases.contains(.cutoff))
    XCTAssertTrue(ParameterAddress.allCases.contains(.resonance))
  }

  func testParameterDefinitions() throws {
    let aup = Parameters()
    for (index, address) in ParameterAddress.allCases.enumerated() {
      XCTAssertTrue(aup.parameters[index] == aup[address])
    }
  }
}
