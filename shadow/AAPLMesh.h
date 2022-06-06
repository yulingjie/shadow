//
//  AAPLMesh.h
//  shadow
//
//  Created by lingjieyu on 2022/4/24.
//
@import Foundation;
@import MetalKit;
@import simd;

#ifndef AAPLMesh_h
#define AAPLMesh_h

@interface AAPLSubmesh: NSObject;

@property (nonatomic, readonly, nonnull) MTKSubmesh* metalKitSubmesh;

@property (nonatomic, readonly, nonnull) NSArray<id<MTLTexture>> * textures;

@end

@interface AAPLMesh : NSObject

+ (nullable NSArray<AAPLMesh*> *) newMeshesFromURL: (nonnull NSURL*) url
                            modelIOVertexDesriptor: (nonnull MDLVertexDescriptor*) vertexDescriptor
                                        metalDeice: (nonnull id<MTLDevice>) device
                                             error: (NSError * __nullable * __nullable) errror;

@property (nonatomic, readonly, nonnull) MTKMesh * metalKitMesh;

@property (nonatomic, readonly, nonnull) NSArray<AAPLSubmesh*> *submeshes;
@end

#endif /* AAPLMesh_h */
