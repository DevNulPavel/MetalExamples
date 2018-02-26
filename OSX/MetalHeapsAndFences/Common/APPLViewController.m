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

#pragma mark - Utilities

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

#pragma mark - Controller

@implementation APPLViewController {
    // Вьюшка
    MTKView* _view;
    
    // Рендерные переменные
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _defaultLibrary;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    
    // Фильтры
    APPLGaussianBlurFilter* _gaussianBlur;
    APPLDownsampleFilter* _downsample;
    
    // Юниформ
    matrix_float4x4 _mvp;
    
    // Меш
    MTKMesh* _planeMesh;
    
    // Текстуры
    id<MTLTexture> _displayTexture;
    AAPLTexture* _imageTextures[kImageNamesCount];
    
    // Кучи и заборы
    id<MTLHeap> _heap;
    id<MTLFence> _fence;
    
    // Куча картинки
    id<MTLHeap> _imageHeap;
    
    // Скейлинг и позиция
    float _scale;
    vector_float2 _screenPosition;
    
    // Таймер
    NSDate* _start;
    NSTimeInterval _previousTime;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupMetal];
    if(_device) {
        [self setupView];
        [self loadAssets];
        [self reshape];
    } else {
        // Fallback to a blank UIView, an application could also fallback to OpenGL ES here.
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
    }
}

- (void)setupView {
    _view = (MTKView *)self.view;
    _view.device = _device;
    _view.delegate = self;
    
    // Формат буффера глубины
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)setupMetal {
    // Создаем девайс
    _device = MTLCreateSystemDefaultDevice();
    
    // Создаем коммандную очередь
    _commandQueue = [_device newCommandQueue];
    
    // Создаем библиотеку для получения шейдеров и тд
    _defaultLibrary = [_device newDefaultLibrary];
}

- (void)loadAssets {
    // Генерация мешей
    MDLMesh* mdl = [MDLMesh newBoxWithDimensions:(vector_float3){2,2,0}
                                        segments:(vector_uint3){1,1,1}
                                    geometryType:MDLGeometryTypeTriangles
                                   inwardNormals:NO
                                       allocator:[[MTKMeshBufferAllocator alloc] initWithDevice: _device]];
    
    // Создаем меш
    _planeMesh = [[MTKMesh alloc] initWithMesh:mdl device:_device error:nil];
    
    // Фрагментный шейдер
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"texturedQuadFragment"];
    
    // Вершинная программа
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"texturedQuadVertex"];
    
    // Создаем дескиптор вершин c описанием расположения данных
    MTLVertexDescriptor* vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(_planeMesh.vertexDescriptor);
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Создаем пайплайн стейт
    MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = _view.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = _view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = _view.depthStencilPixelFormat;
    
    NSError* error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    
    // Настройка состояния работы с глубиной
    MTLDepthStencilDescriptor* depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    // Создаем барьер
    _fence = [_device newFence];
    
    // Создание фильтров
    _gaussianBlur = [[APPLGaussianBlurFilter alloc] initWithDevice:_device];
    _downsample = [[APPLDownsampleFilter alloc] initWithDevice:_device];
    
    // Предзагрузка изображений в кучу
    MTLHeapDescriptor *imageHeapDesc = [[MTLHeapDescriptor alloc] init];
    
    // Режим хранения общий для GPU и CPU
    imageHeapDesc.storageMode = MTLStorageModeShared;
    imageHeapDesc.size = 0;
    
    // Вычисляем общий размер всех картинок
    for(int i = 0; i < kImageNamesCount; ++i) {
        _imageTextures[i] = [[AAPLTexture alloc] initWithResourceName:(NSString*)imageNames[i]
                                                            extension:@"jpg"];
        
        _imageTextures[i].flip = NO;

        MTLSizeAndAlign sizeAndAlign;
        BOOL success = [_imageTextures[i] loadAndGetRequiredHeapSizeAndAlign:_device
                                                             outSizeAndAlign:&sizeAndAlign];
        
        if(!success) {
            NSLog(@"Failed to load image %@", imageNames[i]);
        }
        
        imageHeapDesc.size += alignUp(sizeAndAlign.size, sizeAndAlign.align);
    }

    // Создаем кучу для картинок
    _imageHeap = [_device newHeapWithDescriptor:imageHeapDesc];
    
    // Копируем изображения в кучу
    for(int i = 0; i < kImageNamesCount; ++i) {
        if(![_imageTextures[i] finalize:_imageHeap]) {
            NSLog(@"Failed to copy image %@ into image heap", imageNames[i]);
        }
    }
    
    // Инициализация таймера
    _start = [NSDate date];
    _previousTime = [_start timeIntervalSinceNow];
    
    _displayTexture = nil;
}

// Настройка кучи для текстуры
- (void)setupHeap:(nonnull id <MTLTexture>)inTexture {
    // Вычисление размеров кучи
    MTLTextureDescriptor* descriptor = getDescFromTexture(inTexture);
    
    // Вычисляем размеры для кучи?
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

// Выполнение фильтрации
- (nonnull id <MTLTexture>)executeFilterGraph:(nonnull id <MTLTexture>)inTexture {
    // Создаем буффер комманд
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Выполняем фильтрацию
    id <MTLTexture> downsampledTexture = [_downsample executeWithCommandBuffer:commandBuffer
                                                                  inputTexture:inTexture
                                                                          heap:_heap
                                                                         fence:_fence];
    // Блюрим
    id <MTLTexture> blurredTexture = [_gaussianBlur executeWithCommandBuffer:commandBuffer
                                                                inputTexture:downsampledTexture
                                                                        heap:_heap
                                                                       fence:_fence];
    
    [commandBuffer commit];
    
    return blurredTexture;
}

- (void)reshape {
    float scaledWidth = (float)_displayTexture.width * _scale / (float)self.view.bounds.size.width;
    float scaledHeight = (float)_displayTexture.height * _scale / (float)self.view.bounds.size.height;
    float xTranslation = ((_screenPosition.x - (scaledWidth / 2.0)) * 2.0 - 1.0) / scaledWidth / 10.0;
    float yTranslation = ((_screenPosition.y - (scaledHeight / 2.0)) * 2.0 - 1.0) / scaledHeight / 10.0;
    
    _mvp = matrix_multiply(matrix_from_scale(scaledWidth, scaledHeight, 1.0), matrix_from_translation(xTranslation, yTranslation, 0.0));
}

// Вызывается при смене ориентации или выравнивания
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self reshape];
}

- (void)reposition {
    NSUInteger r = arc4random_uniform(75);
    _scale = (float)(r + 25) / 100.0f;
    _screenPosition.x = (float)arc4random_uniform(100) / 100.0;
    _screenPosition.y = (float)arc4random_uniform(100) / 100.0;
    [self reshape];
}

- (void)render {
    NSTimeInterval currentTime = [_start timeIntervalSinceNow];
    NSTimeInterval elapsedTime = _previousTime - currentTime;
    float blurryness = elapsedTime / kTimeoutSeconds;
    
    if(!_displayTexture || (elapsedTime >= kTimeoutSeconds)) {
        _previousTime = currentTime;
        
        // Освобождаем текущую текстуру из кучи
        [_displayTexture makeAliasable];
        _displayTexture = nil;
  
        // Выбираем рандомную текстуру
        NSUInteger r = arc4random_uniform(kImageNamesCount - 1);
        id<MTLTexture> inTexture = _imageTextures[r].texture;
        
        // Настраиваем кучу на текстуру
        [self setupHeap:inTexture];
        _displayTexture = [self executeFilterGraph:inTexture];
        
        [self reposition];
    }

    // Создаем новый коммандный буффер
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Получаем дескриптор отрисовки из вьюшки
    MTLRenderPassDescriptor* renderPassDescriptor = _view.currentRenderPassDescriptor;
    
    if(renderPassDescriptor != nil) {
        // Создание энкодера для отрисовки
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        // Ожидаем вычислительную часть до того, как мы будем рендерить, ожидание до фрагментного шейдера
        [renderEncoder waitForFence:_fence
                       beforeStages:MTLRenderStageFragment];
        
        // Устанавливаем настроку работу буффера глубины
        [renderEncoder setDepthStencilState:_depthState];
        
        // Установка состояния контекста
        [renderEncoder pushDebugGroup:@"DrawQuad"];
        [renderEncoder setRenderPipelineState:_pipelineState];
        // Установка вершинный буфферов с описанием вершин
        [renderEncoder setVertexBuffer:_planeMesh.vertexBuffers[0].buffer
                                offset:_planeMesh.vertexBuffers[0].offset
                               atIndex:0];
        
        // Юниформы вершинного шейдера
        [renderEncoder setVertexBytes:&_mvp
                               length:sizeof(_mvp)
                              atIndex:1];
        
        // Установка текстуры отрисовки
        [renderEncoder setFragmentTexture:_displayTexture
                                  atIndex:0];
        
        // Установка юниформов фрагментного шейдера
        float lod = blurryness * _displayTexture.mipmapLevelCount;
        [renderEncoder setFragmentBytes:&lod
                                 length:sizeof(float)
                                atIndex:0];
        
        MTKSubmesh* submesh = _planeMesh.submeshes[0];
        
        // Говорим рендеру отрисовать наши примитивы
        [renderEncoder drawIndexedPrimitives:submesh.primitiveType
                                  indexCount:submesh.indexCount
                                   indexType:submesh.indexType
                                 indexBuffer:submesh.indexBuffer.buffer
                           indexBufferOffset:submesh.indexBuffer.offset];
        
        // Отправляем сообщение синхронизации после фрагментного шейдера
        [renderEncoder updateFence:_fence
                       afterStages:MTLRenderStageFragment];
        
        // Закачиваем кодирование
        [renderEncoder endEncoding];
        
        // Ставим в очередь отображение буффера кадра
        [commandBuffer presentDrawable:_view.currentDrawable];
    }

    // Коммитим очередь
    [commandBuffer commit];
}

// Отрисовка
- (void)drawInMTKView:(nonnull MTKView *)view {
    @autoreleasepool {
        [self render];
    }
}

@end
