import XCTest
@testable import Parameters

final class ConfigurationTests: XCTestCase {

  func testInit() throws {
    
    let a = Configuration(cutoff: 1579.0, resonance: 12.3)
    XCTAssertEqual(a.cutoff, 1579.0)
    XCTAssertEqual(a.resonance, 12.3)
  }
}
