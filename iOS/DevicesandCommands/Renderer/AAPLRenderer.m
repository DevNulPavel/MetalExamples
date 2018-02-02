@import simd;
@import MetalKit;

#import "AAPLRenderer.h"

typedef struct {
    float red, green, blue, alpha;
} Color;

// Класс рендера
@implementation AAPLRenderer {
    id<MTLDevice> _device;              // Metal устройство
    id<MTLCommandQueue> _commandQueue;  // Очередь комманд
}

// Инициализация рендера с помощью вьюшки
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if(self) {
        _device = mtkView.device;
		_commandQueue = [_device newCommandQueue];
    }
    return self;
}

// Создание цвета
- (Color)makeFancyColor {
    static BOOL       growing = YES;
    static NSUInteger primaryChannel = 0;
    static float      colorChannels[] = {1.0, 0.0, 0.0, 1.0};

    const float DynamicColorRate = 0.015;

    if(growing){
        NSUInteger dynamicChannelIndex = (primaryChannel+1)%3;
        colorChannels[dynamicChannelIndex] += DynamicColorRate;
        if(colorChannels[dynamicChannelIndex] >= 1.0){
            growing = NO;
            primaryChannel = dynamicChannelIndex;
        }
    }else{
        NSUInteger dynamicChannelIndex = (primaryChannel+2)%3;
        colorChannels[dynamicChannelIndex] -= DynamicColorRate;
        if(colorChannels[dynamicChannelIndex] <= 0.0) {
            growing = YES;
        }
    }

    Color color;

    color.red   = colorChannels[0];
    color.green = colorChannels[1];
    color.blue  = colorChannels[2];
    color.alpha = colorChannels[3];

    return color;
}

#pragma mark - MTKViewDelegate methods

// Метод отрисовки
- (void)drawInMTKView:(nonnull MTKView *)view {
    Color color = [self makeFancyColor];
    view.clearColor = MTLClearColorMake(color.red, color.green, color.blue, color.alpha);

    // Создаем буффер комманд
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
	
    // Получаем дескриптор отрисовки из вьюшки
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    // Отрисовку можно производить только при наличии дескриптора отрисовки
    if(renderPassDescriptor != nil) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Здесь должна происходить отрисовка
        
        // После того, как добавили все для отрисовки данным энкодером - вызываем завершение буффера
        [renderEncoder endEncoding];

        // Вызов отображения предыдущего кадра??
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Рендеринг заканчивается здесь и задачи отправляются на GPU
    [commandBuffer commit];
}

// Вызывается при ресайзе (смене ориентации устройства)
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
}

@end
