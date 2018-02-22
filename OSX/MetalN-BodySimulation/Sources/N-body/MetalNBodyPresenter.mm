/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for rendering (encoding into Metal pipeline components of) N-Body simulation and presenting the frame
 */

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"

#import "MetalNBodyComputeStage.h"
#import "MetalNBodyRenderStage.h"
#import "MetalNBodyPresenter.h"

@implementation MetalNBodyPresenter {
@private
    BOOL _haveEncoder;
    BOOL _isEncoded;
    
    NSDictionary* _globals;
    NSDictionary* _activeParameters;
    
    id<MTLLibrary>        _library;
    id<MTLCommandBuffer>  _commandBuffer;
    id<MTLCommandQueue>   _commandQueue;
    
    MetalNBodyRenderStage*   _renderStage;
    MetalNBodyComputeStage*  _computeStage;
}

- (instancetype) init {
    self = [super init];
    
    if(self){
        _haveEncoder = NO;
        _isEncoded   = NO;
        
        _globals    = nil;
        _activeParameters = nil;
        
        _commandBuffer = nil;
        _commandQueue  = nil;
        _library   = nil;
        
        _renderStage  = nil;
        _computeStage = nil;
    }
    
    return self;
}

// Установка глобальных параметров симуляции
- (void)setGlobals:(NSDictionary *)globals {
    _globals = globals;
    
    if(_renderStage) {
        _renderStage.globals = _globals;
    }
}

// N-body parameters for simulation types
- (void)setActiveParameters:(NSDictionary *)parameters {
    _activeParameters = parameters;
    
    if(_renderStage) {
        _renderStage.parameters = _activeParameters;
    }
}

// Установка соотношения сторон
- (void)setAspect:(float)aspect {
    if(_renderStage){
        _renderStage.aspect = aspect;
    }
}

// Установка типа ортографической проекции
- (void)setConfig:(uint32_t)config {
    if(_renderStage) {
        _renderStage.config = config;
    }
}

// Обновление трансформации матрицы модели-вида-проекции
- (void)setUpdate:(BOOL)update {
    if(_renderStage){
        _renderStage.update = update;
    }
}

// Указатель на данные цветов
- (nullable simd::float4 *)getColorsPointer{
    simd::float4* pColors = nullptr;
    
    if(_renderStage) {
        pColors = _renderStage.colors;
    }

    return pColors;
}

// Указатель на данные позиций
- (nullable simd::float4*)getPositionsPointer {
    simd::float4* pPosition = nullptr;
    
    if(_computeStage){
        pPosition = _computeStage.position;
    }
    
    return pPosition;
}

// Указатель на данные ускорений
- (nullable simd::float4 *)getVelocityPointer{
    simd::float4* pVelocity = nullptr;
    
    if(_computeStage){
        pVelocity = _computeStage.velocity;
    }
    
    return pVelocity;
}

- (BOOL)acquire:(nullable id<MTLDevice>)device {
    if(device) {
        // Получаем указатель на библиотеку
        _library = [device newDefaultLibrary];
        
        if(!_library){
            NSLog(@">> ERROR: Failed to instantiate a new default m_Library!");
            return NO;
        }
        
        // Получаем очередь комманд
        _commandQueue = [device newCommandQueue];
        if(!_commandQueue){
            NSLog(@">> ERROR: Failed to instantiate a new command queue!");
            return NO;
        }
        
        // Создаем вычислительный стейдж
        _computeStage = [MetalNBodyComputeStage new];
        if(!_computeStage){
            NSLog(@">> ERROR: Failed to instantiate a N-Body compute object!");
            return NO;
        }
        
        // Обновляем параметры в вычислительном стейдже
        _computeStage.globals = _globals;
        _computeStage.library = _library;
        _computeStage.device  = device;
        
        // Инициализированная ли вычислительная стадия?
        if(!_computeStage.isStaged){
            NSLog(@">> ERROR: Failed to acquire a N-Body compute resources!");
            return NO;
        }

        // Создаем стейдж рендеринга
        _renderStage = [MetalNBodyRenderStage new];
        if(!_renderStage) {
            NSLog(@">> ERROR: Failed to instantiate a N-Body render stage object!");
            return NO;
        }
        
        // Обновляем параметры в стейдже рендеринга
        _renderStage.globals = _globals;
        _renderStage.library = _library;
        _renderStage.device  = device;

        // Инициализированная ли рендер стадия?
        if(!_renderStage.isStaged){
            NSLog(@">> ERROR: Failed to acquire a N-Body render stage resources!");
            return NO;
        }
        
        return YES;
    }else{
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}


// Генерация  необходимых ресурсов для симуляции
- (void)initWithDevice:(nullable id<MTLDevice>)device {
    if(!_haveEncoder){
        _haveEncoder = [self acquire:device];
    }
}

// Выполняем энкодинг для drawable объекта
- (void)encodeForDrawable:(nonnull id<CAMetalDrawable> (^)(void))drawableBlock {
    _isEncoded = NO;
    
    // Создаем новый command buffer
    _commandBuffer = [_commandQueue commandBuffer];
    if(!_commandBuffer){
        NSLog(@">> ERROR: Failed to acquire a command buffer!");
        _isEncoded = NO;
        return;
    }
    
    // Обновляем параметры вычислительной стадии и выполняем задачи по вычислению на GPU
    _computeStage.parameters = _activeParameters;
    _computeStage.cmdBuffer  = _commandBuffer;
    
    // TODO: Надо получать drawable как можно ближе к present, чтобы не было ворнинга
    id<CAMetalDrawable> drawable = drawableBlock();
    if(drawable){
        // Обновляем данные для рендеринга, вызываем рендеринг
        _renderStage.positions = _computeStage.buffer;
        _renderStage.cmdBuffer = _commandBuffer;
        _renderStage.drawable  = drawable;
        
        // Отображаем и коммитим
        [_commandBuffer presentDrawable:drawable];
        [_commandBuffer commit];
        
        // Вызываем цикличную смену вычислительных буфферов
        [_computeStage swapBuffers];
    }
    
    _isEncoded = YES;
}

// Ждем пока рендер-энкодер завершит свою работу
- (void) finish {
    if(_commandBuffer){
        [_commandBuffer waitUntilCompleted];
    }
}

@end
