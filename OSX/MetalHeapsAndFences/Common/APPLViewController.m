/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller interface.
 */

#import <math.h>
#import "APPLViewController.h"
#import "APPLFilter.h"
#import "AAPLTexture.h"

@import simd;
@import ModelIO;
@import MetalKit;

static const NSTimeInterval kTimeoutSeconds = 7.0;

static const uint32_t kImageNamesCount = 6;
static const NSString *imageNames[kImageNamesCount] = {
    @"Assets/one",
    @"Assets/two",
    @"Assets/three",
    @"Assets/four",
    @"Assets/five",
    @"Assets/six"
};

@implementation APPLViewController {
    // view
    MTKView *_view;
    
    // renderer
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _defaultLibrary;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    
    // Filters
    APPLGaussianBlurFilter *_gaussianBlur;
    APPLDownsampleFilter *_downsample;
    
    // uniforms
    matrix_float4x4 _mvp;
    
    // meshes
    MTKMesh *_planeMesh;
    
    // textures
    id<MTLTexture> _displayTexture;
    AAPLTexture   *_imageTextures[kImageNamesCount];
    
    // heaps / fence
    id<MTLHeap> _heap;
    id<MTLFence> _fence;
    
    id<MTLHeap> _imageHeap;
    
    // Random image scaling / translation
    float _scale;
    vector_float2 _screenPosition;
    
    // Timer
    NSDate *_start;
    NSTimeInterval _previousTime;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self _setupMetal];
    if(_device) {
        [self _setupView];
        [self _loadAssets];
        [self _reshape];
    }
	else { // Fallback to a blank UIView, an application could also fallback to OpenGL ES here.
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
    }
}

- (void)_setupView {
    _view = (MTKView *)self.view;
    _view.device = _device;
    _view.delegate = self;
    
    // Setup the render target, choose values based on your app
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)_setupMetal {
    // Set the view to use the default device
    _device = MTLCreateSystemDefaultDevice();
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load all the shader files with a metal file extension in the project
    _defaultLibrary = [_device newDefaultLibrary];
}

- (void)_loadAssets {
    // Generate meshes
    MDLMesh *mdl = [MDLMesh newBoxWithDimensions:(vector_float3){2,2,0} segments:(vector_uint3){1,1,1}
                     geometryType:MDLGeometryTypeTriangles inwardNormals:NO
                        allocator:[[MTKMeshBufferAllocator alloc] initWithDevice: _device]];

    _planeMesh = [[MTKMesh alloc] initWithMesh:mdl device:_device error:nil];
    
    // Load the fragment program into the library
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"texturedQuadFragment"];
    
    // Load the vertex program into the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"texturedQuadVertex"];
    
    // Create a vertex descriptor from the MTKMesh
    MTLVertexDescriptor *vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_planeMesh.vertexDescriptor);
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = _view.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = _view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = _view.depthStencilPixelFormat;
    
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    // Create fence
    _fence = [_device newFence];
    
    // Initialize our filters
    _gaussianBlur = [[APPLGaussianBlurFilter alloc] initWithDevice:_device];
    _downsample = [[APPLDownsampleFilter alloc] initWithDevice:_device];
    
    // Preload all of our images into a heap
    MTLHeapDescriptor *imageHeapDesc = [[MTLHeapDescriptor alloc] init];
    // Make the storage mode shared so the CPU can access the heap
    imageHeapDesc.storageMode = MTLStorageModeShared;
    imageHeapDesc.size = 0;
    
    // Calculate the combined size of all our images
    for(int i = 0; i < kImageNamesCount; ++i) {
        MTLSizeAndAlign sizeAndAlign;
        _imageTextures[i] = [[AAPLTexture alloc] initWithResourceName:(NSString*)imageNames[i]
                                                            extension:@"jpg"];
        
        _imageTextures[i].flip = NO;
        
        if(![_imageTextures[i] loadAndGetRequiredHeapSizeAndAlign:_device
                                                  outSizeAndAlign:&sizeAndAlign]) {
            NSLog(@"Failed to load image %@", imageNames[i]);
        }
        
        imageHeapDesc.size += alignUp(sizeAndAlign.size, sizeAndAlign.align);
    }

    // Create our image heap
    _imageHeap = [_device newHeapWithDescriptor:imageHeapDesc];
    
    // Copy the images into the heap
    for(int i = 0; i < kImageNamesCount; ++i) {
        if(![_imageTextures[i] finalize:_imageHeap]) {
            NSLog(@"Failed to copy image %@ into image heap", imageNames[i]);
        }
    }
    
    // Set up timer
    _start = [NSDate date];
    _previousTime = [_start timeIntervalSinceNow];
    
    _displayTexture = nil;
}

- (void)_setupHeap:(nonnull id <MTLTexture>)inTexture {
    // Calculate the heap size
    MTLTextureDescriptor *descriptor = getDescFromTexture(inTexture);
    
    MTLSizeAndAlign downsampleSizeAndAlignRequirement = [_downsample heapSizeAndAlignWithInputTextureDescriptor:descriptor];
    MTLSizeAndAlign gaussianBlurSizeAndAlignRequirement = [_gaussianBlur heapSizeAndAlignWithInputTextureDescriptor:descriptor];
    
    NSUInteger totalSizeRequirement = downsampleSizeAndAlignRequirement.size + alignUp(gaussianBlurSizeAndAlignRequirement.size, gaussianBlurSizeAndAlignRequirement.align);
    NSUInteger maxAlignmentRequirement = max(gaussianBlurSizeAndAlignRequirement.align, downsampleSizeAndAlignRequirement.align);
    
    // Make sure the heap is big enough to support the largest alignment
    totalSizeRequirement = alignUp(totalSizeRequirement, maxAlignmentRequirement);
    
    if(!_heap || totalSizeRequirement > [_heap maxAvailableSizeWithAlignment:maxAlignmentRequirement]) {
        MTLHeapDescriptor *heapDesc = [[MTLHeapDescriptor alloc] init];
        heapDesc.size = totalSizeRequirement;
        _heap = nil;
        _heap = [_device newHeapWithDescriptor:heapDesc];
    }
}

- (nonnull id <MTLTexture>)_executeFilterGraph:(nonnull id <MTLTexture>)inTexture {
    // Create a command buffer
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Perform the filters
    id <MTLTexture> downsampledTexture = [_downsample executeWithCommandBuffer:commandBuffer
                                                                  inputTexture:inTexture
                                                                          heap:_heap
                                                                         fence:_fence];
    
    id <MTLTexture> blurredTexture = [_gaussianBlur executeWithCommandBuffer:commandBuffer
                                                                inputTexture:downsampledTexture
                                                                        heap:_heap
                                                                       fence:_fence];
    
    [commandBuffer commit];
    
    return blurredTexture;
}

- (void)_render {
    NSTimeInterval currentTime = [_start timeIntervalSinceNow];
    NSTimeInterval elapsedTime = _previousTime - currentTime;
    float blurryness = elapsedTime / kTimeoutSeconds;
    
    if(!_displayTexture || elapsedTime >= kTimeoutSeconds) {
        _previousTime = currentTime;
        
        // Release our display texture from the heap
        [_displayTexture makeAliasable];
        _displayTexture = nil;
  
        // Select an image at random
        NSUInteger r = arc4random_uniform(kImageNamesCount - 1);
        id<MTLTexture> inTexture = _imageTextures[r].texture;
        
        [self _setupHeap:inTexture];
        _displayTexture = [self _executeFilterGraph:inTexture];
        
        [self _reposition];
    }

    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor* renderPassDescriptor = _view.currentRenderPassDescriptor;
    
    if(renderPassDescriptor != nil) {// If we have a valid drawable, begin the commands to render into it
        // Create a render command encoder so we can render into something
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        // We need to wait for compute to finish before we can start our fragment stage
        [renderEncoder waitForFence:_fence
                       beforeStages:MTLRenderStageFragment];
        
        [renderEncoder setDepthStencilState:_depthState];
        
        // Set context state
        [renderEncoder pushDebugGroup:@"DrawQuad"];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:_planeMesh.vertexBuffers[0].buffer offset:_planeMesh.vertexBuffers[0].offset atIndex:0 ];
        [renderEncoder setVertexBytes:&_mvp length:sizeof(_mvp) atIndex:1 ];
        
        [renderEncoder setFragmentTexture:_displayTexture
                                  atIndex:0];
        
        float lod = blurryness * _displayTexture.mipmapLevelCount;
        [renderEncoder setFragmentBytes:&lod
                                 length:sizeof(float)
                                atIndex:0];
        
        MTKSubmesh* submesh = _planeMesh.submeshes[0];
        // Tell the render context we want to draw our primitives
        [renderEncoder drawIndexedPrimitives:submesh.primitiveType indexCount:submesh.indexCount indexType:submesh.indexType indexBuffer:submesh.indexBuffer.buffer indexBufferOffset:submesh.indexBuffer.offset];
        
        [renderEncoder updateFence:_fence
                       afterStages:MTLRenderStageFragment];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
        
        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:_view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

- (void)_reposition {
    NSUInteger r = arc4random_uniform(75);
    _scale = (float)(r + 25) / 100.0f;
    _screenPosition.x = (float)arc4random_uniform(100) / 100.0;
    _screenPosition.y = (float)arc4random_uniform(100) / 100.0;
    [self _reshape];
}

- (void)_reshape {
    float scaledWidth = (float)_displayTexture.width * _scale / (float)self.view.bounds.size.width;
    float scaledHeight = (float)_displayTexture.height * _scale / (float)self.view.bounds.size.height;
    float xTranslation = ((_screenPosition.x - (scaledWidth / 2.0)) * 2.0 - 1.0) / scaledWidth / 10.0;
    float yTranslation = ((_screenPosition.y - (scaledHeight / 2.0)) * 2.0 - 1.0) / scaledHeight / 10.0;

    _mvp = matrix_multiply(matrix_from_scale(scaledWidth, scaledHeight, 1.0), matrix_from_translation(xTranslation, yTranslation, 0.0));
}

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self _reshape];
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
    @autoreleasepool {
        [self _render];
    }
}

#pragma mark Utilities

static NSUInteger max(NSUInteger x, NSUInteger y) {
    return (x >= y) ? x : y;
}

static NSUInteger alignUp(NSUInteger size, NSUInteger align) {
    // Make sure align is a power of 2
    assert(((align-1) & align) == 0);
    
    const NSUInteger alignmentMask = align - 1;
    return ((size + alignmentMask) & (~alignmentMask));
}

static MTLTextureDescriptor *getDescFromTexture(id <MTLTexture> texture) {
    MTLTextureDescriptor *inTextureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:texture.pixelFormat
                                                                                             width:texture.width
                                                                                            height:texture.height
                                                                                         mipmapped:(texture.mipmapLevelCount > 0)];
    return inTextureDesc;
}

static inline matrix_float4x4 matrix_from_translation(float x, float y, float z) {
    matrix_float4x4 m = matrix_identity_float4x4;
    m.columns[3] = (vector_float4) { x, y, z, 1.0 };
    return m;
}

static inline matrix_float4x4 matrix_from_scale(const float x, const float y, const float z) {
    matrix_float4x4 m = {
        .columns[0] = { x, 0.0f, 0.0f, 0.0f },
        .columns[1] = { 0.0f, y, 0.0f, 0.0f },
        .columns[2] = { 0.0f, 0.0f, z, 0.0f },
        .columns[3] = { 0.0f, 0.0f, 0.0f, 1.0f }
    };
    
    return m;
}

@end
