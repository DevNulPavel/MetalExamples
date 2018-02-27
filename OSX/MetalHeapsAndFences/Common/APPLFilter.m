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
    // Создаем дескриптор текстуры
    _textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:inDescriptor.pixelFormat
                                                                            width:inDescriptor.width
                                                                           height:inDescriptor.height
                                                                        mipmapped:YES];

    // Ресурсы в куче должны иметь один и тот же режима расшаривания
    _textureDescriptor.storageMode = MTLStorageModePrivate;
    _textureDescriptor.usage |= MTLTextureUsageShaderWrite;
    
    return [_device heapTextureSizeAndAlignWithDescriptor:_textureDescriptor];
}


- (_Nullable id <MTLTexture>) executeWithCommandBuffer:(_Nonnull id <MTLCommandBuffer>)commandBuffer
                                          inputTexture:(_Nonnull id <MTLTexture>)inTexture
                                                  heap:(_Nonnull id <MTLHeap>)heap
                                                 fence:(_Nonnull id <MTLFence>)fence {
    
    // Создаем выходную текстуру
    id <MTLTexture> outTexture = [heap newTextureWithDescriptor:_textureDescriptor];
    assert(outTexture && "Failed to allocate on heap, did not request enough resources");
    
    // Создаем энкодер комманд
    id <MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    if(blitCommandEncoder) {
        // Ожидаем возможности исполнить копировать текстуру
        [blitCommandEncoder waitForFence:fence];
        
        // Закидываем в очередь операцию по копированию текстуры
        [blitCommandEncoder copyFromTexture:inTexture
                                sourceSlice:0
                                sourceLevel:0
                               sourceOrigin:(MTLOrigin){ 0, 0, 0 }
                                 sourceSize:(MTLSize){ inTexture.width, inTexture.height, inTexture.depth }
                                  toTexture:outTexture
                           destinationSlice:0
                           destinationLevel:0
                          destinationOrigin:(MTLOrigin){ 0, 0, 0}];
        
        // Выполняем операцию генерации мипмапы
        [blitCommandEncoder generateMipmapsForTexture:outTexture];
        
        // Отправляем сообщение о возможности следующего шага
        [blitCommandEncoder updateFence:fence];
        
        // Заканчиваем кодирование
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
    AAPLSeparablePassSize = 2
};

- (instancetype) initWithDevice:(nonnull id <MTLDevice>)device {
    NSError* error = nil;
    
    self = [super init];

    // Создание библиотеки
    _library = [device newDefaultLibrary];
    if(!_library) {
        NSLog(@"Failed creating a new library: %@", error);
    }
    
    // Создаем вычислительное ядро гауса для горизонтальной обработки
    id <MTLFunction> function = [_library newFunctionWithName:@"gaussianblurHorizontal"];
    if(!function) {
        NSLog(@"Failed creating a new function");
    }
    
    // Создаем горизонтальную функцию
    _horizontalKernel = [device newComputePipelineStateWithFunction:function
                                                              error:&error];
    if(!_horizontalKernel) {
        NSLog(@"Failed creating a compute kernel: %@", error);
    }
    
    // Получаем вычислительное ядро вертикальной обработки
    function = [_library newFunctionWithName:@"gaussianblurVertical"];
    if(!function) {
        NSLog(@"Failed creating a new function");
    }
    
    // Создаем вертикальную функцию
    _verticalKernel = [device newComputePipelineStateWithFunction:function
                                                            error:&error];
    if(!_verticalKernel) {
        NSLog(@"Failed creating a compute kernel: %@", error);
    }
    
    _device = device;
    
    return self;
}

- (MTLSizeAndAlign) heapSizeAndAlignWithInputTextureDescriptor:(nonnull MTLTextureDescriptor *)inDescriptor {
    // Создаем дескриптор текстуры меньшего в 2 раза размер
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:(inDescriptor.width >> 1)
                                                                                   height:(inDescriptor.height >> 1)
                                                                                mipmapped:NO];
    // Используем для записи шейдера
    textureDescriptor.usage |= MTLTextureUsageShaderWrite;
    return [_device heapTextureSizeAndAlignWithDescriptor:textureDescriptor];
}

- (_Nullable id <MTLTexture>) executeWithCommandBuffer:(_Nonnull id <MTLCommandBuffer>)commandBuffer
                                          inputTexture:(_Nonnull id <MTLTexture>)inTexture
                                                  heap:(_Nonnull id <MTLHeap>)heap
                                                 fence:(_Nonnull id <MTLFence>)fence {
    // Выполняем блюр для каждого мипмап левела начиная с первого
    for(uint32_t mipmapLevel = 1; mipmapLevel < inTexture.mipmapLevelCount; ++mipmapLevel) {
        // Создаем описание текстуры
        MTLTextureDescriptor*textureDescriptior = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                     width:(inTexture.width >> mipmapLevel)
                                                                                                    height:(inTexture.height >> mipmapLevel)
                                                                                                 mipmapped:NO];
        
        // Ресурсы в куче должны иметь такой же режим хранения, как у кучи
        textureDescriptior.storageMode = MTLStorageModePrivate;
        
        // Использование
        textureDescriptior.usage |= MTLTextureUsageShaderWrite;
        
        // Корректируем размеры
        if(textureDescriptior.width <= 0) {
            textureDescriptior.width = 1;
        }
        if(textureDescriptior.height <= 0) {
            textureDescriptior.height = 1;
        }
        
        // Создаем текстуру в куче
        id<MTLTexture> horizontalTexture = [heap newTextureWithDescriptor:textureDescriptior];
        assert(horizontalTexture && "Failed to allocate on heap, did not request enough resources");
        
        // Выставляем размер тредгрупп 16x16x1
        MTLSize threadgroupSize = MTLSizeMake(kThreadgroupWidth, kThreadgroupHeight, kThreadgroupDepth);
        
        // Вычисляем количество групп потоков по горизонтали и по вертикали
        NSUInteger nThreadCountW = (horizontalTexture.width  + threadgroupSize.width -  1) / threadgroupSize.width;
        NSUInteger nThreadCountH = (horizontalTexture.height + threadgroupSize.height - 1) / threadgroupSize.height;
        
        // Переменная с количестом групп потоков
        MTLSize threadgroupCount = MTLSizeMake(nThreadCountW, nThreadCountH, 1);
        
        // Массив вычислительных ядер
        id<MTLComputePipelineState> kernel[AAPLSeparablePassSize] = { _horizontalKernel, _verticalKernel };
        // Массив входных текстур
        id<MTLTexture> inTextures[AAPLSeparablePassSize] = { inTexture, horizontalTexture };
        // Массив выходных текстур
        id<MTLTexture> outTextures[AAPLSeparablePassSize] = { horizontalTexture, inTexture };
        
        uint32_t mipmapLevelZero = 0;
        
        // Делаем сначала горизонтальный, потом вертикальный проход
        for(AAPLSeparablePass pass = AAPLSeparablePassHorizontal; pass < AAPLSeparablePassSize; ++pass) {
            // Энкодер создаем
            id <MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
            
            if(computeEncoder) {
                // Ждем барьер
                [computeEncoder waitForFence:fence];
                
                // Устанавливаем пайплайн стейт вычисления
                [computeEncoder setComputePipelineState:kernel[pass]];
                
                // Устанавливаем текстуру входную
                [computeEncoder setTexture:inTextures[pass]
                                   atIndex:0];
                
                // Устанавливаем выходную текстуру
                [computeEncoder setTexture:outTextures[pass]
                                   atIndex:1];
                
                // Устанавливаем уровень мипмаппинга 1
                [computeEncoder setBytes:(pass == AAPLSeparablePassHorizontal) ? &mipmapLevel : &mipmapLevelZero
                                  length:sizeof(mipmapLevel)
                                 atIndex:0];
                
                // Устанавливаем уровень миплмаппинга 2
                [computeEncoder setBytes:(pass == AAPLSeparablePassHorizontal) ? &mipmapLevelZero : &mipmapLevel
                                  length:sizeof(mipmapLevel)
                                 atIndex:1];
                
                // Ставим исполнение в очередь
                [computeEncoder dispatchThreadgroups:threadgroupCount
                               threadsPerThreadgroup:threadgroupSize];
                
                // Разрешаем дальнейшее исполнение
                [computeEncoder updateFence:fence];
                
                [computeEncoder endEncoding];
            }
        }
        
        /**
         We can now make our horizontal texture aliasable and use that space for 
         the next mip level.
         */
        // Можно сделать нашу горизонтальную текстуру
        [horizontalTexture makeAliasable];
    }
    
    return inTexture;
}

@end
