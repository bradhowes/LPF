//
//  LowPassFilterAudioUnit.h
//  LowPassFilter
//
//  Created by Brad Howes on 7/15/20.
//  Copyright © 2020 Apple. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "LowPassFilterDSPKernelAdapter.h"

// Define parameter addresses.
extern const AudioUnitParameterID myParam1;

@interface LowPassFilterAudioUnit : AUAudioUnit

@property (nonatomic, readonly) LowPassFilterDSPKernelAdapter *kernelAdapter;
- (void)setupAudioBuses;
- (void)setupParameterTree;
- (void)setupParameterCallbacks;
@end
