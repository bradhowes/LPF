import XCTest
import AUv3Support
import Kernel
import Parameters
import ParameterAddress

final class ParameterTests: XCTestCase {

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
