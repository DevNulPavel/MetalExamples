/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import "APPLFilter.h"

static const NSUInteger kThreadgroupWidth  = 16;
static const NSUInteger kThreadgroupHeight = 16;
static const NSUInteger kThreadgroupDepth  = 1;

@implementation APPLDownsampleFilter {
@private
    id <MTLDevice> _device;
    MTLTextureDescriptor *_textureDescriptor;
}

- (instancetype) initWithDevice:(nonnull id <MTLDevice>)device {
    self = [super init];
    
    _device = device;
    
    return self;
}

- (MTLSizeAndAlign) heapSizeAndAlignWithInputTextureDescriptor:(nonnull MTLTextureDescriptor *)inDescriptor {
    _textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:inDescriptor.pixelFormat
                                                               width:inDescriptor.width
                                                              height:inDescriptor.height
                                                           mipmapped:YES];

    // Heap resources must share the same storage mode as the heap.
    _textureDescriptor.storageMode = MTLStorageModePrivate;
    _textureDescriptor.usage |= MTLTextureUsageShaderWrite;
    
    return [_device heapTextureSizeAndAlignWithDescriptor:_textureDescriptor];
}


- (_Nullable id <MTLTexture>) executeWithCommandBuffer:(_Nonnull id <MTLCommandBuffer>)commandBuffer
                                          inputTexture:(_Nonnull id <MTLTexture>)inTexture
                                                  heap:(_Nonnull id <MTLHeap>)heap
                                                 fence:(_Nonnull id <MTLFence>)fence {
    id <MTLTexture> outTexture = [heap newTextureWithDescriptor:_textureDescriptor];
    assert(outTexture && "Failed to allocate on heap, did not request enough resources");
    
    id <MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    
    if(blitCommandEncoder) {
        [blitCommandEncoder waitForFence:fence];
        
        [blitCommandEncoder copyFromTexture:inTexture
                                sourceSlice:0
                                sourceLevel:0
                               sourceOrigin:(MTLOrigin){ 0, 0, 0 }
                                 sourceSize:(MTLSize){ inTexture.width, inTexture.height, inTexture.depth }
                                  toTexture:outTexture
                           destinationSlice:0
                           destinationLevel:0
                          destinationOrigin:(MTLOrigin){ 0, 0, 0}];
        
        [blitCommandEncoder generateMipmapsForTexture:outTexture];
        
        [blitCommandEncoder updateFence:fence];
        
        [blitCommandEncoder endEncoding];
    }
    
    return outTexture;
}

@end

@implementation APPLGaussianBlurFilter {
@private
    id <MTLDevice> _device;
    id <MTLLibrary> _library;
    id <MTLComputePipelineState> _horizontalKernel;
    id <MTLComputePipelineState> _verticalKernel;
}

typedef NS_ENUM(NSInteger, AAPLSeparablePass) {
    AAPLSeparablePassHorizontal = 0,
    AAPLSeparablePassVertical = 1,
    AAPLSeparablePassSize
};

- (instancetype) initWithDevice:(nonnull id <MTLDevice>)device {
    NSError *error;
    
    self = [super init];

    // Create a library for our filter.
    _library = [device newDefaultLibrary];
    
    if(!_library) {
        NSLog(@"Failed creating a new library: %@", error);
    }
    
    // Create a compute kernel function.
    id <MTLFunction> function = [_library newFunctionWithName:@"gaussianblurHorizontal"];
    
    if(!function) {
        NSLog(@"Failed creating a new function");
    }
    
    // Create a compute kernel.
    _horizontalKernel = [device newComputePipelineStateWithFunction:function
                                                              error:&error];
    
    if(!_horizontalKernel) {
        NSLog(@"Failed creating a compute kernel: %@", error);
    }
    
    // Create a compute kernel function.
    function = [_library newFunctionWithName:@"gaussianblurVertical"];
    
    if(!function) {
        NSLog(@"Failed creating a new function");
    }
    
    // Create a compute kernel.
    _verticalKernel = [device newComputePipelineStateWithFunction:function
                                                            error:&error];
    
    if(!_verticalKernel) {
        NSLog(@"Failed creating a compute kernel: %@", error);
    }
    
    _device = device;
    
    return self;
}

- (MTLSizeAndAlign) heapSizeAndAlignWithInputTextureDescriptor:(nonnull MTLTextureDescriptor *)inDescriptor {
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:(inDescriptor.width >> 1)
                                                                                   height:(inDescriptor.height >> 1)
                                                                                mipmapped:NO];
    // Usage
    textureDescriptor.usage |= MTLTextureUsageShaderWrite;
    
    return [_device heapTextureSizeAndAlignWithDescriptor:textureDescriptor];
}

- (_Nullable id <MTLTexture>) executeWithCommandBuffer:(_Nonnull id <MTLCommandBuffer>)commandBuffer
                                          inputTexture:(_Nonnull id <MTLTexture>)inTexture
                                                  heap:(_Nonnull id <MTLHeap>)heap
                                                 fence:(_Nonnull id <MTLFence>)fence {
    
    /**
     Perform blur in place on each mipmap level, starting with the first mipmap 
     level.
     */
    for(uint32_t mipmapLevel = 1; mipmapLevel < inTexture.mipmapLevelCount; ++mipmapLevel) {
        MTLTextureDescriptor *textureDescriptior = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                        width:(inTexture.width >> mipmapLevel)
                                                                                       height:(inTexture.height >> mipmapLevel)
                                                                                    mipmapped:NO];
        // Heap resources must share the same storage mode as the heap.
        textureDescriptior.storageMode = MTLStorageModePrivate;
        
        // Usage
        textureDescriptior.usage |= MTLTextureUsageShaderWrite;
        
        if(textureDescriptior.width <= 0) {
            textureDescriptior.width = 1;
        }
        
        if(textureDescriptior.height <= 0) {
            textureDescriptior.height = 1;
        }

        id <MTLTexture> horizontalTexture = [heap newTextureWithDescriptor:textureDescriptior];
        assert(horizontalTexture && "Failed to allocate on heap, did not request enough resources");
        
        MTLSize threadgroupSize;
        MTLSize threadgroupCount;
        
        // Set the compute kernel's thread group size of 16x16.
        threadgroupSize = MTLSizeMake(kThreadgroupWidth, kThreadgroupHeight, kThreadgroupDepth);
        
        // Calculate the compute kernel's width and height.
        NSUInteger nThreadCountW = (horizontalTexture.width  + threadgroupSize.width -  1) / threadgroupSize.width;
        NSUInteger nThreadCountH = (horizontalTexture.height + threadgroupSize.height - 1) / threadgroupSize.height;
        
        // Set the compute kernel's thread count.
        threadgroupCount = MTLSizeMake(nThreadCountW, nThreadCountH, 1);
        
        id <MTLComputePipelineState> kernel[AAPLSeparablePassSize] = { _horizontalKernel, _verticalKernel };
        id <MTLTexture> inTextures[AAPLSeparablePassSize] = { inTexture, horizontalTexture };
        id <MTLTexture> outTextures[AAPLSeparablePassSize] = { horizontalTexture, inTexture };
        uint32_t mipmapLevelZero = 0;
        
        for(AAPLSeparablePass pass = AAPLSeparablePassHorizontal; pass < AAPLSeparablePassSize; ++pass) {
            id <MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
            
            if(computeEncoder) {
                [computeEncoder waitForFence:fence];
                
                [computeEncoder setComputePipelineState:kernel[pass]];
                
                [computeEncoder setTexture:inTextures[pass]
                                   atIndex:0];
                
                [computeEncoder setTexture:outTextures[pass]
                                   atIndex:1];
                
                [computeEncoder setBytes:(pass == AAPLSeparablePassHorizontal) ? &mipmapLevel : &mipmapLevelZero
                                  length:sizeof(mipmapLevel)
                                 atIndex:0];
                
                [computeEncoder setBytes:(pass == AAPLSeparablePassHorizontal) ? &mipmapLevelZero : &mipmapLevel
                                  length:sizeof(mipmapLevel)
                                 atIndex:1];
                
                [computeEncoder dispatchThreadgroups:threadgroupCount
                               threadsPerThreadgroup:threadgroupSize];
                
                [computeEncoder updateFence:fence];
                
                [computeEncoder endEncoding];
            }
        }
        
        /**
         We can now make our horizontal texture aliasable and use that space for 
         the next mip level.
         */
        [horizontalTexture makeAliasable];
    }
    
    return inTexture;
}

@end
