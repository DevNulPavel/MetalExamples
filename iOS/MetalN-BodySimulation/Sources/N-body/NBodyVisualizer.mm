/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 N-body controller object for visualizing the simulation.
 */

#import <QuartzCore/CAMetalLayer.h>

#import "CMNumerics.h"

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"
#import "NBodyProperties.h"
#import "NBodyURDGenerator.h"
#import "MetalNBodyPresenter.h"

#import "NBodyVisualizer.h"

@implementation NBodyVisualizer {
@private
    BOOL  _haveVisualizer;
    BOOL  _isComplete;

    float _aspect;

    uint32_t _particles;
    uint32_t _frames;
    uint32_t _texRes;
    uint32_t _config;
    uint32_t _active;
    uint32_t _frame;
    
    uint32_t mnCount;
    
    NBodyProperties*     mpProperties;
    NBodyURDGenerator*   mpGenerator;
    MetalNBodyPresenter* mpPresenter;
}

- (instancetype) init {
    self = [super init];
    
    if(self){
        _haveVisualizer = NO;
        _isComplete     = NO;
        
        _aspect    = NBody::Defaults::kAspectRatio;
        _frames    = NBody::Defaults::kFrames;
        _config    = NBody::Defaults::Configs::eShell;
        _texRes    = NBody::Defaults::kTexRes;
        _particles = NBody::Defaults::kParticles;
        
        _active = 0;
        _frame  = 0;
        
        mpProperties = nil;
        mpGenerator  = nil;
        mpPresenter  = nil;
    }
    
    return self;
}

// Coordinate points on the Eunclidean axis of simulation
- (void) setAxis:(simd::float3)axis{
    if(mpGenerator){
        mpGenerator.axis = axis;
    }
}

// Aspect ratio
- (void) setAspect:(float)aspect {
    float nEPS = NBody::Defaults::kTolerance;
    
    _aspect = CM::isLT(nEPS, aspect) ? aspect : 1.0f;
}

// Количество партиклов
- (void) setParticles:(uint32_t)particles {
    if(!_haveVisualizer){
        mpProperties.totalParticlesCount = _particles = (particles) ? particles : NBody::Defaults::kParticles;
    }
}

// Разрешение текстуры - по-умолчанию 64x64.
- (void) setTexRes:(uint32_t)texRes {
    if(!_haveVisualizer){
        mpProperties.texRes = _texRes = (texRes > 64) ? texRes :  NBody::Defaults::kTexRes;
    }
}

// Количество кадров, которое нужно отрендерить
- (void) setFrames:(uint32_t)frames {
    _frames = (frames) ? frames : NBody::Defaults::kFrames;
}

- (BOOL) _acquire:(nullable id<MTLDevice>)device {
    if(device){
        // Создаем объект свойств
        mpProperties = [NBodyProperties new];
        
        if(!mpProperties){
            NSLog(@">> ERROR: Failed to instantiate N-body properties object!");
            return NO;
        }
        
        // Количество симуляций
        mnCount = mpProperties.simulationsTotalCount;
        if(!mnCount){
            NSLog(@">> ERROR: Empty array for N-Body properties!");
            return NO;
        }
        
        // Создаем генерато для инициализации данных
        mpGenerator = [NBodyURDGenerator new];
        if(!mpGenerator){
            NSLog(@">> ERROR: Failed to instantiate uniform random distribution object!");
            return NO;
        }
        
        // Создаем рендер для нашего пространства
        mpPresenter = [MetalNBodyPresenter new];
        if(!mpPresenter){
            NSLog(@">> ERROR: Failed to instantiate Metal render encoder object!");
            return NO;
        }
        
        [mpPresenter setGlobals:[mpProperties getGlobals]];
        [mpPresenter initWithDevice:device];
        
        // Проверяем наличие энкодера у рендера
        if(!mpPresenter.haveEncoder){
            NSLog(@">> ERROR: Failed to acquire resources for the render encoder object!");
            return NO;
        }
        
        return YES;
    }
    
    return NO;
}

- (void) _update {
    // Выбираем новую демку симуляции
    NSLog(@">> MESSAGE[N-Body]: Demo [%u] selected!", _active);
    
    // Обновляем матрицу линейной трансформации
    [mpPresenter setUpdate:YES];
    
    // Выставляем словарь настроек симуляции
    mpProperties.activeSimulationConfigIndex = _active;
    
    // Генерируем начальные данные для симуляции
    mpGenerator.parameters = [mpProperties getActiveSimulationParameters];
    mpGenerator.colors     = [mpPresenter getColorsPointer];
    mpGenerator.position   = [mpPresenter getPositionsPointer];
    mpGenerator.velocity   = [mpPresenter getVelocityPointer];
    [mpGenerator setConfigId:_config];
}

// Создание всех необходимых ресурсов для симуляции
- (void) acquire:(nullable id<MTLDevice>)device {
    if(!_haveVisualizer){
        // Создаем визуализатор
        _haveVisualizer = [self _acquire:device];
        
        // обновляем параметры визуализации
        if(_haveVisualizer){
            [self _update];
        }
    }
}

// Рендерим новый кадр
- (void)renderFrame:(nonnull id<CAMetalDrawable> (^)(void))drawableBlock{
    [mpPresenter setAspect:_aspect];                 // Обновляем соотношение сторон
    [mpPresenter setActiveParameters:[mpProperties getActiveSimulationParameters]]; // Обновляем параметры симуляции
    [mpPresenter encodeForDrawable:drawableBlock];                // Обновляем рисуемый объект и вызываем отрисовку
}

// Переход на новый кадр
- (void)nextFrame {
    _frame++;

    // Как только достигаем максимума кадров данной симуляции - переходим к следующей симуляции
    _isComplete = (_frame % _frames) == 0;
    if(_isComplete){
        // Завершаем работу
        [mpPresenter finish];
        
        // Выбираем новую симуляцию
        _active = (_active + 1) % mnCount;
        
        // обновляем настройки симуляции
        [self _update];
    }
}

// Рендеринг кадра симуляции
- (void) render:(nonnull id<CAMetalDrawable> (^)(void))drawableBlock {
    [self renderFrame:drawableBlock];
    [self nextFrame];
}

@end
