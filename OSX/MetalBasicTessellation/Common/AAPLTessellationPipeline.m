/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Tessellation Pipeline for MetalBasicTessellation.
            The exposed properties are user-defined via the ViewController UI elements.
            The compute pipelines are built with a compute kernel (one for triangle patches; one for quad patches).
            The render pipelines are built with a post-tessellation vertex function (one for triangle patches; one for quad patches) and a fragment function. The render pipeline descriptor also configures tessellation-specific properties.
            The tessellation factors buffer is dynamically populated by the compute kernel.
            The control points buffer is populated with static position data.
 */

#include <TargetConditionals.h>
#import "AAPLTessellationPipeline.h"

@implementation AAPLTessellationPipeline {
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _library;
    
    id <MTLComputePipelineState> _computePipelineTriangle;
    id <MTLComputePipelineState> _computePipelineQuad;
    id <MTLRenderPipelineState> _renderPipelineTriangle;
    id <MTLRenderPipelineState> _renderPipelineQuad;
    
    id <MTLBuffer> _tessellationFactorsBuffer;
    id <MTLBuffer> _controlPointsBufferTriangle;
    id <MTLBuffer> _controlPointsBufferQuad;
}

- (nullable instancetype)initWithMTKView:(nonnull MTKView *)view {
    self = [super init];
    if(self) {
        // Настройка
        _wireframe = YES;
        _patchType = MTLPatchTypeTriangle;
        _edgeFactor = 2.0;
        _insideFactor = 2.0;
        
        // Настраиваем метал
        if(![self didSetupMetal]) {
            return nil;
        }
        
        // Настраиваем делегат и устройство во вьюшке
        view.device = _device;
        view.delegate = self;
        
        // Создаем пайплайны вычисления
        if(![self didSetupComputePipelines]) {
            return nil;
        }
        
        // Настраиваем пайплайн отрисовки
        if(![self didSetupRenderPipelinesWithMTKView:view]) {
            return nil;
        }
        
        // Настраиваем буфферы
        [self setupBuffers];
    }
    return self;
}

#pragma mark Setup methods

- (BOOL)didSetupMetal {
    // Получаем Metal девайс
    _device = MTLCreateSystemDefaultDevice();
    if(!_device) {
        NSLog(@"Metal is not supported on this device");
        return NO;
    }
    
    // Проверяем возможности тасселяции
#if TARGET_OS_IOS
    if(![_device supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily3_v2]) {
        NSLog(@"Tessellation is not supported on this device");
        return NO;
    }
#elif TARGET_OS_OSX
    if(![_device supportsFeatureSet:MTLFeatureSet_OSX_GPUFamily1_v1]) {
        NSLog(@"Tessellation is not supported on this device");
        return NO;
    }
#endif
    
    // Создаем коммандную очередь
    _commandQueue = [_device newCommandQueue];
    
    // Создаем библиотеку
    _library = [_device newDefaultLibrary];
    
    return YES;
}

// Создание вычислительного пайплайна
- (BOOL)didSetupComputePipelines {
    NSError* computePipelineError = NULL;
    
    // Создаем вычислительный пайплайн для тесселяции треугольников
    id <MTLFunction> kernelFunctionTriangle = [_library newFunctionWithName:@"tessellation_kernel_triangle"];
    _computePipelineTriangle = [_device newComputePipelineStateWithFunction:kernelFunctionTriangle
                                                                      error:&computePipelineError];
    if(!_computePipelineTriangle) {
        NSLog(@"Failed to create compute pipeline (TRIANGLE), error: %@", computePipelineError);
        return NO;
    }
    
    // Получаем вычислительный пайплайн для тесселяции прямоугольников
    id <MTLFunction> kernelFunctionQuad = [_library newFunctionWithName:@"tessellation_kernel_quad"];
    _computePipelineQuad = [_device newComputePipelineStateWithFunction:kernelFunctionQuad
                                                                  error:&computePipelineError];
    if(!_computePipelineQuad) {
        NSLog(@"Failed to create compute pipeline (QUAD), error: %@", computePipelineError);
        return NO;
    }
    
    return YES;
}

// Создаем рендер-пайплайн
- (BOOL)didSetupRenderPipelinesWithMTKView:(nonnull MTKView *)view {
    NSError* renderPipelineError = nil;
    
    // Создаем описание структуры вершин отрисовки для стадии пост-тасселяции
    MTLVertexDescriptor* vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerPatchControlPoint;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stride = 4.0*sizeof(float);
    
    // Создание повторно используемого дескриптора пайплайна
    MTLRenderPipelineDescriptor* renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    
    // Фрагментный шейдер тасселяции
    id<MTLFunction> fragmentFunction = [_library newFunctionWithName:@"tessellation_fragment"];
    
    // Настраиваем пайплайн отрисовки
    renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
    renderPipelineDescriptor.sampleCount = view.sampleCount;
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    renderPipelineDescriptor.fragmentFunction = fragmentFunction;
    
    // Настраиваем тасселяцию
    renderPipelineDescriptor.tessellationFactorScaleEnabled = NO;
    renderPipelineDescriptor.tessellationFactorFormat = MTLTessellationFactorFormatHalf;
    renderPipelineDescriptor.tessellationControlPointIndexType = MTLTessellationControlPointIndexTypeNone;
    renderPipelineDescriptor.tessellationFactorStepFunction = MTLTessellationFactorStepFunctionConstant;
    renderPipelineDescriptor.tessellationOutputWindingOrder = MTLWindingClockwise;
    renderPipelineDescriptor.tessellationPartitionMode = MTLTessellationPartitionModeFractionalEven;
#if TARGET_OS_IOS
    // In iOS, the maximum tessellation factor is 16
    renderPipelineDescriptor.maxTessellationFactor = 16;
#elif TARGET_OS_OSX
    // In OS X, the maximum tessellation factor is 64
    renderPipelineDescriptor.maxTessellationFactor = 64;
#endif
    
    // Создание пайплайна тасселяции треугольниками
    renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"tessellation_vertex_triangle"];
    _renderPipelineTriangle = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                      error:&renderPipelineError];
    if(!_renderPipelineTriangle){
        NSLog(@"Failed to create render pipeline (TRIANGLE), error %@", renderPipelineError);
        return NO;
    }
    
    // Создание пайплайна тасселяции прямоугольниками
    renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"tessellation_vertex_quad"];
    _renderPipelineQuad = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                  error:&renderPipelineError];
    if (!_renderPipelineQuad) {
        NSLog(@"Failed to create render pipeline state (QUAD), error %@", renderPipelineError);
        return NO;
    }
    
    return YES;
}

- (void)setupBuffers
{
    // Allocate memory for the tessellation factors buffer
    // This is a private buffer whose contents are later populated by the GPU (compute kernel)
    // Создаем буффер для выполнения тасселяции
    _tessellationFactorsBuffer = [_device newBufferWithLength:256
                                                      options:MTLResourceStorageModePrivate];
    _tessellationFactorsBuffer.label = @"Tessellation Factors";
    
    // Настраиваем режим доступа к памяти буфферов
    MTLResourceOptions controlPointsBufferOptions;
#if TARGET_OS_IOS
    controlPointsBufferOptions = MTLResourceStorageModeShared;
#elif TARGET_OS_OSX
    controlPointsBufferOptions = MTLResourceStorageModeManaged;
#endif
    
    static const float controlPointPositionsTriangle[] = {
        -0.8, -0.8, 0.0, 1.0,   // lower-left
         0.0,  0.8, 0.0, 1.0,   // upper-middle
         0.8, -0.8, 0.0, 1.0,   // lower-right
    };
    _controlPointsBufferTriangle = [_device newBufferWithBytes:controlPointPositionsTriangle
                                                        length:sizeof(controlPointPositionsTriangle)
                                                       options:controlPointsBufferOptions];
    _controlPointsBufferTriangle.label = @"Control Points Triangle";
    
    static const float controlPointPositionsQuad[] = {
        -0.8,  0.8, 0.0, 1.0,   // upper-left
         0.8,  0.8, 0.0, 1.0,   // upper-right
         0.8, -0.8, 0.0, 1.0,   // lower-right
        -0.8, -0.8, 0.0, 1.0,   // lower-left
    };
    _controlPointsBufferQuad = [_device newBufferWithBytes:controlPointPositionsQuad
                                                    length:sizeof(controlPointPositionsQuad)
                                                   options:controlPointsBufferOptions];
    _controlPointsBufferQuad.label = @"Control Points Quad";
    
    // More sophisticated tessellation passes might have additional buffers for per-patch user data
}

#pragma mark Compute/Render methods

- (void)computeTessellationFactorsWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    // Создаем вычислительный энкодер
    id <MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    computeCommandEncoder.label = @"Compute Command Encoder";
    
    // Пишем имя для отладочной информации
    [computeCommandEncoder pushDebugGroup:@"Compute Tessellation Factors"];
    
    // Включаем необходимый вычислительный пайплайн
    if(self.patchType == MTLPatchTypeTriangle) {
        [computeCommandEncoder setComputePipelineState:_computePipelineTriangle];
    } else if(self.patchType == MTLPatchTypeQuad) {
        [computeCommandEncoder setComputePipelineState:_computePipelineQuad];
    }
    
    // Для вычислительной стадии устанавливаем данные настроек
    [computeCommandEncoder setBytes:&_edgeFactor length:sizeof(float) atIndex:0];
    [computeCommandEncoder setBytes:&_insideFactor length:sizeof(float) atIndex:1];
    
    // Устанавливаем буффер таccеляции
    [computeCommandEncoder setBuffer:_tessellationFactorsBuffer offset:0 atIndex:2];
    
    // Кидаем задачи в очередь
    [computeCommandEncoder dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
    
    // Заканчиваем энкодинг
    [computeCommandEncoder popDebugGroup];
    [computeCommandEncoder endEncoding];
}

- (void)tessellateAndRenderInMTKView:(nonnull MTKView *)view withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // Obtain a renderPassDescriptor generated from the view's drawable
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    
    // If the renderPassDescriptor is valid, begin the commands to render into its drawable
    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder
        id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderCommandEncoder.label = @"Render Command Encoder";
        
        // Begin encoding render commands, including commands for the tessellator
        [renderCommandEncoder pushDebugGroup:@"Tessellate and Render"];
        
        // Set the correct render pipeline and bind the correct control points buffer
        if(self.patchType == MTLPatchTypeTriangle) {
            [renderCommandEncoder setRenderPipelineState:_renderPipelineTriangle];
            [renderCommandEncoder setVertexBuffer:_controlPointsBufferTriangle offset:0 atIndex:0];
        } else if(self.patchType == MTLPatchTypeQuad) {
            [renderCommandEncoder setRenderPipelineState:_renderPipelineQuad];
            [renderCommandEncoder setVertexBuffer:_controlPointsBufferQuad offset:0 atIndex:0];
        }
        
        // Enable/Disable wireframe mode
        if(self.wireframe) {
            [renderCommandEncoder setTriangleFillMode:MTLTriangleFillModeLines];
        }
        
        // Encode tessellation-specific commands
        [renderCommandEncoder setTessellationFactorBuffer:_tessellationFactorsBuffer offset:0 instanceStride:0];
        NSUInteger patchControlPoints = (self.patchType == MTLPatchTypeTriangle) ? 3 : 4;
        [renderCommandEncoder drawPatches:patchControlPoints patchStart:0 patchCount:1 patchIndexBuffer:NULL patchIndexBufferOffset:0 instanceCount:1 baseInstance:0];
        
        // All render commands have been encoded
        [renderCommandEncoder popDebugGroup];
        [renderCommandEncoder endEncoding];
        
        // Schedule a present once the drawable has been completely rendered to
        [commandBuffer presentDrawable:view.currentDrawable];
    }
}

#pragma mark MTKView delegate methods

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
}

// Отрисовка Metal
- (void)drawInMTKView:(nonnull MTKView *)view {
    @autoreleasepool {
        // Создание коммандного буффера
        id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"Tessellation Pass";
        
        // Выполняем вычислительную стадию тасселяции
        [self computeTessellationFactorsWithCommandBuffer:commandBuffer];
        
        [self tessellateAndRenderInMTKView:view withCommandBuffer:commandBuffer];
        
        // Коммитим тассиляцию и рендеринг
        [commandBuffer commit];
    }
}

@end
