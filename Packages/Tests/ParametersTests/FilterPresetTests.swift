import XCTest
@testable import Parameters

final class AudioUnitParametersTests: XCTestCase {

  func testInit() throws {
    
    let a = FilterPreset(cutoff: 1.0, resonance: 2.0)
    XCTAssertEqual(a.cutoff, 1.0)
    XCTAssertEqual(a.resonance, 2.0)
  }
}
