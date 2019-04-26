/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing the N-body compute resources.
 */

#import "CMNumerics.h"

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"
#import "NBodyComputePrefs.h"

#import "MetalNBodyComputeStage.h"

const static uint32_t kNBodyFloat4Size = sizeof(simd::float4);

@implementation MetalNBodyComputeStage {
@private
    BOOL _isStaged;
    
    uint32_t _multiplier;
    
    NSString* _name;
    NSDictionary* _globals;
    NSDictionary* _parameters;
    
    id<MTLFunction> _calculateFunction;
    id<MTLComputePipelineState> _computePipelineState;
    id<MTLBuffer> _positionsBuffers[2];
    id<MTLBuffer> _velocityBuffers[2];
    id<MTLBuffer> _paramsBuffer;
    
    uint32_t _dataStride;
    uint32_t _readBufferIndex;
    uint32_t _writeBufferIndex;
    
    uint64_t _buffersDataSize;
    uint64_t _preferencesDataSize;
    uint64_t _threadgroupMemorySize;
    
    uint64_t _threadsDimentionX;
    
    simd::float4* _positionsDataPtr[2];
    simd::float4* _velocityDataPtr[2];
    
    NBody::Compute::Prefs _preferences;
    NBody::Compute::Prefs* _paramsDataPtr;
    
    MTLSize _threadsCountInGroup;
    MTLSize _threadGroupsCount;
}

- (instancetype) init {
    self = [super init];
    
    if(self) {
        _name       = nil;
        _globals    = nil;
        _parameters = nil;
        
        _isStaged = NO;
        _multiplier  = 1;
        
        _calculateFunction = nil;
        _computePipelineState   = nil;
        
        _positionsBuffers[0] = nil;
        _positionsBuffers[1] = nil;
        
        _velocityBuffers[0] = nil;
        _velocityBuffers[1] = nil;
        
        _paramsBuffer = nil;
        
        _preferences.particles    = NBody::Defaults::kParticles;
        _preferences.timestep     = NBody::Defaults::kTimestep;
        _preferences.damping      = NBody::Defaults::kDamping;
        _preferences.softeningSqr = NBody::Defaults::kSofteningSqr;
        
        _buffersDataSize = _dataStride * _preferences.particles; // Размер буффера данных
        _preferencesDataSize = sizeof(NBody::Compute::Prefs);    // Размер буффера настроек
        _threadgroupMemorySize = 0;                              // Размер буфферных данных на отдельную тредгруппу
        
        _dataStride = kNBodyFloat4Size;
        _readBufferIndex = 0;
        _writeBufferIndex = 1;
        
        _positionsDataPtr[0] = nullptr;
        _positionsDataPtr[1] = nullptr;
        
        _velocityDataPtr[0] = nullptr;
        _velocityDataPtr[1] = nullptr;
        
        _paramsDataPtr = nullptr;
    }
    
    return self;
}

// Получаем текущий активный буффер с позициями
- (nullable id<MTLBuffer>) getActivePositionBuffer {
    return _positionsBuffers[_readBufferIndex];
}

// Указатель на данные с позициями
- (nullable simd::float4 *) getPositionData{
    return _positionsDataPtr[_readBufferIndex];
}

// Указатель на данные с ускорениями
- (nullable simd::float4 *) getVelocityData {
    return _velocityDataPtr[_readBufferIndex];
}

- (void)setMultiplier:(uint32_t)multiplier {
    if(!_isStaged) {
        _multiplier = (multiplier) ? multiplier : 1;
    }
}

// Установка глобальных параметров
- (void)setGlobals:(NSDictionary *)globals {
    if(globals && !_isStaged){
        _globals = globals;
        
        _preferences.particles = [_globals[kNBodyParticles] unsignedIntValue];
        
        _buffersDataSize = _dataStride * _preferences.particles;
    }
}

// Установка параметров конкретной симуляции
- (void)setActiveParameters:(NSDictionary *)parameters{
    if(parameters){
        _parameters = parameters;
        
        const float nSoftening = [_parameters[kNBodySoftening] floatValue];
        
        _preferences.timestep     = [_parameters[kNBodyTimestep]  floatValue];
        _preferences.damping      = [_parameters[kNBodyDamping]   floatValue];
        _preferences.softeningSqr = nSoftening * nSoftening;
        
        *_paramsDataPtr = _preferences;
    }
}

- (BOOL)acquire:(nullable id<MTLDevice>)device {
    if(device){
        if(!_library){
            NSLog(@">> ERROR: Metal library is nil!");
            return NO;
        }
        
        // Получаем вычислительную функцию из шейдеров
        _calculateFunction = [_library newFunctionWithName:(_name) ? _name : @"NBodyIntegrateSystem"];
        if(!_calculateFunction){
            NSLog(@">> ERROR: Failed to instantiate function!");
            return NO;
        }
        
        // создаем вычислительное состояние для энкодера
        NSError* pError = nil;
        _computePipelineState = [device newComputePipelineStateWithFunction:_calculateFunction error:&pError];
        if(!_computePipelineState){
            NSString* pDescription = [pError description];
            if(pDescription){
                NSLog(@">> ERROR: Failed to instantiate kernel: {%@}!", pDescription);
            }else{
                NSLog(@">> ERROR: Failed to instantiate kernel!");
            }
            return NO;
        }
        
        // Получаем количество потоков на группу
        // threadExecutionWidth - это количество потоков, которое дается на выполнение отдельной функции за один вызов
        // точнее - количество гарантированно параллельный потоков
        _threadsDimentionX = _computePipelineState.threadExecutionWidth;
        
        // Просто максимальное количество потоков в группе потоков, но не обязательно параллельных, для такого варианта требуется барьер
        //_threadsDimentionX = MIN(_computePipelineState.maxTotalThreadsPerThreadgroup, 1024);
        
        if((_preferences.particles % _threadsDimentionX) != 0) {
            NSLog(@">> ERROR: The number of bodies needs to be a multiple of the workgroup size!");
            return NO;
        }
        
        // Размер буфферных данных на отдельную тредгруппу, максимум 16Кб
        _threadgroupMemorySize = kNBodyFloat4Size * _threadsDimentionX;
        
        // Вычисляем необходимое количество групп потоков
        _threadGroupsCount = MTLSizeMake(_preferences.particles/_threadsDimentionX, 1, 1);
        // Количество потоков в отдельной группе потоков
        _threadsCountInGroup  = MTLSizeMake(_threadsDimentionX, 1, 1);
        
        // Создаем входной Метал буффер для позиций
        _positionsBuffers[_readBufferIndex] = [device newBufferWithLength:_buffersDataSize options:0];
        if(!_positionsBuffers[_readBufferIndex]){
            NSLog(@">> ERROR: Failed to instantiate position buffer 1!");
            return NO;
        }
        
        // Получаем указатель на входные данные позиций
        _positionsDataPtr[_readBufferIndex] = static_cast<simd::float4*>([_positionsBuffers[_readBufferIndex] contents]);
        if(!_positionsDataPtr[_readBufferIndex]){
            NSLog(@">> ERROR: Failed to get the base address to position buffer 1!");
            return NO;
        }
        
        // Создаем выходной Метал буффер данных для позиций
        _positionsBuffers[_writeBufferIndex] = [device newBufferWithLength:_buffersDataSize options:0];
        if(!_positionsBuffers[_writeBufferIndex]){
            NSLog(@">> ERROR: Failed to instantiate position buffer 2!");
            return NO;
        }
        
        // Получаем указатель на выходные данные позиций
        _positionsDataPtr[_writeBufferIndex] = static_cast<simd::float4 *>([_positionsBuffers[_writeBufferIndex] contents]);
        if(!_positionsDataPtr[_writeBufferIndex]){
            NSLog(@">> ERROR: Failed to get the base address to position buffer 2!");
            return NO;
        }
        
        // Создаем входной Метал буффер для направления движений
        _velocityBuffers[_readBufferIndex] = [device newBufferWithLength:_buffersDataSize options:0];
        if(!_velocityBuffers[_readBufferIndex]){
            NSLog(@">> ERROR: Failed to instantiate velocity buffer 1!");
            return NO;
        }
        
        // Получаем указатель на входные данные направления движений
        _velocityDataPtr[_readBufferIndex] = static_cast<simd::float4 *>([_velocityBuffers[_readBufferIndex] contents]);
        if(!_velocityDataPtr[_readBufferIndex]){
            NSLog(@">> ERROR: Failed to get the base address to velocity buffer 1!");
            return NO;
        }
        
        // Создаем выходной Метал буффер для направления движений
        _velocityBuffers[_writeBufferIndex] = [device newBufferWithLength:_buffersDataSize options:0];
        if(!_velocityBuffers[_writeBufferIndex]){
            NSLog(@">> ERROR: Failed to instantiate velocity buffer 2!");
            return NO;
        }
        
        // Получаем указатель на выходные данные направления движений
        _velocityDataPtr[_writeBufferIndex] = static_cast<simd::float4 *>([_velocityBuffers[_writeBufferIndex] contents]);
        if(!_velocityDataPtr[_writeBufferIndex]){
            NSLog(@">> ERROR: Failed to get the base address to velocity buffer 2!");
            return NO;
        }
        
        // Создаем Метал буффер для параметров
        _paramsBuffer = [device newBufferWithLength:_preferencesDataSize options:0];
        if(!_paramsBuffer){
            NSLog(@">> ERROR: Failed to instantiate compute kernel parameter buffer!");
            return NO;
        }
        
        // Указатель на данные параметров
        _paramsDataPtr = static_cast<NBody::Compute::Prefs*>([_paramsBuffer contents]);
        if(!_paramsDataPtr){
            NSLog(@">> ERROR: Failed to get the base address to compute kernel parameter buffer!");
            return NO;
        }
        
        return YES;
    } else {
        NSLog(@">> ERROR: Metal device is nil!");
    }
    
    return NO;
}

// Настройка и генерация необходимых ресурсов для девайса
- (void)setupForDevice:(nullable id<MTLDevice>)device {
    if(!_isStaged){
        _isStaged = [self acquire:device];
    }
}

// Выполняем вычисления на GPU
- (void)encode:(nullable id<MTLCommandBuffer>)cmdBuffer {
    if(cmdBuffer) {
        id<MTLComputeCommandEncoder> encoder = [cmdBuffer computeCommandEncoder];
        
        if(encoder) {
            // Выставляем вычислительный стейт
            [encoder setComputePipelineState:_computePipelineState];
            
            // Выставляем выходные буфферы
            [encoder setBuffer:_positionsBuffers[_writeBufferIndex] offset:0 atIndex:0];
            [encoder setBuffer:_velocityBuffers[_writeBufferIndex] offset:0 atIndex:1];
            
            // Выставляем входные буфферы
            [encoder setBuffer:_positionsBuffers[_readBufferIndex] offset:0 atIndex:2];
            [encoder setBuffer:_velocityBuffers[_readBufferIndex] offset:0 atIndex:3];
            
            // Выставляем буффер с параметрами
            [encoder setBuffer:_paramsBuffer offset:0 atIndex:4];
            
            // Размер буфферных данных на отдельную тредгруппу, максимум - 16Кб
            [encoder setThreadgroupMemoryLength:_threadgroupMemorySize atIndex:0];
            
            // Ставим вычисления в очередь
            [encoder dispatchThreadgroups:_threadGroupsCount threadsPerThreadgroup:_threadsCountInGroup];
            
            [encoder endEncoding];
        }
    }
}

// Меняем местами индексы входных и выходных буфферов
- (void) swapBuffers {
    CM::swap(_readBufferIndex, _writeBufferIndex);
}

@end
