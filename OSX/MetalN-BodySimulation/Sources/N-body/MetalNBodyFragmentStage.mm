/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating N-body simulation fragment stage.
 */

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"

#import "MetalGaussianMap.h"

#import "MetalNBodySampler.h"

#import "MetalNBodyFragmentStage.h"

@implementation MetalNBodyFragmentStage {
@private
    BOOL _isStaged;
    
    NSString* _name;
    NSDictionary* _globals;
    
    id<MTLFunction>  _function;
    
    uint32_t _particlesCount;
    uint32_t _textureColorChannels;
    uint32_t _textureResolution;

    MetalGaussianMap* _gaussian;
    MetalNBodySampler* _sampler;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _name = nil;
        _globals  = nil;
        _function = nil;
        
        _isStaged = NO;
        
        _particlesCount = NBody::Defaults::kParticles;
        _textureResolution = NBody::Defaults::kTexRes;
        _textureColorChannels  = NBody::Defaults::kChannels;

        _gaussian = nil;
        _sampler  = nil;
    }
    
    return self;
}

// Установка глобальных настроек
- (void)setGlobals:(NSDictionary *)globals {
    if(globals && !_isStaged){
        _globals = globals;
        
        _particlesCount = [_globals[kNBodyParticles] unsignedIntValue];
        _textureResolution    = [_globals[kNBodyTexRes]    unsignedIntValue];
        _textureColorChannels  = [_globals[kNBodyChannels]  unsignedIntValue];
    }
}

- (BOOL)acquire:(nullable id<MTLDevice>)device{
    if(device){
        if(!_library){
            NSLog(@">> ERROR: Metal library is nil!");
            return NO;
        }
        
        _function = [_library newFunctionWithName:(_name) ? _name : @"NBodyLightingFragment"];
        if(!_function){
            NSLog(@">> ERROR: Failed to instantiate fragment function!");
            return NO;
        }
        
        _sampler = [MetalNBodySampler new];
        if(!_sampler){
            NSLog(@">> ERROR: Failed to instantiate a N-Body sampler object!");
            return NO;
        }
        
        [_sampler initForDevice:device];
        if(!_sampler.haveSampler){
            NSLog(@">> ERROR: Failed to acquire a N-Body sampler resources!");
            return NO;
        }
        
        _gaussian = [MetalGaussianMap new];
        if(!_gaussian){
            NSLog(@">> ERROR: Failed to instantiate a N-Body Gaussian texture object!");
            return NO;
        }
        
        [_gaussian setChannels:_textureColorChannels];
        [_gaussian setTexRes:_textureResolution];
        [_gaussian initWithDevice:device];
        
        if(!_gaussian.haveTexture){
            NSLog(@">> ERROR: Failed to acquire a N-Body Gaussian texture resources!");
            return NO;
        }

        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Инициализация для девайса
- (void)initForDevice:(nullable id<MTLDevice>)device{
    if(!_isStaged){
        _isStaged = [self acquire:device];
    }
}

// Обновляем буфферы в энкодере
- (void)updateBuffersInsideEncoder:(nullable id<MTLRenderCommandEncoder>)cmdEncoder {
    [cmdEncoder setFragmentTexture:_gaussian.texture atIndex:0];
    [cmdEncoder setFragmentSamplerState:_sampler.sampler atIndex:0];
}

@end

