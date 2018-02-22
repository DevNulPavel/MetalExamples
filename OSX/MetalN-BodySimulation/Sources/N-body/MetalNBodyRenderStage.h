/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for instantiating and encoding of vertex and fragment stages.
 */

#import <simd/simd.h>

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface MetalNBodyRenderStage : NSObject

// Метал-библиотека
@property (nullable) id<MTLLibrary> library;

// Метал комманд буффер
@property (nullable) id<MTLCommandBuffer> cmdBuffer;

// Переменная метал-буффер позиций
@property (nullable) id<MTLBuffer> positions;

// Query to determine if all the resources are instantiated for the render stage object
@property (readonly) BOOL isStaged;

// Query to determine if all stages are encoded
@property (readonly) BOOL isEncoded;



// Установка глобальных параметров
-(void)setGlobals:(nonnull NSDictionary*)globals;

// Установка параметров конкретной симуляции
- (void)setParameters:(nonnull NSDictionary*)parameters;

// Установка соотношения сторон
- (void)setAspect:(float)aspect;

// Обновление конфига ортографической проекции
- (void)setConfig:(uint32_t)config;

// Выполнятие обновления
- (void)setUpdate:(BOOL)update;

// Получаем указатель на данные буффера цветов
- (nullable simd::float4*)getColorsPtr;

// Инициализация для устройства
- (void)setupForDevice:(nullable id<MTLDevice>)device;

// Выполняем рендеринг
- (void)encode:(nullable id<CAMetalDrawable>)drawable;

@end
