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
    float2 shadow_uv;
    half  shadow_depth;
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
    constexpr sampler shadowSampler(coord::normalized,
                                    filter::linear,
                                    mip_filter::none,
                                    address::clamp_to_edge);
    float visibility = 1.0;
    half4 shadowSample = shadowMap.sample(shadowSampler, in.shadow_uv);
    
   
    if(shadowSample.z < in.shadow_depth -0.0015)
    {
        visibility = 0.0;
    }
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
