/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 N-body controller object for visualizing the simulation.
 */

#import <simd/simd.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface NBodyVisualizer : NSObject

// Инициализированны ли все необходимые ресурсы??
@property (readonly) BOOL haveVisualizer;

// Тип ортографической проекции
@property uint32_t config;

// Coordinate points on the Eunclidean axis of simulation
@property (nonatomic) simd::float3 axis;

// Соотношение сторон
@property (nonatomic) float aspect;

// Total number of frames to be rendered for a N-body simulation type
@property (nonatomic) uint32_t frames;

// Количество партиклов
@property (nonatomic) uint32_t particles;

// Разрешение текстуры - дефолтное 64x64.
@property (nonatomic) uint32_t texRes;

// Выставляется, когда все фреймы симуляции были отрендерены
@property (readonly) BOOL isComplete;

// Текущий активный тип симуляции
@property (readonly) uint32_t active;

// Текущий кадр, который рендерится
@property (readonly) uint32_t frame;

// Создание всех необходимых ресурсов для симуляции
- (void) acquire:(nullable id<MTLDevice>)device;

- (void)render:(nullable id<CAMetalDrawable>)drawable;

@end
