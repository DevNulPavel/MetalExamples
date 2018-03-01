/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
         This is the main renderer for this sample. Acts as the update and render delegate for the view controller and performs rendering. renders in 2 passes, 1) shadow pass, 2) Gbuffer pass which retains the drawable and presents it to the screen while discard the remaining attachments
      
 */

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#import "AAPLView.h"
#import "AAPLViewController.h"

#include "AAPLObjModel.h"
#include "AAPLTransforms.h"

@interface AAPLRenderer : NSObject <AAPLViewControllerDelegate, AAPLViewDelegate>

// Metal девайс
@property (nonatomic, readonly) id <MTLDevice> device;

// Загружаем все необходимые ассеты
- (void)configure:(AAPLView*)view;

@end
