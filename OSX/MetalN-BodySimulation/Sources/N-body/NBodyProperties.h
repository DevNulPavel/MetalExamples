/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing a set of defualt initial conditions for n-body simulation.
 */

#import <Foundation/Foundation.h>

@interface NBodyProperties: NSObject

// Выбираем новую конфигурацию симуляции
@property (nonatomic, setter=setActiveSimulationConfigIndex:) uint32_t activeSimulationConfigIndex;
// Количество цветов
@property (nonatomic, setter=setColorChannelsCount:) uint32_t colorChannelsCount;
// Количество партиклов
@property (nonatomic, setter=setTotalParticlesCount:) uint32_t totalParticlesCount;
// Разрешение текстуры - стандартно 64x64
@property (nonatomic, setter=setTexRes:) uint32_t texRes;
// Общее количество различных типов симуляций
@property (readonly) uint32_t simulationsTotalCount;


// Загрузка свойств из файлика plist
- (nullable instancetype)initWithFile:(nullable NSString *)fileName;
// Словарь с глобальными параметрами симуляций
- (nonnull NSDictionary *)getGlobals;
// Параметры для текущей симуляций
- (nonnull NSDictionary *)getActiveSimulationParameters;

@end
