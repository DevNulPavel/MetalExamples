/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple Utility class for creating a 2d texture allocated as a heap resource.
 */

#import "Metal/Metal.h"

@interface AAPLTexture : NSObject

@property (nonatomic, readonly)  _Nullable id <MTLTexture> texture;
@property (nonatomic, readonly)  MTLTextureType            target;
@property (nonatomic, readonly)  uint32_t                  width;
@property (nonatomic, readonly)  uint32_t                  height;
@property (nonatomic, readonly)  uint32_t                  depth;
@property (nonatomic, readonly)  uint32_t                  format;
@property (nonatomic, readonly)  NSString * _Nonnull       path;
@property (nonatomic, readwrite) BOOL                      flip;

- (_Nonnull id) initWithResourceName:(NSString * _Nonnull )name
                          extension:(NSString * _Nonnull )ext;

- (BOOL) loadAndGetRequiredHeapSizeAndAlign:(_Nonnull id<MTLDevice>)device
                            outSizeAndAlign:(MTLSizeAndAlign* _Nonnull )outSizeAndAlign;

- (BOOL) finalize:(nonnull id<MTLHeap>)heap;

@end
