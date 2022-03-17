// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>

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
  Kernel* kernel = new Kernel("blah");
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel->setRenderingFormat(1, format, 100);

  kernel->setParameterValue(ParameterAddressCutoff, 10.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressCutoff), 10.0, 0.001);

  kernel->setParameterValue(ParameterAddressResonance, 20.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressResonance), 20.0, 0.001);
}

@end
