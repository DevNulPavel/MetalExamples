#ifndef AAPLShaderTypes_h
#define AAPLShaderTypes_h

#include <simd/simd.h>

// Индексы общих буфферов отрисовки, общие данные на CPU и GPU
typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,	// Индекс буффера вершин
    AAPLVertexInputIndexViewportSize = 1,	// Индекс буффера вьюпорта (юниформ)
} AAPLVertexInputIndex;

// Структура общая для шейдера, определяющая структуру данных вершин
typedef struct
{
    // Позиция в пиксельных координатах (0,0), (100,100)
    vector_float2 position;

    // Цвет
    vector_float4 color;
} AAPLVertex;

#endif
