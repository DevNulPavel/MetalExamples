#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Константы и общие типы данных для шейдера
#import "AAPLShaderTypes.h"


// Выходная структура данных вершинного шейдера и входная структура данных фрагментного
typedef struct {
    // Спецификатор [[position]] говорит, что данное поле является позицией в пространстве Metal [-1.0, 1.0]
    float4 clipSpacePosition [[position]];

    // Данное поле не имеет никакого спеецификатора типа - поэтому происходит интерполяция значений
    float4 color;

} RasterizerData;

// Vertex Function
vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],	// ID вершины
             					   device AAPLVertex* vertices [[buffer(AAPLVertexInputIndexVertices)]], // Входной буффер под индексом 0
             					   constant vector_uint2* viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]]) // Входной буффер под индексом 1
{
    RasterizerData out;

    // Начальное значение позиции, надо ли???
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);

    // С помощью индекса текущей вершины - получаем непосредственно позицию точки
    float2 pixelSpacePosition = vertices[vertexID].position.xy;

    // Приводим буффер вьюпорта к float2, исходные данные были в uint2
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);

    // Вычисляем позицию в пространстве Metal
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Присваиваем цвет
    out.color = vertices[vertexID].color;

    return out;
}

// Fragment function
fragment float4 fragmentShader(RasterizerData in [[stage_in]]){
    return in.color;
}

