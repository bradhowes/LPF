import XCTest
@testable import ParameterAddress

final class ParameterAddressTests: XCTestCase {

  func testParameterAddress() throws {
    XCTAssertEqual(ParameterAddress.cutoff.rawValue, 0)
    XCTAssertEqual(ParameterAddress.resonance.rawValue, 1)
    XCTAssertEqual(ParameterAddress.allCases.count, 2)
  }

  func testParameterDefinitions() throws {
    let depth = ParameterAddress.cutoff.parameterDefinition
    XCTAssertEqual(depth.range.lowerBound, 12.0)
    XCTAssertEqual(depth.range.upperBound, 20_000.0)
    XCTAssertEqual(depth.unit, .hertz)
    XCTAssertTrue(depth.ramping)
    XCTAssertTrue(depth.logScale)

    let delay = ParameterAddress.resonance.parameterDefinition
    XCTAssertEqual(delay.range.lowerBound, -20.0)
    XCTAssertEqual(delay.range.upperBound, 40.0)
    XCTAssertEqual(delay.unit, .decibels)
    XCTAssertTrue(delay.ramping)
    XCTAssertFalse(delay.logScale)
  }

  func testAUParameterGeneration() throws {
    var address: ParameterAddress = .cutoff
    var definition = address.parameterDefinition
    var parameter = definition.parameter
    XCTAssertEqual(parameter.address, address.rawValue)
    XCTAssertEqual(parameter.identifier, definition.identifier)
    XCTAssertEqual(parameter.displayName, definition.localized)
    XCTAssertTrue(parameter.flags.contains(.flag_CanRamp))
    XCTAssertTrue(parameter.flags.contains(.flag_DisplayLogarithmic))

    address = .resonance
    definition = address.parameterDefinition
    parameter = definition.parameter
    XCTAssertTrue(parameter.flags.contains(.flag_CanRamp))
    XCTAssertFalse(parameter.flags.contains(.flag_DisplayLogarithmic))
  }
}
