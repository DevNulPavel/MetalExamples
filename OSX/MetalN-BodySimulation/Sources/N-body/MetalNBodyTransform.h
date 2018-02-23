/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing N-body linear transformation matrix and buffer.
 */

#import <simd/simd.h>
#import <Metal/Metal.h>

@interface MetalNBodyTransform : NSObject

// Query to determine if a Metal buffer was generated successfully
@property (readonly) BOOL haveBuffer;

// Metal buffer for linear transformation matrix
@property (nullable, readonly) id<MTLBuffer> buffer;

// Linear transformation matrix
@property (readonly) simd::float4x4 transform;

// Metal buffer size
@property (readonly) size_t size;

// Orthographic 2d bounds
@property simd::float3 bounds;

// (x,y,z) centers
@property float center;
@property float zCenter;

// Обновляем финальную матрицу трансформации
- (void)setUpdate:(BOOL)update;

// Обновление переменной соотношения сторон
- (void)setAspect:(float)aspect;

// Выполняем инициализацию для конкретногго устройства
- (void)prepareForDevice:(nullable id<MTLDevice>)device;

// Обновление конфигурации размера ортографической проекции
- (void)setConfig:(uint32_t)config;

@end
