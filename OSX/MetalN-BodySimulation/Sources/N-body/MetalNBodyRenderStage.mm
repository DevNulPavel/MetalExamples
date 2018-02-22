/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for instantiating and encoding of vertex and fragment stages.
 */

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"

#import "MetalNBodyRenderPipeline.h"
#import "MetalNBodyRenderPassDescriptor.h"
#import "MetalNBodyFragmentStage.h"
#import "MetalNBodyVertexStage.h"

#import "MetalNBodyRenderStage.h"

@implementation MetalNBodyRenderStage {
@private
    BOOL _isStaged;
    BOOL _isEncoded;
    
    NSDictionary* _globals;
    NSDictionary* _parameters;
    
    id<MTLCommandBuffer>  _cmdBuffer;
    id<MTLLibrary>        _library;
    id<MTLBuffer>         _positions;
    
    uint32_t mnParticles;
    
    MetalNBodyFragmentStage*         mpFragment;
    MetalNBodyVertexStage*           mpVertex;
    MetalNBodyRenderPassDescriptor*  mpDescriptor;
    MetalNBodyRenderPipeline*        mpPipeline;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _isStaged  = NO;
        _isEncoded = NO;
        
        _globals    = nil;
        _parameters = nil;
        _library    = nil;
        _cmdBuffer  = nil;
        _positions  = nil;
        
        mnParticles = NBody::Defaults::kParticles;
        
        mpDescriptor = nil;
        mpPipeline   = nil;
        mpFragment   = nil;
        mpVertex     = nil;
    }
    
    return self;
}

// Установка глобальных параметров
- (void)setGlobals:(NSDictionary *)globals {
    if(globals && !_isStaged) {
        _globals = globals;
        
        mnParticles = [_globals[kNBodyParticles] unsignedIntValue];
        
        if(mpFragment) {
            mpFragment.globals = globals;
        }
    }
}

// Установка параметров конкретной симуляции
- (void)setParameters:(NSDictionary*)parameters {
    if(parameters){
        _parameters = parameters;
        
        if(mpVertex){
            mpVertex.pointSz = [parameters[kNBodyPointSize] floatValue];
        }
    }
}

// Установка соотношения сторон
- (void)setAspect:(float)aspect {
    if(mpVertex){
        mpVertex.aspect = aspect;
    }
}

// Обновление конфига ортографической проекции
- (void) setConfig:(uint32_t)config {
    if(mpVertex){
        mpVertex.config = config;
    }
}

// Выполнятие обновления
- (void) setUpdate:(BOOL)update {
    if(mpVertex){
        mpVertex.update = update;
    }
}

// Получаем указатель на данные буффера цветов
- (nullable simd::float4 *)getColorsPtr {
    simd::float4* pColors = nullptr;
    if(mpVertex) {
        pColors = mpVertex.colors;
    }
    return pColors;
}

- (BOOL)acquire:(nullable id<MTLDevice>)device {
    if(device){
        if(!_library){
            NSLog(@">> ERROR: Failed to instantiate a new default m_Library!");
            return NO;
        }
        
        mpVertex = [MetalNBodyVertexStage new];
        if(!mpVertex){
            NSLog(@">> ERROR: Failed to instantiate a N-Body vertex stage object!");
            return NO;
        }
        
        mpVertex.particles = mnParticles;
        mpVertex.library   = _library;
        mpVertex.device    = device;
        
        if(!mpVertex.isStaged){
            NSLog(@">> ERROR: Failed to acquire a N-Body vertex stage resources!");
            return NO;
        }
        
        mpFragment = [MetalNBodyFragmentStage new];
        if(!mpFragment) {
            NSLog(@">> ERROR: Failed to instantiate a N-Body fragment stage object!");
            return NO;
        }
        
        mpFragment.globals = _globals;
        mpFragment.library = _library;
        mpFragment.device  = device;
       
        if(!mpFragment.isStaged){
            NSLog(@">> ERROR: Failed to acquire a N-Body fragment stage resources!");
            return NO;
        }
        
        mpPipeline = [MetalNBodyRenderPipeline new];
        if(!mpPipeline){
            NSLog(@">> ERROR: Failed to instantiate a N-Body render pipeline object!");
            return NO;
        }
        
        mpPipeline.fragment = mpFragment.function;
        mpPipeline.vertex   = mpVertex.function;
        [mpPipeline buildForDevice:device];
        
        if(!mpPipeline.haveDescriptor){
            NSLog(@">> ERROR: Failed to acquire a N-Body render pipeline resources!");
            return NO;
        }
        
        mpDescriptor = [MetalNBodyRenderPassDescriptor new];
        if(!mpDescriptor){
            NSLog(@">> ERROR: Failed to instantiate a N-Body render pass descriptor object!");
            return NO;
        }
        
        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Инициализация для устройства
- (void)setupForDevice:(nullable id<MTLDevice>)device {
    if(!_isStaged){
        _isStaged = [self acquire:device];
    }
}

// Выполняем рендеринг
- (void)encode:(nullable id<CAMetalDrawable>)drawable{
    _isEncoded = false;
    
    if(!_cmdBuffer) {
        _isEncoded = false;
        NSLog(@">> ERROR: Command buffer is nil!");
        return;
    }
    
    if(!drawable){
        _isEncoded = false;
        NSLog(@">> ERROR: Drawable is nil!");
        return;
    }
    
    mpDescriptor.drawable = drawable;
    
    if(!mpDescriptor.haveTexture){
        _isEncoded = false;
        NSLog(@">> ERROR: Failed to acquire a texture from a CA drawable!");
        return;
    }
    
    id<MTLRenderCommandEncoder> renderEncoder
    = [_cmdBuffer renderCommandEncoderWithDescriptor:mpDescriptor.descriptor];
    
    if(!renderEncoder){
        _isEncoded = false;
        NSLog(@">> ERROR: Failed to acquire a render command encoder!");
        return;
    }
    
    [renderEncoder setRenderPipelineState:mpPipeline.render];
    
    mpVertex.positions  = _positions;
    mpVertex.cmdEncoder = renderEncoder;
    
    mpFragment.cmdEncoder = renderEncoder;
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypePoint
                      vertexStart:0
                      vertexCount:mnParticles
                    instanceCount:1];
    
    [renderEncoder endEncoding];
    
    _isEncoded = true;
}

@end
