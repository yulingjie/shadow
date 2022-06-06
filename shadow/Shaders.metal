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
    float2 texCoord;
    float3 normal;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    out.worldPosition = uniforms.modelViewMatrix * position;
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
fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(AAPLTextureIndexBaseColor) ]],
                               device AAPLPointLight *light_data [[buffer(BufferIndexLightsData)]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
  
    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
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
    
    return float4(pow((ambient + diffuse + specular), float3(1.0/2.2)),1.0);
    
}
