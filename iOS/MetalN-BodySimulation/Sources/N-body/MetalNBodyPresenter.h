/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for rendering (encoding into Metal pipeline components of) N-Body simulation and presenting the frame
 */

#import <simd/simd.h>

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface MetalNBodyPresenter : NSObject

// Есть ли у нас энкодер???
@property (readonly) BOOL haveEncoder;

// Проверяем, завершены ли все стадии
@property (readonly) BOOL isEncoded;


// Генерация  необходимых ресурсов для симуляции
- (void)initWithDevice:(nullable id<MTLDevice>)device;

// Установка глобальных параметров симуляции
- (void)setGlobals:(nonnull NSDictionary *)globals;

// Установка параметров симуляции
- (void)setActiveParameters:(nonnull NSDictionary *)parameters;

// Установка соотношения сторон
- (void)setAspect:(float)aspect;

// Установка типа ортографической проекции
- (void)setConfig:(uint32_t)config;

// Обновление трансформации матрицы модели-вида-проекции
- (void)setUpdate:(BOOL)update;

// Указатель на данные цветов
- (nullable simd::float4 *)getColorsPointer;

// Указатель на данные позиций
- (nullable simd::float4*)getPositionsPointer;

// Указатель на данные ускорений
- (nullable simd::float4 *) getVelocityPointer;

// Выполняем энкодинг для drawable объекта
- (void) encodeForDrawable:(nonnull id<CAMetalDrawable>(^)(void))drawableBlock;

// Ждем пока рендер-энкодер завершит свою работу
- (void)finish;


@end
