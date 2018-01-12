//
//  Renderer.m
//  MetalTest
//
//  Created by DevNul on 11/01/2018.
//  Copyright © 2018 empty. All rights reserved.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>

#import "Renderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"

static const NSUInteger kMaxBuffersInFlight = 5;

static const size_t kAlignedUniformsSize = (sizeof(Uniforms) & ~0xFF) + 0x100;

@implementation Renderer {
    dispatch_semaphore_t _inFlightSemaphore;
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;

    id <MTLBuffer> _dynamicUniformBuffer;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    id <MTLTexture> _colorMap;
    MTLVertexDescriptor *_mtlVertexDescriptor;

    uint32_t _uniformBufferOffset;
    uint8_t _uniformBufferIndex;
    void* _uniformBufferAddress;

    double _lastDrawTime;
    
    matrix_float4x4 _projectionMatrix;
    
    float _rotation;

    MTKMesh *_mesh;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    self = [super init];
    if(self) {
        // Получаем Metal Device
        _device = view.device;
        // Создаем семафор для того, чтобы видео карта не сильно убегала от процессора
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        
        _lastDrawTime = [[NSDate date] timeIntervalSince1970];
        
        [self loadMetalWithView:view];
        [self loadAssets];
    }

    return self;
}

- (void)loadMetalWithView:(nonnull MTKView *)view {
    // Выставляем формат буффера глубины
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    // Выставляем формат буффера цвета
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    // Антиаллиасинг
    view.sampleCount = 4;

    // Создаем описание вершин данного буффера один раз для дальнейшего использования
    _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // Координаты вершин
    _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;
    // Координаты текстурных координат
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;
    // Описание расположения в памяти вершин
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    // Описание расположения в памяти текстурных координат
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 8;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;

    // Получаем ссылку на библиотеку данных??
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    // Получаем вершинный и фрагментный шейдеры
    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    // Описание пайплайна отрисовки
    MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = view.sampleCount;             // Антиаллиасинг
    pipelineStateDescriptor.vertexFunction = vertexFunction;            // Вершинный шейдер
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;        // Фрагментный шейдер
    pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;    // Описание вершин в буффере
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;        // Формат пикселей
    pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;      // Формат буффера глубины
    pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;    // Формат буффера трафарета

    // Создание пайплайна отрисовки для дальнейшего использования
    NSError* error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }

    // Описание состояния буффера глубины
    MTLDepthStencilDescriptor* depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    // Буффер для юниформов
    NSUInteger uniformBufferSize = kAlignedUniformsSize * kMaxBuffersInFlight;
    _dynamicUniformBuffer = [_device newBufferWithLength:uniformBufferSize
                                                 options:MTLResourceStorageModeShared];
    _dynamicUniformBuffer.label = @"UniformBuffer";

    // Очередь комманд
    _commandQueue = [_device newCommandQueue];
}

- (void)loadAssets {
    NSError* error;

    MTKMeshBufferAllocator* metalAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice: _device];

    // Создание меша коробки
    MDLMesh* mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){4, 4, 4}
                                            segments:(vector_uint3){2, 2, 2}
                                        geometryType:MDLGeometryTypeTriangles
                                       inwardNormals:NO
                                           allocator:metalAllocator];

    MDLVertexDescriptor* mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);
    mdlVertexDescriptor.attributes[VertexAttributePosition].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name = MDLVertexAttributeTextureCoordinate;

    mdlMesh.vertexDescriptor = mdlVertexDescriptor;

    _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                   device:_device
                                    error:&error];

    if(!_mesh || error){
        NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    }

    // Загрузка текстуры
    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    NSDictionary *textureLoaderOptions = @{ MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
                                            MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate) };
    
    _colorMap = [textureLoader newTextureWithName:@"ColorMap"
                                      scaleFactor:1.0
                                           bundle:nil
                                          options:textureLoaderOptions
                                            error:&error];

    if(!_colorMap || error){
        NSLog(@"Error creating texture %@", error.localizedDescription);
    }
}

- (void)updateDynamicBufferState {
    // Определяем, какой буффер юниформов будем использовать
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;
    // Смещение данных в буффере юниформов
    _uniformBufferOffset = kAlignedUniformsSize * _uniformBufferIndex;
    // Аддрес данных в буффере юниформов
    _uniformBufferAddress = ((uint8_t*)_dynamicUniformBuffer.contents) + _uniformBufferOffset;
}

- (void)updateGameState:(double)delta {
    // Получаем указатель на буффер юниформов
    Uniforms* uniforms = (Uniforms*)_uniformBufferAddress;
    
    // Выставляем матрицу проекции в буффер
    uniforms->projectionMatrix = _projectionMatrix;

    // Матрица модели и вида
    vector_float3 rotationAxis = {1, 1, 0};
    matrix_float4x4 modelMatrix = matrix4x4_rotation(_rotation, rotationAxis);
    matrix_float4x4 viewMatrix = matrix4x4_translation(0.0, 0.0, -7.0);
    uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);

    // Увеличиваем угол поворота
    _rotation += delta * 0.3;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    // Ждем, пока количество отрендеренных кадров станет меньше лимита
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    
    // Вычисляем дельту
    NSTimeInterval timeNow = [[NSDate date] timeIntervalSince1970];
    double delta = timeNow - _lastDrawTime;
    _lastDrawTime = timeNow;
    
    // Из очереди комманд - создаем буффер комманд
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Устанавливаем в буффер комманд обработчик завершения очереди буффера комманд
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer){
         dispatch_semaphore_signal(block_sema);
     }];

    // Обновляем смещения и адрес на буффер юниформов
    [self updateDynamicBufferState];
    
    // Обновляем юниформы
    [self updateGameState:delta];

    // TODO: ???
    /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil) {
        // Создаем энкодер
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        [renderEncoder pushDebugGroup:@"DrawBox"];
        
        // Фронтальная сторона треугольника - по часовой стрелке
        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        // Отброс задних граней
        [renderEncoder setCullMode:MTLCullModeBack];
        // Включаем созданный пайплайн
        [renderEncoder setRenderPipelineState:_pipelineState];
        // Включаем состояние буффера глубины
        [renderEncoder setDepthStencilState:_depthState];
        
        // Включаем буффер юниформов для вершинного шейдера и фрагментного
        [renderEncoder setVertexBuffer:_dynamicUniformBuffer
                                offset:_uniformBufferOffset
                               atIndex:BufferIndexUniforms];
        [renderEncoder setFragmentBuffer:_dynamicUniformBuffer
                                  offset:_uniformBufferOffset
                                 atIndex:BufferIndexUniforms];

        // Идем по всем вершинным буфферам меша и включаем буфферы поочередно с индексами по порядку
        for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++) {
            MTKMeshBuffer* vertexBuffer = _mesh.vertexBuffers[bufferIndex];
            if((NSNull*)vertexBuffer != [NSNull null]){
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset:vertexBuffer.offset
                                       atIndex:bufferIndex];
            }
        }
        
        // Включаем текстуру
        [renderEncoder setFragmentTexture:_colorMap
                                  atIndex:TextureIndexColor];

        // Идем по подмешам и вызываем их поиндексную отрисовку
        for(MTKSubmesh* submesh in _mesh.submeshes) {
            [renderEncoder drawIndexedPrimitives:submesh.primitiveType
                                      indexCount:submesh.indexCount
                                       indexType:submesh.indexType
                                     indexBuffer:submesh.indexBuffer.buffer
                               indexBufferOffset:submesh.indexBuffer.offset];
        }

        [renderEncoder popDebugGroup];

        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    // Коммитим буффер комманд
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size{
    // Корректируем матрицу проекции при ресайзе
    float aspect = size.width / (float)size.height;
    _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

#pragma mark - Matrix Math Utilities

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz)
{
    return (matrix_float4x4) {{
        { 1,   0,  0,  0 },
        { 0,   1,  0,  0 },
        { 0,   0,  1,  0 },
        { tx, ty, tz,  1 }
    }};
}

static matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis)
{
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;

    return (matrix_float4x4) {{
        { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
        { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
        {                   0,                   0,                   0, 1}
    }};
}

matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);

    return (matrix_float4x4) {{
        { xs,   0,          0,  0 },
        {  0,  ys,          0,  0 },
        {  0,   0,         zs, -1 },
        {  0,   0, nearZ * zs,  0 }
    }};
}

@end
