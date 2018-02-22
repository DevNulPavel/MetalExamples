/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Application view controller implementing Metal Kit delgates.
 */

#import <cmath>

#import "NBodyVisualizer.h"

#import "AppViewController.h"

@implementation AppViewController {
@private
    // Текущее Metal устройство
    id<MTLDevice> device;
    
    // Текущая вьюшка
    MTKView* mpView;
    
    // N-мерный визуализатор
    NBodyVisualizer*  mpVisualizer;
}

- (void) didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
}

- (UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Создание нового обхекта симуляции
    mpVisualizer = [NBodyVisualizer new];
    assert(mpVisualizer);

    // Выставляем девайс симуляции + происходит инициализация ресурсов
    [mpVisualizer acquire:device];
    
    // If successful in acquiring resources for the visualizer
    // object, then continue
    assert(mpVisualizer.haveVisualizer);
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    // Получаем стандартный девайс
    device = MTLCreateSystemDefaultDevice();
    assert(device);

    // Конвертируем вьюшку к нашему типу
    mpView = static_cast<MTKView*>(self.view);
    assert(mpView);
    
    // Настраиваем вьюшку
    mpView.device   = device;
    mpView.delegate = self;
}

- (void) update:(nonnull MTKView *)view {
    const CGRect bounds = view.bounds;
    const float  aspect = float(std::abs(bounds.size.width / bounds.size.height));
    
    // Обновляем соотношение сторон у визуализатора
    mpVisualizer.aspect = aspect;
}

- (void) mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Обновляем трансформы
    [self update:view];
}

- (void) drawInMTKView:(nonnull MTKView *)view {
    if(view){
        @autoreleasepool {
            [self update:view];
            
            id<CAMetalDrawable> (^getDrawableBlock)(void) = ^{
                return view.currentDrawable;
            };
            // Вызываем отрисовку партиклов для симуляции тела из сеттера
            [mpVisualizer render:getDrawableBlock];
        }
    }
}

@end
