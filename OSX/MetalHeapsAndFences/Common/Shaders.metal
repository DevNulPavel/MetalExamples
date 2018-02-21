/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Vertex and fragment shader for full screen quad and mipmap filtering.
 */

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
} vertex_t;

typedef struct {
    float4 position [[position]];
    float2 texCoord [[user(texturecoord)]];
} VertexInOut;

// Vertex shader function
vertex VertexInOut texturedQuadVertex(vertex_t vertexArray      [[stage_in]],
                                  constant matrix_float4x4 &mvp [[buffer(1)]]) {
    VertexInOut out;
    
    float4 in_position = float4(vertexArray.position, 1.0);
    out.position = mvp * in_position;
    out.texCoord = vertexArray.texCoord;
    
    return out;
}

// Fragment shader function
fragment half4 texturedQuadFragment(VertexInOut in          [[stage_in]],
                                 texture2d<half> tex2D      [[texture(0)]],
                                 constant float &mipmapBias [[buffer(0)]]) {
    constexpr sampler quadSampler(min_filter::linear, mag_filter::linear, mip_filter::linear, s_address::clamp_to_edge, t_address::clamp_to_edge, r_address::clamp_to_edge);
    half4 color = tex2D.sample(quadSampler, in.texCoord, level(mipmapBias));
    return color;
}
