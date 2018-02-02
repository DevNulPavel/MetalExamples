/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple Utility class for creating a 2d array texture
 */

#import <Metal/Metal.h>

@interface AAPLArrayTexture : NSObject

@property (nonatomic, readonly) id <MTLTexture> texture;
@property (nonatomic, readonly) uint32_t width;
@property (nonatomic, readonly) uint32_t height;

- (instancetype)initWithTextureWidth:(NSUInteger)width textureHeight:(NSUInteger)height arrayLength:(NSUInteger)length device:(id <MTLDevice>)device;
- (BOOL)setSlice:(NSUInteger)slice withContentsOfFile:(NSString *)path;

@end
