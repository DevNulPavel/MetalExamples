/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Shader functions for the Game of Life sample. Define the core of the GPU-based simulation
 and describe how to draw the current game state to the screen
 */

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Набор векторов соседей конкретной точки
constant float2 kNeighborDirections[] = {
    float2(-1, -1), float2(-1, 0), float2(-1, 1),
    float2( 0, -1), /*  center  */ float2( 0, 1),
    float2( 1, -1), float2( 1, 0), float2( 1, 1),
};

// Likelihood that a random cell will become alive when interaction happens at an adjacent cell
constant float kSpawnProbability = 0.8;

// Константы, обозначающие живую ячейку и конченую
constant int kCellValueAlive = 0;
constant int kCellValueDead = 255;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef struct {
    packed_float2 position;
    packed_float2 texCoords;
} VertexIn;

typedef struct {
    float4 position [[position]];
    float2 texCoords;
} FragmentVertex;

// Шейдеры для отрисовки
vertex FragmentVertex lighting_vertex(device VertexIn *vertexArray [[buffer(0)]],
                                      uint vertexIndex [[vertex_id]]) {
    FragmentVertex out;
    out.position = float4(vertexArray[vertexIndex].position, 0.0, 1.0);
    out.texCoords = vertexArray[vertexIndex].texCoords;
    return out;
}

fragment half4 lighting_fragment(FragmentVertex in [[stage_in]],
                                 texture2d<uint, access::sample> gameGrid [[texture(0)]],
                                 texture2d<half, access::sample> colorMap [[texture(1)]]) {
    
    constexpr sampler nearestSampler(coord::normalized, filter::nearest);
    
    // Значение в сетке жизни в виде float
    float deadTime = gameGrid.sample(nearestSampler, in.texCoords).r / 255.0;
    
    // Конвертируем жизнеспособность ячейки в конкретный цвет с помощью карты
    half4 color = colorMap.sample(nearestSampler, float2(deadTime, 0));
    return color;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Импровизированная функция получения рандомного значения
static float hash(int2 v){
    return fract(sin(dot(float2(v), float2(12.9898, 78.233))) * 43758.5453);
}

// https://developer.apple.com/documentation/metal/compute_processing/about_threads_and_threadgroups
// Вычислительная функция, которая активирует соседей в текстуре
kernel void activate_random_neighbors(texture2d<uint, access::write> writeTexture [[texture(0)]],
                                      constant uint2* cellPositions [[buffer(0)]], // Буффер с координатами пикселей
                                      ushort2 gridPosition [[thread_position_in_grid]]) {   // Ширина вычислительной сетки равна количеству точек вычисления
    int cellPosIndex = gridPosition.x;
    int2 cellPosition = int2(cellPositions[cellPosIndex]);
    // Итерируемся по соседям конкретной точки
    for (ushort i = 0; i < 8; ++i) {
        // Вычисляем позицию конкретной ячейки
        int2 neighborPosition = cellPosition + int2(kNeighborDirections[i]);
        // Получаем конкретное случайное значение
        ushort cellValue = (hash(neighborPosition) < kSpawnProbability) ? kCellValueAlive : kCellValueDead;
        // Пишем полученое значение в текстуру
        writeTexture.write(cellValue, uint2(neighborPosition));
    }
}

// https://developer.apple.com/documentation/metal/compute_processing/about_threads_and_threadgroups
kernel void game_of_life(texture2d<uint, access::sample> readTexture [[texture(0)]],
                         texture2d<uint, access::write> writeTexture [[texture(1)]],
                         sampler wrapSampler [[sampler(0)]],
                         ushort2 gridPosition [[thread_position_in_grid]]){ // Координаты пикселя в вычислительной сетке (аналог координат в текстуре)
    // Высота и ширина текстуры
    ushort width = readTexture.get_width();
    ushort height = readTexture.get_height();
    float2 bounds(width, height);
    // Позиция в сетке
    float2 position = float2(gridPosition);
    
    // Не выполняем обновление или запись, если мы вылезли за границы текстуры
    if((gridPosition.x < width) && (gridPosition.y < height)) {
        // Подсчитываем количество соседних ячеек, которые являются живыми
        ushort neighbors = 0;
        for (int i = 0; i < 8; ++i) {
            // Sample from the current game state texture, wrapping around edges if necessary
            float2 coords = (position + kNeighborDirections[i] + float2(0.5)) / bounds;
            ushort cellValue = readTexture.sample(wrapSampler, coords).r;
            neighbors += (cellValue == kCellValueAlive) ? 1 : 0;
        }
        
        // Получаем текущее значение в буффере
        ushort deadFrames = readTexture.read(uint2(position)).r;
        
        /*
         The rules of the Game of Life:
         Any live cell with fewer than two live neighbours dies, as if caused by under-population.
         Any live cell with two or three live neighbours lives on to the next generation.
         Any live cell with more than three live neighbours dies, as if by over-population.
         Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
         */
        bool alive = (deadFrames == 0 && (neighbors == 2 || neighbors == 3)) || (deadFrames > 0 && (neighbors == 3));
        
        // Если мы живы, оставляем значение, иначе - увеличиваем количество которых надо мочить??
        ushort cellValue = alive ? kCellValueAlive : deadFrames + 1;
        
        // Записываем полученное значение в конкретный пиксель
        writeTexture.write(cellValue, uint2(position));
    }
}

