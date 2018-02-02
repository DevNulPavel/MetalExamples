/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal shader code to perform a separable pass gaussian blur filter.
 */

#include <metal_stdlib>
using namespace metal;

constant float gaussianWeights[5] { 0.06136, 0.24477, 0.38774, 0.24477, 0.06136 };
static void gaussianblur(texture2d<half, access::read> inTexture,
                        texture2d<half, access::write> outTexture,
                        uint                           readLod,
                        uint                           writeLod,
                        int2                           offset,
                        uint2                          gid) {
    uint2 textureDim(outTexture.get_width(), outTexture.get_height());
    if(all(gid < textureDim)) {
        half3 outColor(0.0);
        
        for(int i = -2; i < 3; ++i) {
            uint2 pixCoord = clamp(uint2(int2(gid) + offset * i), uint2(0), textureDim);
            outColor += inTexture.read(pixCoord, readLod).rgb * gaussianWeights[i + 2];
        }
        
        outTexture.write(half4(outColor, 1.0), gid, writeLod);
    }
}

kernel void gaussianblurHorizontal(texture2d<half, access::read>  inTexture   [[texture(0)]],
                                   texture2d<half, access::write> outTexture  [[texture(1)]],
                                   constant uint                 &readLod     [[buffer(0)]],
                                   constant uint                 &writeLod    [[buffer(1)]],
                                   uint2                          gid         [[thread_position_in_grid]]) {
    gaussianblur(inTexture, outTexture, readLod, writeLod, int2(1, 0), gid);
}

kernel void gaussianblurVertical(texture2d<half, access::read>  inTexture   [[texture(0)]],
                                 texture2d<half, access::write> outTexture  [[texture(1)]],
                                 constant uint                 &readLod     [[buffer(0)]],
                                 constant uint                 &writeLod    [[buffer(1)]],
                                 uint2                          gid         [[thread_position_in_grid]]) {
    gaussianblur(inTexture, outTexture, readLod, writeLod, int2(0, 1), gid);
}
