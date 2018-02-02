/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple Utility class for creating a 2d texture
 */

#ifdef TARGET_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "AAPLArrayTexture.h"

@implementation AAPLArrayTexture
{
@private
    uint32_t         _width;
    uint32_t         _height;
}

- (instancetype)initWithTextureWidth:(NSUInteger)width textureHeight:(NSUInteger)height arrayLength:(NSUInteger)length device:(id <MTLDevice>)device
{
    if (self = [super init])
    {
        _width    = (uint32_t)(width);
        _height   = (uint32_t)(height);
        
        MTLTextureDescriptor *pTexDesc = [MTLTextureDescriptor new];
        
        pTexDesc.textureType = MTLTextureType2DArray;
        pTexDesc.pixelFormat = MTLPixelFormatRGBA8Unorm;
        pTexDesc.width = _width;
        pTexDesc.height = _height;
        pTexDesc.arrayLength = length;
        
        _texture = [device newTextureWithDescriptor:pTexDesc];
    }
    
    return self;
}

- (BOOL)setSlice:(NSUInteger)slice withContentsOfFile:(NSString *)path
{
    
#if TARGET_IOS
    UIImage* pImage = [[UIImage alloc] initWithContentsOfFile:path];
#else
    NSImage *nsimage = [[NSImage alloc] initWithContentsOfFile:path];
    
    NSBitmapImageRep *pImage = [[NSBitmapImageRep alloc] initWithData:[nsimage TIFFRepresentation]];
    nsimage = nil;
#endif
    
    if(!pImage)
    {
        return NO;
    }
    
    CGColorSpaceRef pColorSpace = CGColorSpaceCreateDeviceRGB();
    
    if(!pColorSpace)
    {
        return NO;
    }
    
    uint32_t width    = _width;
    uint32_t height   = _height;
    uint32_t rowBytes = width * 4;
    
    CGContextRef pContext = CGBitmapContextCreate(NULL,
                                                  width,
                                                  height,
                                                  8,
                                                  rowBytes,
                                                  pColorSpace,
                                                  CGBitmapInfo(kCGImageAlphaPremultipliedLast));
    
    CGColorSpaceRelease(pColorSpace);
    
    if(!pContext)
    {
        return NO;
    }
    
    CGRect bounds = CGRectMake(0.0f, 0.0f, width, height);
    
    CGContextClearRect(pContext, bounds);
    
    // flip
    CGContextTranslateCTM(pContext, width, height);
    CGContextScaleCTM(pContext, -1.0, -1.0);
    
    CGContextDrawImage(pContext, bounds, pImage.CGImage);
    
    const void *pPixels = CGBitmapContextGetData(pContext);
    
    if(pPixels != NULL)
    {
        MTLRegion region = MTLRegionMake2D(0, 0, _width, _height);
        
        [_texture replaceRegion:region
                    mipmapLevel:0
                          slice:slice
                      withBytes:pPixels
                    bytesPerRow:rowBytes
                  bytesPerImage:rowBytes*height];
    }
    
    CGContextRelease(pContext);
    
    return YES;
}

- (void) dealloc
{
    _texture = nil;
}

@end
