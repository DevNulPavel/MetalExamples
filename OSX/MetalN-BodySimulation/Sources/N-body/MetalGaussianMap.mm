/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for creating a 2d Gaussian texture.
 */

#import <iostream>

#import <simd/simd.h>

#import "CFQueueGenerator.h"

#import "CMNumerics.h"

#import "MetalGaussianMap.h"

typedef enum : uint32_t {
    eCChannelIsUnkown = 0,
    eCChannelIsR = 1,
    eCChannelIsRG = 2,
    eCChannelIsRGBA = 4
} CChannels;

@implementation MetalGaussianMap {
@private
    BOOL _haveTexture;

    id<MTLTexture> _texture;
    
    uint32_t _texRes;
    uint32_t _width;
    uint32_t _height;
    uint32_t _channels;
    uint32_t _rowBytes;
    
    MTLRegion _region;
        
    dispatch_queue_t  _generateQueue[2];
    
    CFQueueGenerator* _generator;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _texture     = nil;
        _texRes      = 64;
        _width       = _texRes;
        _height      = _texRes;
        _channels    = 4;
        _rowBytes    = _width * _channels;
        _haveTexture = NO;
        
        _generateQueue[0] = nullptr;
        _generateQueue[1] = nullptr;
        
        _generator = nil;

        _region = MTLRegionMake2D(0, 0, _width, _height);
    }
    
    return self;
}

// Разрешение текстуры
- (void) setTexRes:(uint32_t)texRes {
    _texRes = (texRes) ? texRes : 64;
    _width  = _texRes;
    _height = _texRes;
    
    _region = MTLRegionMake2D(0, 0, _width, _height);
}

// Количество каналов
- (void)setChannels:(uint32_t)channels {
    _channels = (channels) ? channels : 4;
    // Нет поддержки RGB текстур
    if(_channels == 3){
        _channels = 4;
    }
}

// Генерим картинку
- (void)generateImage:(nonnull uint8_t *)pImage {
    const float nDelta = 2.0f / float(_texRes);
    
    __block int32_t j = 0;
    
    __block simd::float2 w = -1.0f;
    
    // Идем по вертикали
    dispatch_apply(_texRes, _generateQueue[0], ^(size_t y) {
        w.y += nDelta;
        
        // Идем по горизонтали
        dispatch_apply(_texRes, _generateQueue[1], ^(size_t x) {
            w.x += nDelta;
            
            float d = simd::length(w);
            float t = 1.0f;
            
            t = CM::isLT(d, t) ? d : 1.0f;
            
            // Hermite interpolation where u = {1, 0} and v = {0, 0}
            uint8_t nColor = uint8_t(255.0f * ((2.0f * t - 3.0f) * t * t + 1.0f));
            
            switch(_channels) {
                case eCChannelIsRGBA:
                    pImage[j+0] = nColor;
                    pImage[j+1] = nColor;
                    pImage[j+2] = nColor;
                    pImage[j+3] = nColor;
                    break;
                case eCChannelIsRG:
                    pImage[j+0] = nColor;
                    pImage[j+1] = nColor;
                    break;
                default:
                case eCChannelIsR:
                    pImage[j] = nColor;
                    break;
            }
            
            j += _channels;
        });
        
        w.x = -1.0f;
    });
}

// Создание очередей инициализации
- (BOOL)newQueues{
    if(!_generator){
        _generator = [CFQueueGenerator new];
    }
    
    if(_generator){
        if(!_generateQueue[0]){
            _generator.label = "com.apple.metal.gaussianmap.ycoord";
            _generateQueue[0] = [_generator generateQueue];
        }
        
        if(!_generateQueue[1]){
            _generator.label = "com.apple.metal.gaussianmap.xcoord";
            _generateQueue[1] = [_generator generateQueue];
        }
    }
    return (_generateQueue[0] != nullptr) && (_generateQueue[1] != nullptr);
}

// Генерация новой картинки
- (nullable uint8_t*) newImage {
    uint8_t* pImage = nullptr;
    
    if([self newQueues]){
        pImage = new (std::nothrow) uint8_t[_channels * _texRes * _texRes];
        
        if(pImage != nullptr){
            [self generateImage:pImage];
        }else{
            NSLog(@">> ERROR: Failed allocating backing-store for a Gaussian image!");
        }
    }
    
    return pImage;
}

// Generate a Gaussian texture
- (BOOL) acquire:(nullable id<MTLDevice>)device {
    if(device){
        MTLPixelFormat format = MTLPixelFormatRGBA8Unorm;
        switch (_channels) {
            case eCChannelIsRGBA:
                format = MTLPixelFormatRGBA8Unorm;
                break;
            case eCChannelIsRG:
                format = MTLPixelFormatRG8Unorm;
                break;
            case eCChannelIsR:
            default:
                format = MTLPixelFormatR8Unorm;
                break;
        }
        
        // Описание текстуры
        MTLTextureDescriptor* pDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                                                         width:_width
                                                                                        height:_height
                                                                                     mipmapped:NO];
        if(!pDesc){
            return NO;
        }
        
        // Create a Metal texture from a descriptor
        _texture = [device newTextureWithDescriptor:pDesc];
        if(!_texture){
            return NO;
        }
        
        // Generate a Gaussian image data
        uint8_t* pImage = [self newImage];
        if(!pImage){
            return NO;
        }
        
        _rowBytes = _width * _channels;
        
        // Загружаем данные в текстуру
        [_texture  replaceRegion:_region
                     mipmapLevel:0
                       withBytes:pImage
                     bytesPerRow:_rowBytes];
        
        delete [] pImage;
        
        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Инициализация
- (void)initWithDevice:(nullable id<MTLDevice>)device{
    if(!_haveTexture){
        _haveTexture = [self acquire:device];
    }
}

@end
