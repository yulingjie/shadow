//
//  Shaders.metal
//  shadow
//
//  Created by lingjieyu on 2022/4/16.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;
#define NUM_SAMPLES 20
typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
    float3 normal [[attribute(VertexAttributeNormal)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float4 worldPosition;
    float2 shadow_uv;
    half  shadow_depth;
    float2 texCoord;
    float3 normal;
} ColorInOut;

float rand_2to1(vector_float2 uv)
{
    const float a = 12.9898;
    const float b = 78.233;
    const float c= 43758.5453;
    float dt = dot(uv.xy, vector_float2(a,b));
    float PI = M_PI_F;
    float sn = modf(dt, PI);
    return fract(sin(sn) * c);
}
float rand_1to1(float x)
{
    return fract(sin(x)* 10000.0);
}


void uniformDiskSamples(const vector_float2 randomSeed,
                         vector_float2 possionSample[])
{
    
    float randNum = rand_2to1(randomSeed);
    float sampleX = rand_1to1(randNum);
    float sampleY = rand_1to1(sampleX);
    
    float angle = sampleX * M_PI_2_F;
    float radius = sqrt(sampleY);
    
    for(int i = 0; i< NUM_SAMPLES; ++i)
    {
        possionSample[i] = vector_float2(radius*cos(angle), radius*sin(angle));
        sampleX = rand_1to1(sampleY);
        sampleY = rand_1to1(sampleX);
        
        angle = sampleX * M_PI_2_F;
        radius = sqrt(sampleY);
    }
}



vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    out.worldPosition = uniforms.modelViewMatrix * position;
    float4 shadow_coord = (uniforms.shadowFlipMatrix * uniforms.shadowOrthographicMatrix * uniforms.shadowModelViewMatrix * position);
    //out.shadow_uv = (float2(-shadow_coord.x,-shadow_coord.y) + float2(1.0,1.0))/2.0;
    out.shadow_uv = shadow_coord.xy;
    out.shadow_depth = half(shadow_coord.z);
    return out;
}
vertex ColorInOut shadow_vertex(Vertex in[[stage_in]],
                                constant Uniforms & uniforms[[buffer(BufferIndexUniforms)]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.shadowOrthographicMatrix * uniforms.shadowModelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    
    return out;
}
fragment float4 fragmentShader_Normal(ColorInOut in[[stage_in]],
                               constant Uniforms & uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d<half> colorMap [[texture(AAPLTextureIndexBaseColor)]],
                               device AAPLPointLight * light_data [[buffer(BufferIndexLightsData)]])
{
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
   
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);
    
  
    return float4(colorSample);
}
float PCF(texture2d<half> shadowMap, vector_float2 shadow_uv, float shadow_depth)
{
    constexpr sampler shadowSampler(coord::normalized, filter::linear, mip_filter::none,address::clamp_to_edge);
    vector_float2 possionSample[NUM_SAMPLES];
    uniformDiskSamples(shadow_uv, possionSample);
    float visibility = 0.0f;
    int totalNum = NUM_SAMPLES;
    for(int i = 0; i < totalNum; ++i)
    {
        vector_float2 uv = shadow_uv + possionSample[i]/ 70.0f;
        half4 shadowSample = shadowMap.sample(shadowSampler,uv);
        if(shadowSample.z >= shadow_depth - 0.015)
        {
            visibility += 1.0f;
        }
    }
    visibility /= totalNum;
    return visibility;
}
float NormalShadowMap(texture2d<half> shadowMap, vector_float2 shadow_uv, float shadow_depth)
{
    constexpr sampler shadowSampler(coord::normalized, filter::linear, mip_filter::none,address::clamp_to_edge);
    float visibility = 1.0;
    half4 shadowSample = shadowMap.sample(shadowSampler, shadow_uv);
    
   
    if(shadowSample.z < shadow_depth -0.0015)
    {
        visibility = 0.0;
    }
    return visibility;
}
fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(AAPLTextureIndexBaseColor) ]],
                               device AAPLPointLight *light_data [[buffer(BufferIndexLightsData)]],
                               texture2d<half> shadowMap [[texture(AAPLTextureIndexShadowMap)]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
  
    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
   
    float visibility = PCF(shadowMap, in.shadow_uv, in.shadow_depth);
  
    float3 color = float3(colorSample.xyz);
    
    float3 ambient = 0.05 * color;
    
    device AAPLPointLight &light = light_data[0];
    float3 fragPos = float3(in.worldPosition.xyz);
    float3 lightPos = float3(light.lightPosition.xyz);
    
    float3 lightDir = normalize(lightPos - fragPos);
    
    float3 normal = normalize(in.normal);
    
    float diff = max(dot(lightDir, normal), 0.0);
   
    float len = length(lightPos - fragPos);
    float light_atten_coff = light.lightIntensity / len;
    
   // float3 diffuse = diff * light_atten_coff * color;
    float3 diffuse = diff * light_atten_coff * color;
   
    float3 viewDir = normalize(uniforms.uCameraPos - fragPos);
    
    float spec = 0.0f;
    float3 reflectDir = reflect(-lightDir, normal);
    spec = pow(max(dot(viewDir, reflectDir),0.0), 35.0);
    
    float3 specular = uniforms.uKs * light_atten_coff * spec;
    
    //return float4(visibility,visibility,visibility,1.0);
    //return float4(ambient + diffuse + specular, 1.0);
    return float4(pow((ambient + diffuse * visibility + specular * visibility), float3(1.0/2.2)),1.0);
    
}


struct TexturePipelineRasterizerData
{
    float4 position[[position]];
    float2 texcoord;
};
vertex TexturePipelineRasterizerData textureVertexShader(const uint vertexID[[vertex_id]],
                                                         const device AAPLTextureVertex * vertices[[buffer(AAPLVertexIndexVertices)]],
                                                         constant float &aspectRatio[[buffer(AAPLVertexIndexAspectRatio)]])
{
    TexturePipelineRasterizerData out;
    out.position = float4(0.0, 0.0, 0.0, 1.0);
    out.position.x = vertices[vertexID].position.x * aspectRatio;
    out.position.y = vertices[vertexID].position.y;
    
    out.texcoord = vertices[vertexID].texcoord;
    return out;
}
fragment float4 textureFragmentShader(TexturePipelineRasterizerData in [[stage_in]],
                                      texture2d<float> texture[[texture(AAPLTextureIndexColor)]])
{
    sampler simpleSampler;
    
    float4 colorSample = texture.sample(simpleSampler, in.texcoord);
    
    return colorSample;
}


