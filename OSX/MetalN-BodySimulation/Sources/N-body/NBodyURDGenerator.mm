/*
 <codex>
 <import>NBodyURDGenerator.h</import>
 </codex>
 */

#import <memory>

#import "CFQueueGenerator.h"

#import "CMNumerics.h"
#import "CMRandom.h"

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"

#import "NBodyURDGenerator.h"

static const float kScale = 1.0f/1024.0f;

struct NBodyScales {
    float mnCluster;
    float mnVelocity;
    float mnParticles;
};

typedef struct NBodyScales NBodyScales;

@implementation NBodyURDGenerator {
@private
    uint32_t _configId;
    
    NSDictionary* _globals;
    NSDictionary* _parameters;
    
    simd::float3 _axis;
    
    simd::float4* _position;
    simd::float4* _velocity;
    simd::float4* _colors;
    
    bool _isComplete;
    
    uint32_t _particlesTotalCount;
    
    NBodyScales _scales;
    
    dispatch_queue_t _updateDispatchQueue;
    
    std::unique_ptr<CM::URD3::generator> _generators[2];
}

- (instancetype) init{
    self = [super init];
    
    if(self) {
        _generators[0] = CM::URD3::unique_ptr(0.0f, 1.0f, 0.0f);
        _generators[1] = CM::URD3::unique_ptr(-1.0f, 1.0f, 1.0f);

        _globals    = nil;
        _parameters = nil;
        
        _configId = NBody::Defaults::Configs::eCount;
        
        _axis = {0.0f, 0.0f, 1.0f};
        
        _position = nullptr;
        _velocity = nullptr;
        _colors   = nullptr;
        
        _updateDispatchQueue = nullptr;
        
        _particlesTotalCount = NBody::Defaults::kParticles;
        
        _scales.mnCluster   = NBody::Defaults::Scale::kCluster;
        _scales.mnVelocity  = NBody::Defaults::Scale::kVelocity;
        _scales.mnParticles = kScale * float(_particlesTotalCount);
        
        _isComplete = (_generators[0] != nullptr) && (_generators[1] != nullptr);
    }
    
    return self;
}

// Coordinate points on the Eunclidean axis of simulation
- (void) setAxis:(simd::float3)axis {
    _axis = simd::normalize(axis);
}

// Установка указателя для данные цвета
- (void)setColors:(simd::float4*)colors {
    if(colors != nullptr){
        _colors = colors;
        
        // Применяем асинхронное заполнение значениями массива цветов
        dispatch_apply(_particlesTotalCount, _updateDispatchQueue, ^(size_t i) {
            _colors[i].xyz = _generators[0]->rand();
            _colors[i].w   = 1.0f;
        });
    }
}

// Установка глобальных параметров из конфига
- (void)setGlobals:(NSDictionary *)globals {
    if(globals) {
        // Сохраняем параметры
        _globals = globals;
        
        // Получаем количество партиклов
        _particlesTotalCount = [_globals[kNBodyParticles] unsignedIntValue];
        
        _scales.mnParticles = kScale * float(_particlesTotalCount);
    }
}

// Установка параметров конкретной симуляции
- (void)setParameters:(NSDictionary *)parameters {
    if(parameters){
        _parameters = parameters;
        
        _scales.mnCluster  = [_parameters[kNBodyClusterScale]  floatValue];
        _scales.mnVelocity = [_parameters[kNBodyVelocityScale] floatValue];
    }
}

- (void)configureRandom {
    const float pscale = _scales.mnCluster  * std::max(1.0f, _scales.mnParticles);
    const float vscale = _scales.mnVelocity * pscale;
    
    // Заполняем позиции и ускорения случайными значениями
    dispatch_apply(_particlesTotalCount, _updateDispatchQueue, ^(size_t i) {
        simd::float3 point    = _generators[1]->nrand();
        simd::float3 velocity = _generators[1]->nrand();
        
        _position[i].xyz = pscale * point;
        _position[i].w   = 1.0f;
        
        _velocity[i].xyz = vscale * velocity;
        _velocity[i].w   = 1.0f;
    });
}

- (void)configureShell {
    const float pscale = _scales.mnCluster;
    const float vscale = pscale * _scales.mnVelocity;
    const float inner  = 2.5f * pscale;
    const float outer  = 4.0f * pscale;
    const float length = outer - inner;
    
    dispatch_apply(_particlesTotalCount, _updateDispatchQueue, ^(size_t i) {
        simd::float3 nrpos    = _generators[1]->nrand();
        simd::float3 rpos     = _generators[0]->rand();
        simd::float3 position = nrpos * (inner + (length * rpos));
        
        _position[i].xyz = position;
        _position[i].w   = 1.0;
        
        simd::float3 axis = _axis;
        
        float scalar = simd::dot(nrpos, axis);
        
        if((1.0f - scalar) < 1e-6){
            axis.xy = nrpos.yx;
            
            axis = simd::normalize(axis);
        }
        
        simd::float3 velocity = simd::cross(position, axis);
        
        _velocity[i].xyz = velocity * vscale;
        _velocity[i].w   = 1.0;
    });
}

- (void)configureExpand {
    const float pscale = _scales.mnCluster * std::max(1.0f, _scales.mnParticles);
    const float vscale = pscale * _scales.mnVelocity;
    
    dispatch_apply(_particlesTotalCount, _updateDispatchQueue, ^(size_t i) {
        simd::float3 point = _generators[1]->rand();
        
        _position[i].xyz = point * pscale;
        _position[i].w   = 1.0;
        
        _velocity[i].xyz = point * vscale;
        _velocity[i].w   = 1.0;
    });
}

// Генерация начальных данных для симуляции
- (void)setConfigId:(uint32_t)config{
    if(_isComplete && (_position != nullptr) && (_velocity != nullptr)) {
        _configId = config;
        
        if(!_updateDispatchQueue){
            CFQueueGenerator* pQGen = [CFQueueGenerator new];
            
            if(pQGen){
                pQGen.label = "com.apple.nbody.generator.main";
                
                _updateDispatchQueue = pQGen.queue;
            }
        }
        
        if(_updateDispatchQueue){
            switch(_configId){
                case NBody::Defaults::Configs::eExpand:
                    [self configureExpand];
                    break;
                    
                case NBody::Defaults::Configs::eRandom:
                    [self configureRandom];
                    break;
                    
                case NBody::Defaults::Configs::eShell:
                default:
                    [self configureShell];
                    break;
            }
        }
    }
}

@end
