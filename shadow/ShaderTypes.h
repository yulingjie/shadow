//
//  ShaderTypes.h
//  shadow
//
//  Created by lingjieyu on 2022/4/16.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2,
    BufferIndexLightsData    = 3,
};

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
    VertexAttributeNormal    = 2,
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    
    // binn
    vector_float3 uKd;
    vector_float3 uKs;
    vector_float3 uCameraPos;
} Uniforms;

typedef struct
{
    vector_float3 lightColor;
    vector_float3 lightPosition;
    float lightIntensity;
    
    
}AAPLPointLight;
typedef enum AAPLTextureIndices
{
    AAPLTextureIndexBaseColor = 0,
    AAPLTextureIndexSpecular  = 1,
    AAPLTextureIndexNormal    = 2,
    
    AAPLNumTextureIndices
} AAPLTextureIndices;



#endif /* ShaderTypes_h */

