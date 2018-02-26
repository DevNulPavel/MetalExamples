/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating and managing of N-body simulation vertex stage and resources.
 */

#import <simd/simd.h>

#import <Metal/Metal.h>

@interface MetalNBodyVertexStage : NSObject

// Query to determine if all the resource were instantiated.
@property (readonly) BOOL isStaged;

// Vertex function name
@property (nullable) NSString* name;

// Metal library to use for instantiating a vertex stage
@property (nullable) id<MTLLibrary> library;

// Buffer for point particle positions
@property (nullable) id<MTLBuffer>  positions;

// Vertex stage function
@property (nullable, readonly) id<MTLFunction>  function;

// Point particle colors
@property (nullable, readonly) simd::float4* colorsDataPtr;


// Установка количества партиклов
- (void)setParticles:(uint32_t)particles;

// Установка размера точки
- (void) setPointSz:(float)pointSz;

// Соотношение точки
- (void) setAspect:(float)aspect;

// Конфигурация ортографической проекции
- (void) setConfig:(uint32_t)config;

// Установка необходимости обновить матрицу трансформации
- (void) setUpdate:(BOOL)update;

// Инициализация для конкретного девайся
- (void)initWithDevice:(nullable id<MTLDevice>)device;

// Обновляем буфферы в энкодере
- (void)updateBuffersInsideEncoder:(nullable id<MTLRenderCommandEncoder>)cmdEncoder;

@end
