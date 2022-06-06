//
//  AAPLMesh.m
//  shadow
//
//  Created by lingjieyu on 2022/4/24.
//
@import MetalKit;
@import ModelIO;

#import "AAPLMesh.h"
#import "ShaderTypes.h"

#import <Foundation/Foundation.h>


@implementation  AAPLSubmesh{
    NSMutableArray<id<MTLTexture>> *_textures;
}

@synthesize  textures = _textures;

+ (nonnull id<MTLTexture>) createMetalTextureFromMaterial: (nonnull MDLMaterial*) material
                                  modelIOMaterialSemantic: (MDLMaterialSemantic) materialSemantic
                                    metalKitTextureLoader: (nonnull MTKTextureLoader*) textureLoader
{
    id<MTLTexture> texture;
    NSArray<MDLMaterialProperty*> *propertiesWithSemantic = [material propertiesWithSemantic:materialSemantic];
    
    for(MDLMaterialProperty * property in propertiesWithSemantic)
    {
        if(property.type == MDLMaterialPropertyTypeString || property.type == MDLMaterialPropertyTypeURL)
        {
            NSDictionary * textureLoaderOptions = @{
                MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
                MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
                MTKTextureLoaderOptionSRGB : @(NO)
            };
            NSURL * url = property.URLValue;
            NSMutableString * URLString = nil;
            if(property.type == MDLMaterialPropertyTypeURL){
                URLString = [[NSMutableString alloc] initWithString:[url absoluteString]];
            }
            else{
                URLString = [[NSMutableString alloc] initWithString:@"file://"];
                [URLString appendString:property.stringValue];
            }
            
            NSURL* textureURL = [NSURL URLWithString:URLString];
            texture = [textureLoader newTextureWithContentsOfURL:textureURL options:textureLoaderOptions error:nil];
            
            if(texture){
                return texture;
            }
            
            NSString * lastComponent = [[URLString componentsSeparatedByString:@"/"] lastObject];
            texture = [textureLoader newTextureWithName:lastComponent scaleFactor:0 bundle:nil options:textureLoaderOptions error:nil];
            if(texture){
                return texture;
            }
            
            [NSException raise:@"Texture data for material property not found"
                        format:@"Requested material property semantic: %lu string:%@",
             materialSemantic, property.stringValue];
        }
    }
    [NSException raise:@"No appropriate material property from which to create texture"
                format:@"Requested material property semantic: %lu", materialSemantic];
    return nil;
}

- (nonnull instancetype) initWithModelIOSubmesh: (nonnull MDLSubmesh*) modelIOSubmesh
                                metalKitSubmesh:(nonnull MTKSubmesh*) metalKitSubmesh
                          metalKitTextureLoader:(nonnull MTKTextureLoader *)textureLoader
{
    self = [super init];
    if(self)
    {
        _metalKitSubmesh = metalKitSubmesh;
        _textures = [[NSMutableArray alloc] initWithCapacity:AAPLNumTextureIndices];
        for(NSUInteger shaderIndex = 0; shaderIndex < AAPLNumTextureIndices; shaderIndex ++)
        {
            [_textures addObject:(id<MTLTexture>)[NSNull null]];
        }
        @try {
            _textures[AAPLTextureIndexBaseColor] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticBaseColor metalKitTextureLoader:textureLoader];
        } @catch (NSException *exception) {
            NSLog(@"Failed to Load AAPLTextureIndexBaseColor, error %@", [exception description]);
        } @finally {
            
        }
        @try{
            _textures[AAPLTextureIndexSpecular] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticSpecular metalKitTextureLoader:textureLoader];
        } @catch (NSException * exception){
            NSLog(@"Failed to Load AAPLTextureIndexSpecular, error %@", [exception description]);
        } @finally{
            
        }
        @try{
            _textures[AAPLTextureIndexNormal] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticTangentSpaceNormal metalKitTextureLoader:textureLoader];
        } @catch (NSException * exception){
            NSLog(@"Failed to Load AAPLTextureIndexNormal, error %@", [exception description]);
        } @finally{
            
        }
      
        
    }
    return self;
}

@end

@implementation  AAPLMesh{
    NSMutableArray<AAPLSubmesh *> *_submeshes;
}
@synthesize  submeshes = _submeshes;

- (nonnull instancetype) initWithModelIOMesh: (nonnull MDLMesh*) modelIOMesh
                     modelIOVertexDescriptor: (nonnull MDLVertexDescriptor*) vertexDescriptor
                       metalKitTextureLoader: (nonnull MTKTextureLoader *) textureLoader
                                 metalDevice: (nonnull id<MTLDevice>) device
                                       error: (NSError *__nullable * __nullable)error
{
    self = [super init];
    if(!self){
        return nil;
    }
    // Have ModelIO create the tangents from mesh texture coordinates and normals
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                              normalAttributeNamed:MDLVertexAttributeNormal
                                             tangentAttributeNamed:MDLVertexAttributeTangent];
    // Have ModelIO create bitangents from mesh texture coordinates and the newly created tangents
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                             tangentAttributeNamed:MDLVertexAttributeTangent
                                           bitangentAttributeNamed:MDLVertexAttributeBitangent];
    
    modelIOMesh.vertexDescriptor = vertexDescriptor;
    
    MTKMesh* metalKitMesh = [[MTKMesh alloc] initWithMesh: modelIOMesh
                                                   device:device
                                                    error:error];
    _metalKitMesh = metalKitMesh;
    
    assert(metalKitMesh.submeshes.count == modelIOMesh.submeshes.count);
    
    _submeshes = [[NSMutableArray alloc] initWithCapacity:metalKitMesh.submeshes.count];
    
    for(NSUInteger index = 0; index < metalKitMesh.submeshes.count; ++index)
    {
        AAPLSubmesh * submesh = [[AAPLSubmesh alloc] initWithModelIOSubmesh:modelIOMesh.submeshes[index] metalKitSubmesh:metalKitMesh.submeshes[index] metalKitTextureLoader:textureLoader];
        
        [_submeshes addObject:submesh];
    }
    return self;
    
}

+ (NSArray<AAPLMesh*> *) newMeshesFromObject:(nonnull MDLObject*) object
                     modelIOVertexDescriptor:(nonnull MDLVertexDescriptor*) vertexDescriptor
                       metalKitTextureLoader:(nonnull MTKTextureLoader *) textureLoader
                                 metalDevice:(nonnull id<MTLDevice>) device
                                       error:(NSError * __nullable * __nullable) error
{
    NSMutableArray<AAPLMesh *> *newMeshes = [[NSMutableArray alloc] init];
    
    if([object isKindOfClass:[MDLMesh class]])
    {
        MDLMesh * mesh = (MDLMesh*) object;
        AAPLMesh *newMesh = [[AAPLMesh alloc] initWithModelIOMesh:mesh modelIOVertexDescriptor:vertexDescriptor metalKitTextureLoader:textureLoader metalDevice:device error:error];
        
        [newMeshes addObject:newMesh];
    }
    for(MDLObject* child in object.children)
    {
        NSArray<AAPLMesh*> *childMeshes;
        childMeshes = [AAPLMesh newMeshesFromObject:child
                            modelIOVertexDescriptor:vertexDescriptor
                              metalKitTextureLoader:textureLoader
                                        metalDevice:device
                                              error:error];
        [newMeshes addObjectsFromArray:childMeshes];
    }
    return newMeshes;
}

+ (nullable NSArray<AAPLMesh *> *) newMeshesFromURL:(NSURL *)url
                        modelIOVertexDesriptor:(MDLVertexDescriptor *)vertexDescriptor
                                         metalDeice:(id<MTLDevice>)device
                                              error:(NSError * _Nullable __autoreleasing *)error
{
    MTKMeshBufferAllocator * bufferAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    
    MDLAsset * asset = [[MDLAsset alloc] initWithURL:url
                                    vertexDescriptor:nil
                                     bufferAllocator:bufferAllocator];
    NSAssert(asset, @"Failed to open model file with given URL: %@", url.absoluteString);
    
    MTKTextureLoader * textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
    
    NSMutableArray<AAPLMesh*> *newMeshes = [[NSMutableArray alloc] init];
    
    for(MDLObject* object in asset)
    {
        NSArray<AAPLMesh*> *assetMeshes;
        
        assetMeshes = [AAPLMesh newMeshesFromObject:object
                             modelIOVertexDescriptor:vertexDescriptor
                               metalKitTextureLoader:textureLoader
                                         metalDevice:device
                                               error:error];
        [newMeshes addObjectsFromArray:assetMeshes];
    }
    return newMeshes;
}
@end
