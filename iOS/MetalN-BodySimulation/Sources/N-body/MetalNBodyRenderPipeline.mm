/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a render state pipeline.
 */

#import "MetalNBodyRenderPipeline.h"

@implementation MetalNBodyRenderPipeline {
@private
    BOOL _blend;
    BOOL _haveDescriptor;
    
    id<MTLFunction> _vertex;
    id<MTLFunction> _fragment;

    id<MTLRenderPipelineState> _render;
}

- (instancetype) init {
    self = [super init];
    
    if(self){
        _blend          = NO;
        _haveDescriptor = NO;
        
        _fragment = nil;
        _vertex   = nil;
        _render   = nil;
    }

    return self;
}

- (BOOL)acquire:(nullable id<MTLDevice>) device {
    if(device){
        if(!_vertex){
            NSLog(@">> ERROR: Vertex stage object is nil!");
            return NO;
        }
        if(!_fragment){
            NSLog(@">> ERROR: Fragment stage object is nil!");
            return NO;
        }
        
        MTLRenderPipelineDescriptor* pDescriptor = [MTLRenderPipelineDescriptor new];
        if(!pDescriptor){
            NSLog(@">> ERROR: Failed to instantiate render pipeline descriptor!");
            return NO;
        }
        
        // Устанавливаем функции
        [pDescriptor setVertexFunction:_vertex];
        [pDescriptor setFragmentFunction:_fragment];
        
        // Устанавливаем формат и включаем блендинг
        pDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pDescriptor.colorAttachments[0].blendingEnabled = YES;
        pDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        
        if(_blend){
            // Обычный блендинг
            pDescriptor.colorAttachments[0].sourceRGBBlendFactor        = MTLBlendFactorSourceAlpha;
            pDescriptor.colorAttachments[0].sourceAlphaBlendFactor      = MTLBlendFactorSourceAlpha;
            pDescriptor.colorAttachments[0].destinationRGBBlendFactor   = MTLBlendFactorOneMinusSourceAlpha;
            pDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        } else{
            // Аддитивный блендинг
            pDescriptor.colorAttachments[0].sourceRGBBlendFactor        = MTLBlendFactorSourceAlpha;
            pDescriptor.colorAttachments[0].sourceAlphaBlendFactor      = MTLBlendFactorSourceAlpha;
            pDescriptor.colorAttachments[0].destinationRGBBlendFactor   = MTLBlendFactorOne;
            pDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
        } 
        
        // Создаем пайплайн стейт
        NSError* pError = nil;
        _render = [device newRenderPipelineStateWithDescriptor:pDescriptor
                                                         error:&pError];
        if(!_render) {
            NSString* pDescription = [pError description];
            if(pDescription){
                NSLog(@">> ERROR: Failed to instantiate render pipeline: {%@}", pDescription);
            }else{
                NSLog(@">> ERROR: Failed to instantiate render pipeline!");
            }
            return NO;
        }
        
        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Создаем рендер-пайплайн для устройства
- (void)buildForDevice:(nullable id<MTLDevice>)device {
    if(!_haveDescriptor){
        _haveDescriptor = [self acquire:device];
    }
}

@end

