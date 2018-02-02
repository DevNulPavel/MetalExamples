@import simd;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLImage.h"

// Общий хедер для рендера и шейдеров
#import "AAPLShaderTypes.h"

// Класс рендеринга
@implementation AAPLRenderer {
    // Устройство
    id<MTLDevice> _device;

    // Вычислительный пайплайн
    id<MTLComputePipelineState> _computePipelineState;

    // Пайплайн отрисовки
    id<MTLRenderPipelineState> _renderPipelineState;

    // Буффер комманд
    id<MTLCommandQueue> _commandQueue;

    // Входная текстура
    id<MTLTexture> _inputTexture;

    // Выходная текстура
    id<MTLTexture> _outputTexture;

    // Размер вьюпорта
    vector_uint2 _viewportSize;

    // Параметры компьютерного ядра вычисления
    MTLSize _threadgroupSize;
    MTLSize _threadgroupCount;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if(self) {
        NSError *error = NULL;

        _device = mtkView.device;

        // Настройка цвета пикселей
        mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;

        // Библиотека
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Получаем вычислительный шейдер
        id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"grayscaleKernel"];

        // Создаем вычислительный пайплайн стейт
        _computePipelineState = [_device newComputePipelineStateWithFunction:kernelFunction
                                                                       error:&error];

        if(!_computePipelineState) {
            // Compute pipeline State creation could fail if kernelFunction failed to load from the
            //   library.  If the Metal API validation is enabled, we automatically be given more
            //   information about what went wrong.  (Metal API validation is enabled by default
            //   when a debug build is run from Xcode)
            NSLog(@"Failed to create compute pipeline state, error %@", error);
            return nil;
        }

        // Вершинный шейдер
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Фрагментный шейдер
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

        // Дескриптор пайплайна рендеринга
        MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_renderPipelineState){
            NSLog(@"Failed to create render pipeline state, error %@", error);
        }

        // Создание картинки
        NSURL* imageFileLocation = [[NSBundle mainBundle] URLForResource:@"Image"
                                                           withExtension:@"tga"];

        AAPLImage* image = [[AAPLImage alloc] initWithTGAFileAtLocation:imageFileLocation];

        if(!image){
            return nil;
        }
        
        // Создание дескриптора текстуры
        MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];

        // Описание типа текстуры
        textureDescriptor.textureType = MTLTextureType2D;

        // Описание формата текстуры
        textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
        textureDescriptor.width = image.width;
        textureDescriptor.height = image.height;
        
        // Входная текстура используется только для чтения в шейдере
        textureDescriptor.usage = MTLTextureUsageShaderRead;

        // Непосредственно создание входной текстуры на основании дескриптора
        _inputTexture = [_device newTextureWithDescriptor:textureDescriptor];
        
        // Выходная текстура используется для записи из шейдера и для чтения
        textureDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;

        // Создание выходной текстуры
        _outputTexture = [_device newTextureWithDescriptor:textureDescriptor];
        
        // Регион текстур
        MTLRegion region = {{ 0, 0, 0 }, {textureDescriptor.width, textureDescriptor.height, 1}};

        // Сколько байт идет на строку
        NSUInteger bytesPerRow = 4 * textureDescriptor.width;

        // Загружает данные во входную текстуру
        [_inputTexture replaceRegion:region
                         mipmapLevel:0
                           withBytes:image.data.bytes
                         bytesPerRow:bytesPerRow];

        if(!_inputTexture || error) {
            NSLog(@"Error creating texture %@", error.localizedDescription);
            return nil;
        }

        // Размер тредгруппы
        _threadgroupSize = MTLSizeMake(16, 16, 1);

        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        
        // Вычисляем количество строк и столбцов тредгрупп
        _threadgroupCount.width  = (_inputTexture.width  + _threadgroupSize.width -  1) / _threadgroupSize.width;
        _threadgroupCount.height = (_inputTexture.height + _threadgroupSize.height - 1) / _threadgroupSize.height;

        // Работа идет с 2D данными - так что глубина у нас нулевая
        _threadgroupCount.depth = 1;

        // Создание очереди комманд
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

// Вызывается при смене ориентации
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

// Вызывается для рендеринга сцены
- (void)drawInMTKView:(nonnull MTKView *)view {
    static const AAPLVertex quadVertices[] =
    {
        // Позиции и текстурные координаты
        { {  250,  -250 }, { 1.f, 0.f } },
        { { -250,  -250 }, { 0.f, 0.f } },
        { { -250,   250 }, { 0.f, 1.f } },

        { {  250,  -250 }, { 1.f, 0.f } },
        { { -250,   250 }, { 0.f, 1.f } },
        { {  250,   250 }, { 1.f, 1.f } },
    };

    // Создаем буффер комманд
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Создаем энкодер комманд вычисления
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

    // Выставляем пайплайн
    [computeEncoder setComputePipelineState:_computePipelineState];

    // Выставляем входную текстуру по индексу 0
    [computeEncoder setTexture:_inputTexture
                       atIndex:AAPLTextureIndexInput];
    
    // Выставляем выходную текстуру по индексу 1
    [computeEncoder setTexture:_outputTexture
                       atIndex:AAPLTextureIndexOutput];
    
    // Выставляем количество тредгрупп + количество потоков на группу
    [computeEncoder dispatchThreadgroups:_threadgroupCount
                   threadsPerThreadgroup:_threadgroupSize];
    
    // Завершаем конвертацию
    [computeEncoder endEncoding];

    
    // Получаем дескриптор рендеринга
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil){
        // Создаем энкодер для рендеринга
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Выставляем вьюпорт
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];
        
        // Выставляем пайплайн отрисовки
        [renderEncoder setRenderPipelineState:_renderPipelineState];

        // We call -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:] tp send data from our
        //   Application ObjC code here to our Metal 'vertexShader' function
        // This call has 3 arguments
        //   1) A pointer to the memory we want to pass to our shader
        //   2) The memory size of the data we want passed down
        //   3) An integer index which corresponds to the index of the buffer attribute qualifier
        //      of the argument in our 'vertexShader' function

        // Here we're sending a pointer to our 'triangleVertices' array (and indicating its size).
        //   The AAPLVertexInputIndexVertices enum value corresponds to the 'vertexArray' argument
        //   in our 'vertexShader' function because its buffer attribute qualifier also uses
        //   AAPLVertexInputIndexVertices for its index
        
        // Вытавляем вершинный буффер по индексу 0, описание вершин
        [renderEncoder setVertexBytes:quadVertices
                               length:sizeof(quadVertices)
                              atIndex:AAPLVertexInputIndexVertices];

        // Here we're sending a pointer to '_viewportSize' and also indicate its size so the whole
        //   think is passed into the shader.  The AAPLVertexInputIndexViewportSize enum value
        ///  corresponds to the 'viewportSizePointer' argument in our 'vertexShader' function
        //   because its buffer attribute qualifier also uses AAPLVertexInputIndexViewportSize
        //   for its index
        
        // Вытавляем вершинный буффер по индексу 1, юниформ размера вьюпорта
        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];
        
        // Выставляем текстуру для отрисовки
        [renderEncoder setFragmentTexture:_outputTexture
                                  atIndex:AAPLTextureIndexOutput];

        // Вызываем отрисовку
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

@end

