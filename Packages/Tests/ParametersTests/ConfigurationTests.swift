import XCTest
@testable import Parameters

final class ConfigurationTests: XCTestCase {

  func testInit() throws {
    
    let a = Configuration(cutoff: 1.0, resonance: 2.0)
    XCTAssertEqual(a.cutoff, 1.0)
    XCTAssertEqual(a.resonance, 2.0)
  }
}
