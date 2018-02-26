#ifndef APPLFilter_h
#define APPLFilter_h

@import Metal;

@protocol APPLFilter

- (nonnull instancetype) initWithDevice:(nonnull id <MTLDevice>)device;

- (MTLSizeAndAlign) heapSizeAndAlignWithInputTextureDescriptor:(nonnull MTLTextureDescriptor *)inDescriptor;

- (_Nullable id <MTLTexture>) executeWithCommandBuffer:(_Nonnull id <MTLCommandBuffer>)commandBuffer
                                          inputTexture:(_Nonnull id <MTLTexture>)inTexture
                                                  heap:(_Nonnull id <MTLHeap>)heap
                                                 fence:(_Nonnull id <MTLFence>)fence;


@end

/**
 Uses the blit encoder to take an input texture and blit it into a texture 
 that has been allocated as a heap resource and then generate full a mipmap 
 for the texture.
 */
@interface APPLDownsampleFilter : NSObject <APPLFilter>
@end


/** 
 Uses a compute encoder to perform a gaussian blur filter on mipmap levels
 [1...n] on the provided input input texture.
 */
@interface APPLGaussianBlurFilter : NSObject <APPLFilter>
@end

#endif /* APPLFilter_h */
