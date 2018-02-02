/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal Renderer. Acts as the update and render delegate for the MTKView object.
 */

#import <MetalKit/MTKView.h>
#import "AAPLViewController.h"

#import <Metal/Metal.h>

@interface AAPLRenderer : NSObject

@property (nonatomic, readonly) float zoomFactor;

// load all assets before triggering rendering
- (void)configure:(MTKView *)view;

- (void)rotateCameraWithDx:(float)dx dy:(float)dy scale:(float)scale;
- (void)zoomCameraWithScale:(float)scale;

- (void)reshapeView:(MTKView *)view;
- (void)drawView:(MTKView *)view;

@end
