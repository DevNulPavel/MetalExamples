/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing the N-body compute resources.
 */

#import <simd/simd.h>
#import <Metal/Metal.h>

@interface MetalNBodyComputeStage : NSObject

// Query to determine if all the resource were instantiated.
@property (readonly) BOOL isStaged;

// Compute kernel's function name
@property (nullable) NSString* name;

// Metal library to use for instantiating a compute stage
@property (nullable) id<MTLLibrary> library;

// Setup compute pipeline state and encode
@property (nullable, nonatomic, setter=encode:) id<MTLCommandBuffer> cmdBuffer;


// Настройка и генерация необходимых ресурсов для девайса
- (void)setupForDevice:(nullable id<MTLDevice>)device;

// Swap the read and write buffers
- (void) swapBuffers;

// Получаем текущий активный буффер с позициями
- (nullable id<MTLBuffer>)getActivePositionBuffer;

// Указатель на данные с позициями
- (nullable simd::float4 *)getPositionData;

// Указатель на данные с ускорениями
- (nullable simd::float4 *) getVelocityData;

// Множитель
- (void)setMultiplier:(uint32_t)multiplier;

// Установка глобальных параметров
- (void)setGlobals:(nonnull NSDictionary *)globals;

// Установка параметров конкретной симуляции
- (void)setActiveParameters:(nonnull NSDictionary *)parameters;

@end
