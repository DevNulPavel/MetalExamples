/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A functor for creating dispatch queue with a unique identifier.
 */

#import <Foundation/Foundation.h>

@interface CFQueueGenerator : NSObject

// Аттрибуты очереди - по-умолчанию последовательная
@property (nullable, getter=getAttribute, setter=setAttribute:) dispatch_queue_attr_t attribute;
// Имя очереди
@property (nullable, nonatomic, getter=getLabel, setter=setLabel:) const char* label;


// Идентификатор
- (nullable const char*)getIdentifier;

// Генерация новой очереди
- (nullable dispatch_queue_t)generateQueue;

@end
