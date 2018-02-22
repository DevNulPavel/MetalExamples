/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a render state pipeline.
 */

#import <Metal/Metal.h>

@interface MetalNBodyRenderPipeline : NSObject
// Вершинная функция
@property (nullable) id<MTLFunction> vertex;
// Фрагментная функция
@property (nullable) id<MTLFunction> fragment;
// Полученный пайплайн стейт
@property (nullable, readonly) id<MTLRenderPipelineState> render;
// Set blending
@property BOOL blend;
// Query to determine if render pipeline state is instantiated
@property (readonly) BOOL haveDescriptor;


// Создаем рендер-пайплайн для устройства
- (void)buildForDevice:(nullable id<MTLDevice>)device;

@end
