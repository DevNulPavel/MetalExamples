# MetalArrayTexture

An array texture is a collection of one or two-dimensional images of identical size and format, arranged in layers. It results in fewer texture switching and thus less overhead, without some of the problems of atlases. This sample code demonstrates how to create and use a two-dimensional array texture in Metal. It visualizes a terrain by using terrain's Z-coordinate to index into an array texture and applies the correct image for that point's elevation.

The sample has both an iOS and OS X version. When running on iOS, pinch to zoom in and out, and pan to rotate the viewing camera. When running on OS X, press +/- keys to zoom in and out, and use the mouse to rotate the viewing camera.


## Requirements

### Build

iOS 9 SDK; OS X 10.11 SDK

### Runtime

iOS 9, 64 bit devices; OS X 10.11

Copyright (C) 2015 Apple Inc. All rights reserved.
