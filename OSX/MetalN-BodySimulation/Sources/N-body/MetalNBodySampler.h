/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a sampler.
 */

#import <Metal/Metal.h>

@interface MetalNBodySampler : NSObject

// Sample state object for N-body simulation
@property (nullable, readonly) id<MTLSamplerState> sampler;

// Query to find if the sampler state object was generated
@property (readonly) BOOL haveSampler;

- (void)initForDevice:(nullable id<MTLDevice>)device;

@end
