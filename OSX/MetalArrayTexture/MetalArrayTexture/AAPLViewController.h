/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View Controller for Metal Sample Code. Manages a MTKView and a AAPLRenderer object.
 */

#ifdef TARGET_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@protocol AAPLViewControllerDelegate;

#ifdef TARGET_IOS
@interface AAPLViewController : UIViewController
#else
@interface AAPLViewController : NSViewController
#endif

@end
