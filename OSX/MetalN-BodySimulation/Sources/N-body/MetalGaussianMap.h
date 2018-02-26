/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a 2d Gaussian texture.
 */

#import <Metal/Metal.h>

@interface MetalGaussianMap : NSObject

// Query to find if a texture was generated successfully
@property (readonly) BOOL haveTexture;

// Gaussian texture
@property (nullable, readonly) id<MTLTexture> texture;

// Gaussian texture width
@property (readonly) uint32_t width;

// Gaussian texture height
@property (readonly) uint32_t height;

// Gaussian texture bytes per row
@property (readonly) uint32_t rowBytes;


// Разрешение текстуры
- (void)setTexRes:(uint32_t)texRes;
// Количество каналов
- (void)setChannels:(uint32_t)channels;
// Инициализация
- (void)initWithDevice:(nullable id<MTLDevice>)device;

@end
