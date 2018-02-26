/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing N-body linear transformation matrix and buffer.
 */

#import <cmath>
#import <iostream>

#import <simd/simd.h>

#import "CMNumerics.h"
#import "CMTransforms.h"

#import "NBodyDefaults.h"

#import "MetalNBodyTransform.h"

static const simd::float3 kOrth2DBounds[6] =
{
    {50.0f, 50.0f, 50.0f},
    {50.0f, 50.0f, 50.0f},
    {1.0f,  1.0f,  50.0f},
    {5.0f,  5.0f,  50.0f},
    {5.0f,  5.0f,  50.0f},
    {50.0f, 50.0f, 50.0f}
};

@implementation MetalNBodyTransform {
@private
    BOOL _haveBuffer;
    BOOL _update;
    
    uint32_t _config;
    size_t   _size;
    
    float _aspect;
    float _center;
    float _zCenter;
    
    id<MTLDevice>  _device;
    id<MTLBuffer>  _buffer;
    
    simd::float4x4 _transform;
    simd::float3   _bounds;
    
    simd::float4x4* _transformPtr;

    simd::float4x4 _viewMatrix;
    simd::float4x4 _ortiProjection;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _haveBuffer = NO;
        _update     = NO;
        _device     = nil;
        _buffer     = nil;
        _size       = sizeof(simd::float4x4);
        _config     = NBody::Defaults::Configs::eRandom;
        _aspect     = NBody::Defaults::kAspectRatio;
        _center     = NBody::Defaults::kCenter;
        _zCenter    = NBody::Defaults::kZCenter;
        _bounds     = kOrth2DBounds[_config];
        _transform  = 0.0f;
        
        simd::float4x4 rotate1   = CM::rotate(0, 0.0f, 1.0f, 0.0f);
        simd::float4x4 rotate2   = CM::rotate(0, 1.0f, 1.0f, 1.0f);
        simd::float4x4 translate = CM::translate(0, 0, 1000);
        
        _viewMatrix = translate * rotate1 * rotate2;
        
        _ortiProjection = 0.0f;
        
        _transformPtr = nullptr;
    }
    
    return self;
}

// Создание ортографической проекции
- (void) resize {
    // We scale up from the OpenCL version since the dimensions are approximately
    // twice as big on the iPad as on the default view.  Also, we don't use the
    // y bound, in order to keep the aspect ratio.
    
    const float aspect =  _center/_aspect;
    const float left   =  _bounds.x * _center;
    const float right  = -_bounds.x * _center;
    const float bottom =  _bounds.x * aspect;
    const float top    = -_bounds.x * aspect;
    const float near   =  _bounds.z * _zCenter;
    const float far    = -_bounds.z * _zCenter;
    
    _ortiProjection = CM::ortho2d(left, right, bottom, top, near, far);
}

// Обновляем финальную матрицу трансформации
- (void)setUpdate:(BOOL)update {
    if(update) {
        *_transformPtr = _transform = _ortiProjection * _viewMatrix;
        _update = update;
    }
}

// Обновление переменной соотношения сторон
- (void)setAspect:(float)aspect {
    if(!CM::isEQ(aspect, _aspect)){
        _aspect = aspect;
        
        [self resize];
        
        [self setUpdate:YES];
    }
}

// Выполняем инициализацию для конкретногго устройства
- (BOOL)acquire:(nullable id<MTLDevice>)device {
    if(device){
        // Generate a Metal buffer for linear transformation matrix
        _buffer = [device newBufferWithLength:_size options:0];
        
        if(!_buffer){
            NSLog(@">> ERROR: Failed to instantiate a buffer for transformation matrix!");
            return NO;
        }
        
        // Liner transformation mvp matrix
        _transformPtr = static_cast<simd::float4x4 *>([_buffer contents]);
        
        if(!_transformPtr){
            NSLog(@">> ERROR: Failed to acquire a host pointer to the transformation matrix buffer!");
            return NO;
        }
        
        return YES;
    } else {
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Выполняем инициализацию для конкретногго устройства
- (void)prepareForDevice:(nullable id<MTLDevice>)device {
    if(!_haveBuffer){
        _haveBuffer = [self acquire:device];
    }
}

// Обновление конфигурации размера ортографической проекции
- (void)setConfig:(uint32_t)config {
    if(config != _config) {
        _config = config;
        _bounds = kOrth2DBounds[_config];
    }
}

@end

