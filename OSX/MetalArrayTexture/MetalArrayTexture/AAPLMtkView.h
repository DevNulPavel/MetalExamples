/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A MTKView subclass. Handles camera movement. Delegates to the AAPLRenderer object for actual rendering and resizing.
 */

#import <MetalKit/MetalKit.h>

#import "AAPLRenderer.h"

@interface AAPLMtkView : MTKView

@property (strong, nonatomic) AAPLRenderer *renderer;

@end
