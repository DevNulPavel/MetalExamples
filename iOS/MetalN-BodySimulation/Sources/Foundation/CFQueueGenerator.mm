/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A functor for creating dispatch queue with a unique identifier.
 */

#import <random>
#import <strstream>

#import "CFQueueGenerator.h"

@implementation CFQueueGenerator {
@private
    // Id очереди
    uint64_t _queueID;
    
    // Аттрибуты очереди
    dispatch_queue_attr_t _attribute;
    
    // Имя очереди
    std::string _queueLabel;
    
    // Лейбл очереди + ее Id
    std::string _queueLabelAndID;
    
    // Рандом-девайс для генерации чисел
    std::random_device _randomDevice;
}

- (instancetype)init{
    self = [super init];
    
    if(self) {
        // Начальный id очереди
        _queueID = 0;
        
        // Пустые строки
        _queueLabelAndID  = "";
        _queueLabel = "";

        // По-умолчанию очередь последовательная
        _attribute = DISPATCH_QUEUE_SERIAL;
    }
    
    return self;
}

- (dispatch_queue_attr_t)getAttribute{
    return _attribute;
}

-(void)setAttribute:(dispatch_queue_attr_t)attr{
    _attribute = attr;
}

- (nullable const char*)getLabel {
    return _queueLabel.c_str();
}

- (void)setLabel:(nullable const char *)label {
    if(label != nullptr) {
        _queueLabel = label;
    }
}

// Идентификатор
- (nullable const char*)getIdentifier {
    return _queueLabelAndID.c_str();
}

// Генерация новой очереди
- (nullable dispatch_queue_t)generateQueue {
    _queueID = _randomDevice();

    std::strstream sqid;
    
    sqid << _queueID;
    
    if(_queueLabel.empty()){
        _queueLabelAndID = sqid.str();
    } else{
        _queueLabelAndID  = _queueLabel + ".";
        _queueLabelAndID += sqid.str();
    }
    
    _queueLabelAndID += "\0";
    
    return dispatch_queue_create(_queueLabelAndID.c_str(), _attribute);
}

@end
