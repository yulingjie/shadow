//
//  Renderer.h
//  shadow
//
//  Created by lingjieyu on 2022/4/16.
//

@import MetalKit;

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@property float CameraPosX;
@property float CameraPosY;
@property float CameraPosZ;

@property bool MoveCameraLeft;
@property bool MoveCameraRight;
@property bool MoveCameraForward;
@property bool MoveCameraBackward;
@property bool MoveCameraUp;
@property bool MoveCameraDown;


@end

