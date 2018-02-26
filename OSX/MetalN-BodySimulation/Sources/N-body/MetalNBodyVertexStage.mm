/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating and managing of N-body simulation vertex stage and resources.
 */

#import "CMNumerics.h"

#import "NBodyDefaults.h"

#import "MetalNBodyTransform.h"

#import "MetalNBodyVertexStage.h"

@implementation MetalNBodyVertexStage {
@private
    BOOL  _isStaged;
    
    NSString* _name;
    
    simd::float4* _colorsDataPtr;
    
    id<MTLFunction>  _function;
    id<MTLBuffer>    _positions;
    
    id<MTLBuffer>  _сolorsBuffer;
    id<MTLBuffer>  _pointSizeBuffer;
    
    uint32_t mnParticles;
    
    float  mnPointSz;
    float* _pointSizeDataPtr;
    
    MetalNBodyTransform*  mpTransform;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _isStaged = NO;

        _name      = nil;
        _function  = nil;
        _positions = nil;
        
        _colorsDataPtr = nullptr;
        
        mnPointSz   = NBody::Defaults::kPointSz;
        mnParticles = NBody::Defaults::kParticles;
        
        _сolorsBuffer  = nil;
        _pointSizeBuffer = nil;
        
        mpTransform = nil;
        _pointSizeDataPtr   = nullptr;
    }
    
    return self;
}

// Установка количества партиклов
- (void) setParticles:(uint32_t)particles {
    mnParticles = (particles) ? particles : NBody::Defaults::kParticles;
}

// Установка размера точки
- (void) setPointSz:(float)pointSz {
    if(_pointSizeDataPtr != nullptr){
        *_pointSizeDataPtr = CM::isLT(pointSz, mnPointSz) ? mnPointSz : pointSz;
    }
}

// Соотношение сторон
- (void) setAspect:(float)aspect {
    if(mpTransform) {
        [mpTransform setAspect:aspect];
    }
}

// Конфигурация ортографической проекции
- (void) setConfig:(uint32_t)config{
    if(mpTransform) {
        mpTransform.config = config;
    }
}

// Установка необходимости обновить матрицу трансформации
- (void) setUpdate:(BOOL)update {
    if(mpTransform){
        [mpTransform setUpdate:update];
    }
}

- (BOOL)acquire:(nullable id<MTLDevice>)device{
    if(device){
        if(!_library){
            NSLog(@">> ERROR: Metal library is nil!");
            return NO;
        }
        
        _function = [_library newFunctionWithName:(_name) ? _name : @"NBodyLightingVertex"];
        if(!_function){
            NSLog(@">> ERROR: Failed to instantiate vertex function!");
            return NO;
        }
        
        _сolorsBuffer = [device newBufferWithLength:sizeof(simd::float4)*mnParticles options:0];
        if(!_сolorsBuffer){
            NSLog(@">> ERROR: Failed to instantiate a new m_Colors buffer!");
            return NO;
        }
        
        _colorsDataPtr = static_cast<simd::float4 *>([_сolorsBuffer contents]);
        if(!_colorsDataPtr){
            NSLog(@">> ERROR: Failed to acquire a host pointer for m_Colors buffer!");
            return NO;
        }
        
        _pointSizeBuffer = [device newBufferWithLength:sizeof(float) options:0];
        if(!_pointSizeBuffer){
            NSLog(@">> ERROR: Failed to instantiate a new buffer for m_PointSz size!");
            return NO;
        }
        
        _pointSizeDataPtr = static_cast<float *>([_pointSizeBuffer contents]);
        if(!_pointSizeDataPtr){
            NSLog(@">> ERROR: Failed to acquire a host pointer for buffer representing m_PointSz size!");
            return NO;
        }

        // Создание трансформа
        mpTransform = [MetalNBodyTransform new];
        if(!mpTransform){
            NSLog(@">> ERROR: Failed to instantiate a N-Body linear transform object!");
            return NO;
        }
        
        // Инициализация трансформа
        [mpTransform prepareForDevice:device];
        if(!mpTransform.haveBuffer){
            NSLog(@">> ERROR: Failed to acquire a N-Body transform buffer resource!");
            return NO;
        }

        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Инициализация для конкретного девайся
- (void)initWithDevice:(nullable id<MTLDevice>)device{
    if(!_isStaged){
        _isStaged = [self acquire:device];
    }
}

// Обновляем буфферы в энкодере
- (void)updateBuffersInsideEncoder:(nullable id<MTLRenderCommandEncoder>)cmdEncoder{
    if(_positions){
        [cmdEncoder setVertexBuffer:_positions         offset:0 atIndex:0];
        [cmdEncoder setVertexBuffer:_сolorsBuffer           offset:0 atIndex:1];
        [cmdEncoder setVertexBuffer:mpTransform.buffer offset:0 atIndex:2];
        [cmdEncoder setVertexBuffer:_pointSizeBuffer          offset:0 atIndex:3];
    }
}

@end
