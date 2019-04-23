/*
 <codex>
 <abstract>
 Base class for generating random packed or split data sets for the gpu bound simulator using unifrom real distribution.
 </abstract>
 </codex>
 */

#import <simd/simd.h>

#import <Foundation/Foundation.h>

@interface NBodyURDGenerator : NSObject

// Указатель на данные позиций и ускорений
@property (nullable) simd::float4* position;
@property (nullable) simd::float4* velocity;

// Установка указателя для данные цвета
@property (nullable, nonatomic, setter=setColors:) simd::float4* colors;

// Coordinate points on the Eunclidean axis of simulation
@property (nonatomic, setter=setAxis:) simd::float3 axis;

// Генерация начальных данных для симуляции
- (void)setConfigId:(uint32_t)config;

// Установка глобальных параметров из конфига
- (void)setGlobals:(nonnull NSDictionary*)globals;

// Установка параметров конкретной симуляции
- (void)setParameters:(nonnull NSDictionary*)parameters;

@end
