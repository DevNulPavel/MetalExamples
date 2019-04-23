/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Utility class for managing a set of defualt initial conditions for n-body simulation.
 */

#import "NBodyDefaults.h"
#import "NBodyPreferencesKeys.h"
#import "NBodyProperties.h"

@implementation NBodyProperties {
@private
    uint32_t  _simulationsTotalCount;
    uint32_t  _activeSimulationConfigIndex;
    uint32_t  _totalParticlesCount;
    uint32_t  _texRes;
    uint32_t  _colorChannelsCount;
    
    NSMutableDictionary* _globalParameters;
    NSMutableArray* _allSimulationProperties;
    
    NSMutableDictionary* _activeSimulationParameters;
}

- (nullable NSMutableDictionary *) _newProperties:(nullable NSString *)pFileName {
    NSMutableDictionary* pProperties = nil;
    
    if(!pFileName){
        NSLog(@">> ERROR: File name is nil!");
        return nil;
    }

    NSBundle* pBundle = [NSBundle mainBundle];
    if(!pBundle){
        NSLog(@">> ERROR: Failed acquiring a main bundle object!");
        return nil;
    }
    
    NSString* pPathname = [NSString stringWithFormat:@"%@/%@", pBundle.resourcePath, pFileName];
    if(!pPathname) {
        NSLog(@">> ERROR: Failed instantiating a pathname from reource path and file name!");
        return nil;
    }
    
    NSData* pXML = [NSData dataWithContentsOfFile:pPathname];
    if(!pXML){
        NSLog(@">> ERROR: Failed instantiating a xml data from the contents of a file!");
        return nil;
    }
    
    NSError* pError = nil;
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    pProperties = [NSPropertyListSerialization propertyListWithData:pXML
                                                            options:NSPropertyListMutableContainers
                                                             format:&format
                                                              error:&pError];
    
    if(pError){
        NSLog(@">> ERROR: \"%@\"", pError.description);
    }
    
    return pProperties;
}

// Загрузка свойств из файлика plist
- (nullable instancetype) initWithFile:(nullable NSString *)fileName {
    self = [super init];
    
    if(self){
        // Получаем словарь из файлика
        NSMutableDictionary* pProperties = [self _newProperties:fileName];
        
        if(pProperties){
            // Получаем глобальные настройки по ключу
            _globalParameters = pProperties[kNBodyGlobals];
            
            if(_globalParameters){
                // Количество партиклов
                _totalParticlesCount = [_globalParameters[kNBodyParticles] unsignedIntValue];
                // Разрешение текстуры
                _texRes    = [_globalParameters[kNBodyTexRes]    unsignedIntValue];
                // Количество каналов цветов
                _colorChannelsCount  = [_globalParameters[kNBodyChannels]  unsignedIntValue];
            }
            
            // Получаем свойства каждой отдельной анимации
            _allSimulationProperties = pProperties[kNBodyParameters];
            if(_allSimulationProperties){
                _simulationsTotalCount  = uint32_t(_allSimulationProperties.count);
                _activeSimulationConfigIndex = _simulationsTotalCount;
            }
            
            _activeSimulationParameters = nil;
        }
    }
    return self;
}

- (nullable instancetype) init {
    return [self initWithFile:@"NBodyAppPrefs.plist"];
}

// Получаем глобальные параметры из конфига
- (NSDictionary *) getGlobals {
    return _globalParameters;
}

// Параметры отдельных симуляций
- (NSDictionary *) getActiveSimulationParameters {
    return _activeSimulationParameters;
}

// Выбираем конфиг симуляции
- (void)setActiveSimulationConfigIndex:(uint32_t)config {
    if(config != _activeSimulationConfigIndex){
        _activeSimulationConfigIndex = config;
        
        _activeSimulationParameters = _allSimulationProperties[_activeSimulationConfigIndex];
    }
}

// Установка количества партиклов
- (void) setTotalParticlesCount:(uint32_t)particles{
    const uint32_t ptparticles = (particles > 1024) ? particles : NBody::Defaults::kParticles;
    
    if(ptparticles != _totalParticlesCount){
        _totalParticlesCount = ptparticles;
        
        _globalParameters[kNBodyParticles] = @(_totalParticlesCount);
    }
}

// Установка количества каналов цвета
- (void) setColorChannelsCount:(uint32_t)channels {
    const uint32_t nChannels = (channels) ? channels : NBody::Defaults::kChannels;
    
    if(nChannels != _colorChannelsCount){
        _colorChannelsCount = nChannels;
        
        _globalParameters[kNBodyChannels] = @(_colorChannelsCount);
    }
}

// Разрешение текстуры - стандартно 64x64
- (void) setTexRes:(uint32_t)texRes {
    const uint32_t nTexRes = (texRes) ? texRes : NBody::Defaults::kTexRes;
    
    if(nTexRes != _texRes){
        _texRes = nTexRes;
        
        _globalParameters[kNBodyTexRes] = @(_texRes);
    }
}

@end
