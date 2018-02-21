# MetalHeapsAndFences: Using Heaps and Fences in Metal

This sample demonstrates how to use Metal's heap and fence API, two new API concepts added to Apple's low-overhead graphics framework designed to further reduce the overhead of creating and using resources. The sample shows how to create separate heaps for static and dynamic textures. It also shows how to use fences to express dependencies between encoders that produce and consumer those dynamic textures. Dynamic textures not used together will also alias to reduce the amount of memory used.

## Requirements 

### Build

Xcode 8.0 or later; iOS 10.0 SDK or later; tvOS 10.0 SDK or later

### Runtime

iOS 10.0 or later; tvOS 10.0 or later

### Device Feature Set

iOS\_GPUFamily1\_v3 or later; iOS\_GPUFamily2\_v3 or later; iOS\_GPUFamily3\_v2 or later;

Copyright (C) 2016 Apple Inc. All rights reserved.
