/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a sampler.
 */

#import "MetalNBodySampler.h"

@implementation MetalNBodySampler {
@private
    BOOL _haveSampler;
    id<MTLSamplerState>  _sampler;
}

- (instancetype) init {
    self = [super init];
    if(self){
        _haveSampler = NO;
        _sampler     = nil;
    }
    return self;
}

- (BOOL)acquire:(nullable id<MTLDevice>)device {
    if(device){
        
        // Создаем дескриптор
        MTLSamplerDescriptor* pDescriptor = [MTLSamplerDescriptor new];
        if(!pDescriptor){
            NSLog(@">> ERROR: Failed to instantiate sampler descriptor!");
            return NO;
        }
        
        // Настройки
        pDescriptor.minFilter             = MTLSamplerMinMagFilterLinear;
        pDescriptor.magFilter             = MTLSamplerMinMagFilterLinear;
        pDescriptor.sAddressMode          = MTLSamplerAddressModeClampToEdge;
        pDescriptor.tAddressMode          = MTLSamplerAddressModeClampToEdge;
        pDescriptor.mipFilter             = MTLSamplerMipFilterNotMipmapped;
        pDescriptor.maxAnisotropy         = 1U;
        pDescriptor.normalizedCoordinates = YES;
        pDescriptor.lodMinClamp           = 0.0;
        pDescriptor.lodMaxClamp           = 255.0;
        
        // Создаем семплер
        _sampler = [device newSamplerStateWithDescriptor:pDescriptor];
        if(!_sampler){
            NSLog(@">> ERROR: Failed to instantiate sampler state with descriptor!");
            return NO;
        }
        
        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }

    return NO;
}

- (void)initForDevice:(nullable id<MTLDevice>)device{
    if(!_haveSampler){
        _haveSampler = [self acquire:device];
    }
}

@end

