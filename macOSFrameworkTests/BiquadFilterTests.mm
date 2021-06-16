// Copyright © 2020 Apple. All rights reserved.

#import <XCTest/XCTest.h>
#import <vector>

#import "BiquadFilter.h"

@interface BiquadFilterTests : XCTestCase

@end

@implementation BiquadFilterTests

- (void)setUp {
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testFilter {
  BiquadFilter filter;
  
  float nyquistPeriod = 2.0 / 41500.0;
  filter.calculateParams(5500.0, 0.707, nyquistPeriod, 1);
  
  
  std::vector<float> inputSamples;
  std::vector<float> outputSamples;
  for (int index = 0; index < 3; ++index) {
    inputSamples.push_back(cos(index * 2.0 * M_PI / 1000.0) + cos(index * 2.0 * M_PI / 10000.0));
    outputSamples.push_back(0.0);
  }
  
  std::vector<const float*> ins;
  ins.push_back(inputSamples.data());
  std::vector<float*> outs;
  outs.push_back(outputSamples.data());
  
  filter.apply(ins, outs, inputSamples.size());
  
  XCTAssertEqualWithAccuracy(outputSamples[0], 0.243949, 0.000001);
  XCTAssertEqualWithAccuracy(outputSamples[1], 0.976664, 0.000001);
  XCTAssertEqualWithAccuracy(outputSamples[2], 1.836036, 0.000001);
}

- (void)testMagnitudes {
  BiquadFilter filter;
  
  float nyquistPeriod = 2.0 / 41500.0;
  filter.calculateParams(5500.0, 0.707, nyquistPeriod, 1);
  
  float frequencies[] = {100.0, 1000.0, 10000.0};
  float magnitudes[3];
  filter.magnitudes(frequencies, 3, nyquistPeriod, magnitudes);
  
  XCTAssertEqualWithAccuracy(magnitudes[0], 0.0014,   0.0001);
  XCTAssertEqualWithAccuracy(magnitudes[1], 0.1456,   0.0001);
  XCTAssertEqualWithAccuracy(magnitudes[2], -12.1972, 0.0001);
}

@end
