/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Fragment and vertex shaders, and the compute kernel for N-body simulation.
 */

#import <metal_stdlib>

#import "NBodyComputePrefs.h"

using namespace metal;

//--------------------------------------------------
//
// Vertex and fragment shaders for n-body simulation
//
//--------------------------------------------------

typedef struct {
    float4 position  [[position]];
    half4  color;
    float  pointSize [[point_size]];
} FragColor;

vertex FragColor NBodyLightingVertex(device float4*     positionRead        [[ buffer(0) ]],
                                     device float4*     color               [[ buffer(1) ]],
                                     constant float4x4& modelViewProjection [[ buffer(2) ]],
                                     constant float&    pointSize           [[ buffer(3) ]],
                                     uint               vid                 [[ vertex_id ]])
{
    FragColor outColor;
    
    outColor.pointSize = pointSize;
    outColor.color     = half4(color[vid]);
    
    float4 inPosition = float4(float3(positionRead[vid]), 1.0);
    
    outColor.position = float4(modelViewProjection * inPosition);
    
    return outColor;
}

fragment half4 NBodyLightingFragment(FragColor        inColor      [[ stage_in    ]],
                                     texture2d<half>  splatTexture [[ texture(0)  ]],
                                     sampler          sam          [[ sampler(0)  ]],
                                     float2           texcoord     [[ point_coord ]])
{
    half4 c = splatTexture.sample(sam, texcoord);
    
    half4 fragColor = (0.6h + 0.4h * inColor.color) * c;
    
    half4 x = half4(0.1h, 0.0h, 0.0h, fragColor.w);
    half4 y = half4(1.0h, 0.7h, 0.3h, fragColor.w);
    half  a = fragColor.w;
    
    return fragColor * mix(x, y, a);
}



//--------------------------------------
//
// Compute Kernel for n-body simulation
//
//--------------------------------------

typedef NBody::Compute::Prefs NBodyPrefs;

static float3 NBodyComputeForce(const float4 pos_1, const float4 pos_0, const float  softeningSqr) {
    // Вычисляем направление от старой позиции к новой
    float3 r = pos_1.xyz - pos_0.xyz;
    
    // Вычисляем расстояние между точками
    float distSqr = distance_squared(pos_1.xyz, pos_0.xyz);
    
    // Добавляем к расстоянию параметр
    distSqr += softeningSqr;
    
    // Обратный корень от расстояния
    float invDist  = rsqrt(distSqr);
    
    // Куб обратного корня расстояния
    float invDist3 = invDist * invDist * invDist;
    
    float s = pos_1.w * invDist3;
    
    return r * s;
}

// Вычислительный шейдер
kernel void NBodyIntegrateSystem(device float4* const pos_1 [[ buffer(0) ]],    // Выходные позиции
                                 device float4* const vel_1 [[ buffer(1) ]],    // Выходные ускорения
                                 constant float4* const pos_0 [[ buffer(2) ]],  // Позиции предыдущего кадра
                                 constant float4* const vel_0 [[ buffer(3) ]],  // Ускорения предыдущего кадра
                                 constant NBodyPrefs& prefs [[ buffer(4) ]],    // Настройки
                                 
                                 threadgroup float4* threadgroupBufferData [[ threadgroup(0) ]], // Буфферные данные на отдельную тредгруппу, высокая скорость
                                 
                                 const ushort positionInAllGrid [[ thread_position_in_grid ]],      // Позиция во всей сетке
                                 const ushort localPosInGroup [[ thread_position_in_threadgroup ]], // Позиция потока в тредгруппе
                                 const ushort threadsCountOnGroup [[ threads_per_threadgroup ]])    // Количество потоков в группе
{

    // Общее количество партиклов
    const ushort particles = prefs.particles;
    
    const float softeningSqr = prefs.softeningSqr;
    
    // Предыдущая позиция в сетке
    float4 oldPos = pos_0[positionInAllGrid];
    
    // Переменная для ускорения
    float3 acc = 0.0f;
    
    // Обходим все точки с шагом размером равным количеству потоков на тредгруппу
    // Потоки в тредгруппе выполняются параллельно и синхронно,
    // так как выставлено количество потоков на группу, равное размеру SIMD
    for(ushort i = 0; i < particles; i += threadsCountOnGroup){
        // Обновляем значение позиции конкретной точки в быстрой разделяемой памяти
        threadgroupBufferData[localPosInGroup] = pos_0[i + localPosInGroup];
        
        for(ushort j = 0; j < threadsCountOnGroup; j++){
            acc += NBodyComputeForce(threadgroupBufferData[j], oldPos, softeningSqr);
        }
    }
    // Вычисляем взаимодействие со всеми остальными частицами
    /*for(ushort i = 0; i < particles; i++){
        if(positionInAllGrid != i){
            float4 testPos = pos_0[i];
            acc += NBodyComputeForce(testPos, oldPos, softeningSqr);
        }
    }*/
    
    // Получаем старое ускорение данной точки
    float4 oldVel = vel_0[positionInAllGrid];
    
    // Меняем скорость данной точки на основе рассчитанного ускорения
    oldVel.xyz += acc * prefs.timestep;
    
    // Умножаем скорость на затухание
    oldVel.xyz *= prefs.damping;
    
    // Обновляем позицию точки на основе скорости движения
    oldPos.xyz += oldVel.xyz * prefs.timestep;
    
    // Записываем полученное значение позиции и скорости
    pos_1[positionInAllGrid] = oldPos;
    vel_1[positionInAllGrid] = oldVel;
}
