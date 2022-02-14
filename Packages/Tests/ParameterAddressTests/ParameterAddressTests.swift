import XCTest
@testable import ParameterAddress

final class ParameterAddressTests: XCTestCase {

  func testParameterAddress() throws {
    XCTAssertEqual(ParameterAddress.cutoff.rawValue, 0)
    XCTAssertEqual(ParameterAddress.resonance.rawValue, 1)
    XCTAssertEqual(ParameterAddress.allCases.count, 2)
  }

  func testParameterDefinitions() throws {
    let cutoff = ParameterAddress.cutoff.parameterDefinition
    XCTAssertEqual(cutoff.range.lowerBound, 12.0)
    XCTAssertEqual(cutoff.range.upperBound, 20_000.0)
    XCTAssertEqual(cutoff.unit, .hertz)
    XCTAssertTrue(cutoff.ramping)
    XCTAssertTrue(cutoff.logScale)

    let resonance = ParameterAddress.resonance.parameterDefinition
    XCTAssertEqual(resonance.range.lowerBound, -20.0)
    XCTAssertEqual(resonance.range.upperBound, 40.0)
    XCTAssertEqual(resonance.unit, .decibels)
    XCTAssertTrue(resonance.ramping)
    XCTAssertFalse(resonance.logScale)
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
