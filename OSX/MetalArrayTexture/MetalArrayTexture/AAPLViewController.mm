/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View Controller for Metal Sample Code. Manages a MTKView and a AAPLRenderer object.
 */

#import "AAPLViewController.h"
#import "AAPLRenderer.h"
#import "AAPLMtkView.h"

#import <QuartzCore/CAMetalLayer.h>

@implementation AAPLViewController
{
@private
    
    // our renderer instance
    AAPLRenderer *_renderer;
}

- (void)initCommon
{
    _renderer = [AAPLRenderer new];
}

- (id)init
{
    self = [super init];
    
    if(self)
    {
        [self initCommon];
    }
    return self;
}

// called when loaded from nib
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    
    if(self)
    {
        [self initCommon];
    }
    
    return self;
}

// called when loaded from storyboard
- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    if(self)
    {
        [self initCommon];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AAPLMtkView *renderView = (AAPLMtkView *)self.view;
    renderView.device = MTLCreateSystemDefaultDevice();
    renderView.renderer = _renderer;
    
    // load all renderer assets before starting game loop
    [_renderer configure:renderView];
}

@end
