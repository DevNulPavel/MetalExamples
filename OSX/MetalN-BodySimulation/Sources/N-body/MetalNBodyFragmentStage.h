/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating N-body simulation fragment stage.
 */

#import <Metal/Metal.h>

@interface MetalNBodyFragmentStage : NSObject

// Query to determine if all the resource were instantiated.
@property (readonly) BOOL isStaged;

// Fragment function name
@property (nullable) NSString* name;

// Metal library to use for instantiating a fragment stage
@property (nullable) id<MTLLibrary> library;

// Fragment stage function
@property (nullable, readonly) id<MTLFunction> function;


// Установка глобальных настроек
- (void)setGlobals:(nonnull NSDictionary *)globals;

// Инициализация для девайса
- (void)initForDevice:(nullable id<MTLDevice>)device;

// Обновляем буфферы в энкодере
- (void)updateBuffersInsideEncoder:(nullable id<MTLRenderCommandEncoder>)cmdEncoder;

@end
