/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/

#ifndef AAPLShaderTypes_h
#define AAPLShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum AAPLBufferIndices
{
    kBufferIndexMeshPositions    = 0,
    kBufferIndexMeshGenerics     = 1,
    kBufferIndexUniforms         = 2,
    kBufferIndexMaterialUniforms = 3
} AAPLBufferIndices;

// Attribute index values shared between shader and C code to ensure Metal shader vertex
//   attribute indices match the Metal API vertex descriptor attribute indices
typedef enum AAPLVertexAttributes
{
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    kVertexAttributeNormal    = 2,
    kVertexAttributeTangent   = 3,
    kVertexAttributeBitangent = 4
} AAPLVertexAttributes;

// Texture index values shared between shader and C code to ensure Metal shader texture indices
//   match indices of Metal API texture set calls
typedef enum AAPLTextureIndices
{
    kTextureIndexBaseColor        = 0,
    kTextureIndexMetallic         = 1,
    kTextureIndexRoughness        = 2,
    kTextureIndexNormal           = 3,
    kTextureIndexAmbientOcclusion = 4,
    kTextureIndexIrradianceMap    = 5,
    kNumMeshTextureIndices = kTextureIndexAmbientOcclusion+1,
} AAPLTextureIndices;

typedef enum AAPLFunctionConstantIndices
{
    kFunctionConstantBaseColorMapIndex,
    kFunctionConstantNormalMapIndex,
    kFunctionConstantMetallicMapIndex,
    kFunctionConstantRoughnessMapIndex,
    kFunctionConstantAmbientOcclusionMapIndex,
    kFunctionConstantIrradianceMapIndex
} AAPLFunctionConstantIndices;

typedef enum AAPLViewports
{
    kViewportLeft  = 0,
    kViewportRight = 1,
    kViewportNumViewports
} AAPLViewports;

// Structure shared between shader and C code to ensure the layout of uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct
{
    // Per Frame Uniforms
    vector_float3 cameraPos;
    
    // Per Mesh Uniforms
    matrix_float4x4 modelMatrix;
    matrix_float4x4 modelViewProjectionMatrix;
    matrix_float3x3 normalMatrix;

    // Per Light Properties
    vector_float3 directionalLightInvDirection;
    vector_float3 lightPosition;

    vector_float3 irradiatedColor;
    float irradianceMapWeight;
} AAPLUniforms;

typedef struct
{
    vector_float3 baseColor;
    vector_float3 irradiatedColor;
    vector_float3 roughness;
    vector_float3 metalness;
    float         ambientOcclusion;
    float         mapWeights[kNumMeshTextureIndices];
} AAPLMaterialUniforms;

typedef enum AAPLQualityLevel
{
    kQualityLevelHigh   = 0,
    kQualityLevelMedium = 1,
    kQualityLevelLow    = 2,
    kQualityNumLevels
} AAPLQualityLevel;

#endif /* AAPLShaderTypes_h */

