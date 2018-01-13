@import MetalKit;

#import "AAPLRenderer.h"

// Константы и общие типы данных для шейдера
#import "AAPLShaderTypes.h"

// Максимальное количество буфферов в обработке
static const NSUInteger MaxBuffersInFlight = 3;


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Простой класс, представляющий из себя объект спрайта
@interface AAPLSprite : NSObject
@property (nonatomic) vector_float2 position;
@property (nonatomic) vector_float4 color;
+(const AAPLVertex*)vertices;
+(NSUInteger)vertexCount;
@end


@implementation AAPLSprite

// Метод, возвращающий вершины квадрата спрайта
+(const AAPLVertex *)vertices {
    const float SpriteSize = 5;
    static const AAPLVertex spriteVertices[] =
    {
        //Pixel Positions,                 RGBA colors
        { { -SpriteSize,   SpriteSize },   { 0, 0, 0, 1 } },
        { {  SpriteSize,   SpriteSize },   { 0, 0, 0, 1 } },
        { { -SpriteSize,  -SpriteSize },   { 0, 0, 0, 1 } },

        { {  SpriteSize,  -SpriteSize },   { 0, 0, 0, 1 } },
        { { -SpriteSize,  -SpriteSize },   { 0, 0, 0, 1 } },
        { {  SpriteSize,   SpriteSize },   { 0, 0, 1, 1 } },
    };

    return spriteVertices;
}

// The number of vertices for each sprite
+(NSUInteger)vertexCount{
    return 6;
}
@end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


@implementation AAPLRenderer {
    dispatch_semaphore_t _inFlightSemaphore;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;

    id<MTLRenderPipelineState> _pipelineState1;
    id<MTLRenderPipelineState> _pipelineState2;
    id<MTLBuffer> _vertexBuffers[MaxBuffersInFlight];

    // Размер вьюпорта
    vector_uint2 _viewportSize;

    // Индекс текущего активного буффера
    NSUInteger _currentBuffer;

    // Массив спрайтов
    NSArray<AAPLSprite*>* _sprites;

    NSUInteger _spritesPerRow;
    NSUInteger _spritesPerColumn;
    NSUInteger _totalSpriteVertexCount;
}

// Создание рендера на основании вьюшки
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if(self) {
        _device = mtkView.device;

        // Создание самафора
        _inFlightSemaphore = dispatch_semaphore_create(MaxBuffersInFlight);
        
        // Создание библиотеки
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Вершинный шейдер
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Фрагментный шейдер
        id<MTLFunction> fragmentFunction1 = [defaultLibrary newFunctionWithName:@"fragmentShader1"];
        id<MTLFunction> fragmentFunction2 = [defaultLibrary newFunctionWithName:@"fragmentShader2"];

        // Создаем базовое описание пайплайна
        MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"MyPipeline";
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount;
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat;

        NSError* error = NULL;
        // Создаем пайплайн стейт 1
        pipelineStateDescriptor.fragmentFunction = fragmentFunction1;
        _pipelineState1 = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if (!_pipelineState1){
            NSLog(@"Failed to created pipeline state, error %@", error);
        }
        
        // Создаем пайплайн стейт 2
        pipelineStateDescriptor.fragmentFunction = fragmentFunction2;
        _pipelineState2 = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if (!_pipelineState2){
            NSLog(@"Failed to created pipeline state, error %@", error);
        }

        // Создание очереди комманд
        _commandQueue = [_device newCommandQueue];

        // Создаем спрайты
        [self generateSprites];

        // Количество вершин для всех спрайтов
        _totalSpriteVertexCount = AAPLSprite.vertexCount * _sprites.count;

        // размер буффера вершин для спрайта
        NSUInteger spriteVertexBufferSize = _totalSpriteVertexCount * sizeof(AAPLVertex);

        // Создание буфферов данных вершин для каждого кадра
        for(NSUInteger bufferIndex = 0; bufferIndex < MaxBuffersInFlight; bufferIndex++) {
            _vertexBuffers[bufferIndex] = [_device newBufferWithLength:spriteVertexBufferSize
                                                               options:MTLResourceStorageModeShared];
        }
    }

    return self;
}

// Создание спрайтов
- (void) generateSprites {
    const float XSpacing = 12;
    const float YSpacing = 16;

    const NSUInteger SpritesPerRow = 110;
    const NSUInteger RowsOfSprites = 50;
    const float WaveMagnitude = 30.0;

    const vector_float4 Colors[] =
    {
        { 1.0, 0.0, 0.0, 0.8 },  // Red
        { 0.0, 1.0, 1.0, 0.8 },  // Cyan
        { 0.0, 1.0, 0.0, 0.8 },  // Green
        { 1.0, 0.5, 0.0, 0.8 },  // Orange
        { 1.0, 0.0, 1.0, 0.8 },  // Magenta
        { 0.0, 0.0, 1.0, 0.8 },  // Blue
        { 1.0, 1.0, 0.0, 0.8 },  // Yellow
        { .75, 0.5, .25, 0.8 },  // Brown
        { 1.0, 1.0, 1.0, 0.8 },  // White

    };

    const NSUInteger NumColors = sizeof(Colors) / sizeof(vector_float4);

    _spritesPerRow = SpritesPerRow;
    _spritesPerColumn = RowsOfSprites;

    NSMutableArray *sprites = [[NSMutableArray alloc] initWithCapacity:_spritesPerColumn * _spritesPerRow];

    // Create a grid of 'sprite' objects
    for(NSUInteger row = 0; row < _spritesPerColumn; row++)
    {
        for(NSUInteger column = 0; column < _spritesPerRow; column++)
        {
            vector_float2 spritePosition;

            // Determine the position of our sprite in the grid
            spritePosition.x = ((-((float)_spritesPerRow) / 2.0) + column) * XSpacing;
            spritePosition.y = ((-((float)_spritesPerColumn) / 2.0) + row) * YSpacing + WaveMagnitude;

            // Displace the height of this sprite using a sin wave
            spritePosition.y += (sin(spritePosition.x/WaveMagnitude) * WaveMagnitude);

            // Create our sprite, set its properties and add it to our list
            AAPLSprite * sprite = [AAPLSprite new];

            sprite.position = spritePosition;
            sprite.color = Colors[row%NumColors];

            [sprites addObject:sprite];
        }
    }
    _sprites = sprites;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

// Обновляем позицию каждого спрайта в очередном буффере на отрисовку
- (void)updateState {
    // Получаем указатель на данные текущего буффера
    AAPLVertex* currentSpriteVertices = _vertexBuffers[_currentBuffer].contents;
    
    NSUInteger  currentVertex = _totalSpriteVertexCount-1;
    NSUInteger  spriteIdx = (_spritesPerColumn * _spritesPerRow)-1;
    
    for(NSInteger row = _spritesPerColumn - 1; row >= 0; row--) {
        float startY = _sprites[spriteIdx].position.y;
        for(NSInteger spriteInRow = _spritesPerRow-1; spriteInRow >= 0; spriteInRow--) {
            // Update the position of our sprite
            vector_float2 updatedPosition = _sprites[spriteIdx].position;
            
            if(spriteInRow == 0) {
                updatedPosition.y = startY;
            }else{
                updatedPosition.y = _sprites[spriteIdx-1].position.y;
            }
            
            _sprites[spriteIdx].position = updatedPosition;
            
            // Обновляем вершины в текущем буффере вершин с новыми позициями спрайтов
            for(NSInteger vertexOfSprite = AAPLSprite.vertexCount-1; vertexOfSprite >= 0 ; vertexOfSprite--){
                currentSpriteVertices[currentVertex].position = AAPLSprite.vertices[vertexOfSprite].position + _sprites[spriteIdx].position;
                currentSpriteVertices[currentVertex].color = _sprites[spriteIdx].color;
                currentVertex--;
            }
            spriteIdx--;
        }
    }
}

// Вызывается для рендеринга
- (void)drawInMTKView:(nonnull MTKView *)view {
    // Ждем, чтобы не превысилось количество кадров на GPU
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    // Увеличиваем индекс буффера, который будет обновляться
    _currentBuffer = (_currentBuffer + 1) % MaxBuffersInFlight;

    // Обновляем буффер
    [self updateState];

    // Создаем новый буффер комманд для отрисовки
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Add completion hander which signals _inFlightSemaphore when Metal and the GPU has fully
    //   finished processing the commands we're encoding this frame.  This indicates when the
    //   dynamic buffers filled with our vertices, that we're writing to this frame, will no longer
    //   be needed by Metal and the GPU, meaning we can overwrite the buffer contents without
    //   corrupting the rendering.
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer){
        dispatch_semaphore_signal(block_sema);
    }];

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil){
        // Создаем энкодер
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Выставляем состояние энкодера
        [renderEncoder setCullMode:MTLCullModeBack];

        // Выставляем буффер вершин
        [renderEncoder setVertexBuffer:_vertexBuffers[_currentBuffer]
                               offset:0
                              atIndex:AAPLVertexInputIndexVertices];

        // Выставляем пайплайн 1
        [renderEncoder setRenderPipelineState:_pipelineState1];
        
        // Выставляем данные для юниформов
        vector_uint2 viewportSize1;
        viewportSize1.x = _viewportSize.x*0.5;
        viewportSize1.y = _viewportSize.y*0.5;
        [renderEncoder setVertexBytes:&viewportSize1
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];
        
        // Вызываем отрисовку
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_totalSpriteVertexCount];
        
        // Выставляем пайплайн 2
        [renderEncoder setRenderPipelineState:_pipelineState2];
        
        // Выставляем данные для юниформов
        vector_uint2 viewportSize2;
        viewportSize2.x = _viewportSize.x*0.7;
        viewportSize2.y = _viewportSize.y*0.7;
        [renderEncoder setVertexBytes:&viewportSize2
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];
        
        // Вызываем отрисовку
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_totalSpriteVertexCount];

        // Заканчиваем кодирование комманд
        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        // Ставим в очередь отрисовку на экран уже готового буффера цвета из предыдущих кадров
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Заканчиваем рендеринг и отправляем коммандный буффер на GPU
    [commandBuffer commit];
}

@end
