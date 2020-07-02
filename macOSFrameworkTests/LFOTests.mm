// Copyright © 2020 Apple. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>

#import "LFO.hpp"

@interface LFOTests : XCTestCase

@end

@implementation LFOTests

- (void)testSampleTable {
    constexpr float sampleFrequency = 44100.0;
    constexpr float oscillatorFrequency = 1.0;
    constexpr float theta = 2.0 * M_PI * oscillatorFrequency / sampleFrequency;

    LFO lfo(SineWaveGenerator(4096));
    constexpr float accuracy = 0.000001;

    lfo.start(sampleFrequency, oscillatorFrequency);
    lfo.reset();

    for (auto index = 0; index < 1000; ++index) {
        auto value = lfo.tick();
        auto expected = sin(theta * index);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

- (void)testReset {
    constexpr float sampleFrequency = 22050.0;
    constexpr float oscillatorFrequency = 10.0;
    constexpr float theta = 2.0 * M_PI * oscillatorFrequency / sampleFrequency;

    LFO lfo(SineWaveGenerator(256));
    constexpr float accuracy = 0.0001;

    lfo.start(sampleFrequency, oscillatorFrequency);
    lfo.reset();

    for (auto index = 0; index < 100; ++index) {
        auto value = lfo.tick();
        auto expected = sin(theta * index);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }

    lfo.reset();

    for (auto index = 0; index < 100; ++index) {
        auto value = lfo.tick();
        auto expected = sin(theta * index);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

- (void)testCopy {
    constexpr float sampleFrequency = 22050.0;
    constexpr float oscillatorFrequency = 15.0;
    constexpr float theta = 2.0 * M_PI * oscillatorFrequency / sampleFrequency;

    LFO lfo1(SineWaveGenerator(256));
    constexpr float accuracy = 0.0001;

    lfo1.start(sampleFrequency, oscillatorFrequency);
    lfo1.reset();

    auto lfo2 = lfo1;

    for (auto index = 0; index < 10; ++index) {
        auto value = lfo1.tick();
        auto expected = sin(theta * index);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }

    for (auto index = 0; index < 10; ++index) {
        auto value = lfo2.tick();
        auto expected = sin(theta * index);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }

    for (auto index = 0; index < 10; ++index) {
        auto value = lfo1.tick();
        auto expected = sin(theta * (index + 10));
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

- (void)testTriangleWave {
    constexpr size_t sampleCount = 1024;
    constexpr float sampleFrequency = float(sampleCount);
    constexpr float oscillatorFrequency = 1.0;

    TriangleWaveGenerator generator(sampleCount);
    LFO lfo(generator);
    constexpr float accuracy = 0.0000001;

    lfo.start(sampleFrequency, oscillatorFrequency);
    lfo.reset();

    auto quarter = sampleCount / 4;
    auto slope = 1.0 / quarter;
    for (auto index = 0; index < quarter; ++index) {
        auto value = lfo.tick();
        auto expected = slope * index;
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

- (void)testSquareWave {
    constexpr size_t sampleCount = 1024;
    constexpr float sampleFrequency = float(sampleCount);
    constexpr float oscillatorFrequency = 1.0;

    SquareWaveGenerator generator(sampleCount);
    LFO lfo(generator);
    constexpr float accuracy = 0.0000001;

    lfo.start(sampleFrequency, oscillatorFrequency);
    lfo.reset();

    auto half = 1024 / 2;
    for (auto index = 0; index < half; ++index) {
        auto value = lfo.tick();
        auto expected = 1.0;
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }

    for (auto index = 0; index < half; ++index) {
        auto value = lfo.tick();
        auto expected = -1.0;
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

- (void)testSawtoothWave {
    constexpr size_t sampleCount = 1024;
    constexpr float sampleFrequency = float(sampleCount);
    constexpr float oscillatorFrequency = 1.0;

    SawtoothWaveGenerator generator(sampleCount);
    LFO lfo(generator);
    constexpr float accuracy = 0.0000001;

    lfo.start(sampleFrequency, oscillatorFrequency);
    lfo.reset();

    auto half = 1024 / 2;
    for (auto index = 0; index < half; ++index) {
        auto value = lfo.tick();
        auto expected = float(index) / float(half);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }

    for (auto index = 0; index < half; ++index) {
        auto value = lfo.tick();
        auto expected = float(index) / float(half) - 1.0;
        NSLog(@"%d %f %f", index, value, expected);
        XCTAssertEqualWithAccuracy(value, expected, accuracy);
    }
}

@end
