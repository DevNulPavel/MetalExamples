/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal shader code to perform a separable pass gaussian blur filter.
 */

#include <metal_stdlib>
using namespace metal;

constant float gaussianWeights[5] { 0.06136, 0.24477, 0.38774, 0.24477, 0.06136 };

static void gaussianblur(texture2d<half, access::read> inTexture,   // Входная текстура
                        texture2d<half, access::write> outTexture,  // Выходная текстура
                        uint readLod,                               // Уровень мипмапов входной текстуры
                        uint writeLod,                              // Уровень мипмапов выходной текстуры
                        int2 offset,                                // Шаг смещения
                        uint2 gid) {                                // Позиция в сетке
    
    // Размерность выходной текстуры
    uint2 outTextureSize(outTexture.get_width(), outTexture.get_height());
    
    if(all(gid < outTextureSize)) {
        // Переменная выходного цвета
        half3 outColor(0.0);
        
        // Обход соседних пикселей
        for(int i = -2; i < 3; ++i) {
            // Получаем пиксели-окресности пикселя
            uint2 pixCoord = uint2(int2(gid) + offset * i);
            pixCoord = clamp(pixCoord, uint2(0, 0), outTextureSize);
            
            // Читаем из текстуры цвет с Гаусовским коэффициэнтом
            outColor += inTexture.read(pixCoord, readLod).rgb * gaussianWeights[i + 2];
        }
        
        // Сохраняем значения
        outTexture.write(half4(outColor, 1.0), gid, writeLod);
    }
}

// Горизонтальный проход
kernel void gaussianblurHorizontal(texture2d<half, access::read> inTexture [[texture(0)]],    // Входная текстура
                                   texture2d<half, access::write> outTexture [[texture(1)]],  // Выходная текстура
                                   constant uint& readLod [[buffer(0)]],                      // Уровень мипмапов входной текстуры
                                   constant uint& writeLod [[buffer(1)]],                     // Уровень мипмапов выходной текстуры
                                   uint2 gid [[thread_position_in_grid]]) {                   // Позиция в сетке
    // Запускаем блюр
    gaussianblur(inTexture, outTexture, readLod, writeLod, int2(1, 0), gid);
}

// Вертикальный проход
kernel void gaussianblurVertical(texture2d<half, access::read> inTexture [[texture(0)]],    // Входная текстура
                                 texture2d<half, access::write> outTexture [[texture(1)]],  // Выходная текстура
                                 constant uint &readLod [[buffer(0)]],                      // Уровень мипмапов входной текстуры
                                 constant uint &writeLod [[buffer(1)]],                     // Уровень мипмапов выходной текстуры
                                 uint2 gid [[thread_position_in_grid]]) {                   // Позиция в сетке
    // Запускаем блюр
    gaussianblur(inTexture, outTexture, readLod, writeLod, int2(0, 1), gid);
}
