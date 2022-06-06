//
//  Renderer.m
//  shadow
//
//  Created by lingjieyu on 2022/4/16.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>

#import "Renderer.h"
#import "AAPLMesh.h"
#import "AAPLMathUtilities.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"

static const NSUInteger kMaxBuffersInFlight = 3;

static const size_t kAlignedUniformsSize = (sizeof(Uniforms) & ~0xFF) + 0x100;

@implementation Renderer
{
    dispatch_semaphore_t _inFlightSemaphore;
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;

    id <MTLBuffer> _dynamicUniformBuffer;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    id <MTLTexture> _colorMap;
    MTLVertexDescriptor *_mtlVertexDescriptor;

    uint32_t _uniformBufferOffset;

    uint8_t _uniformBufferIndex;

    void* _uniformBufferAddress;

    matrix_float4x4 _projectionMatrix;

    float _rotation;

    MTKMesh *_mesh;
    NSArray<AAPLMesh*> *_meshes;
    
    id<MTLBuffer> _lightsData;
    
    float _previousTime;
    float _deltaTime;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        _device = view.device;
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        [self _loadMetalWithView:view];
        [self _loadAssets];
    }

    return self;
}

- (void)_loadMetalWithView:(nonnull MTKView *)view;
{
    /// Load Metal state objects and initialize renderer dependent view properties

    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    view.sampleCount = 1;

    _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];

    _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;

    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;
    
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].format = MTLVertexFormatHalf4;
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].offset = 8;
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].bufferIndex = BufferIndexMeshGenerics;

    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;

    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 16;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;

    
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = view.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;

    NSError *error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState)
    {
        NSLog(@"Failed to create pipeline state, error %@", error);
    }

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    NSUInteger uniformBufferSize = kAlignedUniformsSize ;

    _dynamicUniformBuffer = [_device newBufferWithLength:uniformBufferSize
                                                 options:MTLResourceStorageModeShared];

    _dynamicUniformBuffer.label = @"UniformBuffer";

    _commandQueue = [_device newCommandQueue];
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    
    /// Per frame updates here
    ///
    _uniformBufferOffset = kAlignedUniformsSize * _uniformBufferIndex;

    _uniformBufferAddress = ((uint8_t*)_dynamicUniformBuffer.contents) + _uniformBufferOffset;
    
    {
        float speed =30.0f;
        if(_MoveCameraLeft)
        {
            _CameraPosX -= _deltaTime * speed;
        }
        if(_MoveCameraRight)
        {
            _CameraPosX += _deltaTime * speed;
        }
        if(_MoveCameraForward)
        {
            _CameraPosZ -= _deltaTime * speed;
        }
        if(_MoveCameraBackward)
        {
            _CameraPosZ += _deltaTime * speed;
        }
        if(_MoveCameraUp)
        {
            _CameraPosY += _deltaTime * speed;
        }
        if(_MoveCameraDown)
        {
            _CameraPosY -= _deltaTime * speed;
        }
        Uniforms * uniforms = (Uniforms*)_uniformBufferAddress;

        uniforms->projectionMatrix = _projectionMatrix;

        vector_float3 rotationAxis = {0, 0, 1};
       // matrix_float4x4 modelMatrix = matrix4x4_rotation(_rotation, rotationAxis);
        matrix_float4x4 modelMatrix = matrix4x4_identity();
        matrix_float4x4 viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0);
        
        uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
        float range = 5.0f;
      //  vector_float3 cameraPos = {(_CameraPosX - 0.5f) * range,
      //      (_CameraPosY - 0.5f) * range,
      //      (_CameraPosZ - 0.5f) * range};
        vector_float3 cameraPos = {_CameraPosX, _CameraPosY, _CameraPosZ };
        //vector_float3 targetPos = cameraPos + (vector_float3){0,0,-1};
        vector_float3 targetPos = (vector_float3){0,-5,-5} + cameraPos;
        vector_float3 up = {0,1, 0};
        viewMatrix = matrix_look_at_right_hand(cameraPos, targetPos, up);
        
        uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
        uniforms->uCameraPos = cameraPos;
        uniforms->uKs = (vector_float3){0.05, 0.05, 0.05};
        uniforms->uKd = (vector_float3){0, 0, 0};
    }
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

  
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
        
        _deltaTime = buffer.GPUEndTime - buffer.GPUStartTime;
          
    }];
    MTLRenderPassDescriptor * drawableRenderPassDescriptor = view.currentRenderPassDescriptor;
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:drawableRenderPassDescriptor];
    renderEncoder.label = @"Drawable Render Pass";
    
    [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setDepthStencilState:_depthState];
    [renderEncoder setRenderPipelineState:_pipelineState];
    
    [renderEncoder setVertexBuffer:_dynamicUniformBuffer offset:_uniformBufferOffset atIndex:BufferIndexUniforms];
    
    [renderEncoder setFragmentBuffer:_lightsData offset:0 atIndex:BufferIndexLightsData];
    [renderEncoder setFragmentBuffer:_dynamicUniformBuffer offset:0 atIndex:BufferIndexUniforms];
    
    [self drawMeshes:renderEncoder];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    
    [commandBuffer commit];
   
}

- (void)_loadAssets
{
    /// Load assets into metal objects

    NSError *error;
 
    MDLVertexDescriptor *mdlVertexDescriptor =
    MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

    mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[VertexAttributeNormal].name = MDLVertexAttributeNormal;

    NSMutableArray<AAPLMesh*>* mutableMeshes = [[NSMutableArray alloc] init];
    {
        NSURL* modelFileURL = [[NSBundle mainBundle] URLForResource:@"mari.obj" withExtension:nil];
        
        NSAssert(modelFileURL, @"Could not find model (%@) file in bundle", modelFileURL.absoluteString);
        
        
        
     
        NSArray<AAPLMesh*> *meshes = [AAPLMesh newMeshesFromURL:modelFileURL
                                        modelIOVertexDesriptor:mdlVertexDescriptor
                                                    metalDeice:_device
                                                         error:&error];
        
        NSAssert(meshes, @"Could not find model (%@) file in bundle", error);
        [mutableMeshes addObjectsFromArray:meshes];
    }
    {
        NSURL* modelFileURL = [[NSBundle mainBundle] URLForResource:@"floor.obj" withExtension:nil];
        
        NSAssert(modelFileURL, @"Could not find model (%@) file in bundle", modelFileURL.absoluteString);
        
        NSArray<AAPLMesh*> *meshes = [AAPLMesh newMeshesFromURL:modelFileURL modelIOVertexDesriptor:mdlVertexDescriptor metalDeice:_device error:&error];
        NSAssert(meshes, @"Could not find model (%@) file in bundle",error);
        [mutableMeshes addObjectsFromArray:meshes];
       
    }
    _meshes = [mutableMeshes copy];
    
    
    _lightsData = [_device newBufferWithLength:sizeof(AAPLPointLight) options:0];
    _lightsData.label = @"LightData";
    NSAssert(_lightsData, @"Could not create lights data buffer");
    
    {
        AAPLPointLight *light_data = (AAPLPointLight*) _lightsData.contents;
        
        srandom(0x134e5348);
        float distance = random_float(14,26);
        //float height = random_float(140,150);
        float height = 10.0f;
        float angle = random_float(0,M_PI * 2);
       // light_data->lightPosition = (vector_float3){
       //     distance * sinf(angle), height, distance * cosf(angle)
       // };
        light_data->lightPosition = (vector_float3){3,3,0};
        light_data->lightIntensity = random_float(2.5,5);
        light_data->lightColor = (vector_float3){1,1,1};
    }
}

- (void)drawMeshes:(id<MTLRenderCommandEncoder>)renderEncoder
{
    for(__unsafe_unretained AAPLMesh * mesh in _meshes)
    {
        __unsafe_unretained MTKMesh *metalKitMesh = mesh.metalKitMesh;
        
        for(NSUInteger bufferIndex = 0; bufferIndex < metalKitMesh.vertexBuffers.count; bufferIndex++)
        {
            __unsafe_unretained MTKMeshBuffer * vertexBuffer = metalKitMesh.vertexBuffers[bufferIndex];
            if((NSNull*) vertexBuffer != [NSNull null])
            {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset: vertexBuffer.offset
                                       atIndex:bufferIndex];
                
            }
        }
        for(AAPLSubmesh * submesh in mesh.submeshes)
        {
            MTKSubmesh *metalKitSubmesh = submesh.metalKitSubmesh;
            id<MTLTexture> texture = submesh.textures[AAPLTextureIndexBaseColor];
            
            
            [renderEncoder setFragmentTexture:submesh.textures[AAPLTextureIndexBaseColor] atIndex:AAPLTextureIndexBaseColor];
            
            
            [renderEncoder drawIndexedPrimitives:metalKitSubmesh.primitiveType
                                      indexCount:metalKitSubmesh.indexCount
                                       indexType:metalKitSubmesh.indexType
                                     indexBuffer:metalKitSubmesh.indexBuffer.buffer
                               indexBufferOffset:metalKitSubmesh.indexBuffer.offset];
        }
    }
}
- (void)_updateDynamicBufferState
{
    /// Update the state of our uniform buffers before rendering

    //_uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;

  //  _uniformBufferOffset = kAlignedUniformsSize * _uniformBufferIndex;

    _uniformBufferAddress = ((uint8_t*)_dynamicUniformBuffer.contents) ;//+ _uniformBufferOffset;
}

- (void)_updateGameState
{
    /// Update any game state before encoding renderint commands to our drawable

   

    //_rotation += .01;
}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    /// Respond to drawable size or orientation changes here

    float aspect = size.width / (float)size.height;
    _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

#pragma mark Matrix Math Utilities



@end