/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a terrain object.
 */

#import <Metal/Metal.h>

@interface AAPLTerrain : NSObject

// Indices
@property (nonatomic, readwrite) NSUInteger  vertexIndex;
@property (nonatomic, readwrite) NSUInteger  texCoordIndex;
@property (nonatomic, readwrite) NSUInteger  samplerIndex;

@property (nonatomic, readonly) uint32_t heightMapSize;
@property (nonatomic, readonly) uint32_t numOfSlices;

// Designated initializer
- (instancetype) initWithDevice:(id <MTLDevice>)device;

// Encoder
- (void)encode:(id <MTLRenderCommandEncoder>)renderEncoder;
- (void)draw:(id <MTLRenderCommandEncoder>)renderEncoder;

@end
