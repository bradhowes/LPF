// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>

#import "../../Sources/Kernel/C++/AcceleratedBiquadFilter.hpp"
#import "../../Sources/Kernel/C++/Kernel.hpp"

@import ParameterAddress;

@interface KernelTests : XCTestCase

@end

@implementation KernelTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testKernelParams {
  Kernel kernel("blah"); //  = Kernel("blah");
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel.setRenderingFormat(1, format, 100);

  kernel.setParameterValuePending(ParameterAddressCutoff, 123.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValuePending(ParameterAddressCutoff), 123.0, 0.001);

  kernel.setParameterValuePending(ParameterAddressResonance, 31.5);
  XCTAssertEqualWithAccuracy(kernel.getParameterValuePending(ParameterAddressResonance), 31.5, 0.001);
}

- (void)testBiquadFilterMagnatudes {
  AcceleratedBiquadFilter filter;
  AUValue nyquistPeriod = 1.0 / (44100.0 / 2);
  filter.calculateParams(8000.0, 0.5, nyquistPeriod, 2);
  const AUValue freqs[] = {100, 200, 300, 400, 500};
  AUValue mags[] = {0, 0, 0, 0, 0};
  filter.magnitudes(freqs, 5, nyquistPeriod, mags);
  AUValue epsilon = 1.0e-6;
  XCTAssertEqualWithAccuracy(mags[0], 0.000595, epsilon);
  XCTAssertEqualWithAccuracy(mags[1], 0.002379, epsilon);
  XCTAssertEqualWithAccuracy(mags[2], 0.005355, epsilon);
  XCTAssertEqualWithAccuracy(mags[3], 0.009519, epsilon);
  XCTAssertEqualWithAccuracy(mags[4], 0.014873, epsilon);
}

- (void)testBiquadFilterApply {
  AcceleratedBiquadFilter filter;
  AUValue nyquistPeriod = 1.0 / (44100.0 / 2);
  filter.calculateParams(8000.0, 0.5, nyquistPeriod, 2);

  AUValue inLeft[] = {0, 0, 0, 0, 0};
  AUValue inRight[] = {0, 0, 0, 0, 0};
  std::vector<AUValue*> inBufs{inLeft, inRight};
  DSPHeaders::BusBuffers ins(inBufs);

  AUValue outLeft[] = {0, 0, 0, 0, 0};
  AUValue outRight[] = {0, 0, 0, 0, 0};
  std::vector<AUValue*> outBufs{outLeft, outRight};
  DSPHeaders::BusBuffers outs(outBufs);

  const AUValue freqs[] = {100, 200, 300, 400, 500};
  AUValue mags[] = {0, 0, 0, 0, 0};
  filter.apply(ins, outs, 5);
  AUValue epsilon = 1.0e-6;

  XCTAssertEqualWithAccuracy(outLeft[0], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[1], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[2], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[3], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[4], 0.0, epsilon);

  XCTAssertEqualWithAccuracy(outRight[0], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outRight[1], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outRight[2], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outRight[3], 0.0, epsilon);
  XCTAssertEqualWithAccuracy(outRight[4], 0.0, epsilon);

  inLeft[0] = 1.0;
  inLeft[1] = -1.0;
  inLeft[2] = 1.0;
  inLeft[3] = -1.0;
  inLeft[4] = 1.0;

  inRight[0] = -1.0;
  inRight[1] =  0.0;
  inRight[2] =  1.0;
  inRight[3] =  0.0;
  inRight[4] = -1.0;

  filter.apply(ins, outs, 5);

  XCTAssertEqualWithAccuracy(outLeft[0],  0.203739, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[1],  0.322877, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[2],  0.107368, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[3], -0.066274, epsilon);
  XCTAssertEqualWithAccuracy(outLeft[4], -0.081670, epsilon);

  XCTAssertEqualWithAccuracy(outRight[0], -0.203739, epsilon);
  XCTAssertEqualWithAccuracy(outRight[1], -0.526615, epsilon);
  XCTAssertEqualWithAccuracy(outRight[2], -0.226505, epsilon);
  XCTAssertEqualWithAccuracy(outRight[3],  0.485521, epsilon);
  XCTAssertEqualWithAccuracy(outRight[4],  0.374450, epsilon);

}

@end
