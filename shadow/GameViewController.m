//
//  GameViewController.m
//  shadow
//
//  Created by lingjieyu on 2022/4/16.
//

#import "GameViewController.h"
#import "Renderer.h"
#include <Carbon/Carbon.h>

@implementation GameViewController
{
    MTKView *_view;

    Renderer *_renderer;
    
    __weak IBOutlet NSSlider * _cameraPosXSlider;
    __weak IBOutlet NSTextField * _cameraPosXLabel;
    __weak IBOutlet NSSlider * _cameraPosYSlider;
    __weak IBOutlet NSTextField * _cameraPosYLabel;
    __weak IBOutlet NSSlider * _cameraPosZSlider;
    __weak IBOutlet NSTextField * _cameraPosZLabel;
}

- (IBAction)setCameraPosX: (NSSlider *)slider
{
    //_renderer.CameraPosX = slider.floatValue;
    //_cameraPosXLabel.stringValue = [NSString stringWithFormat:@"x: %.2f",_renderer.CameraPosX];
   
}
- (IBAction)setCameraPosY:(NSSlider *)slider
{
   // _renderer.CameraPosY = slider.floatValue;
   // _cameraPosYLabel.stringValue = [NSString stringWithFormat:@"y: %.2f", _renderer.CameraPosY];
}
- (IBAction)setCameraPosZ:(NSSlider *)slider
{
   // _renderer.CameraPosZ = slider.floatValue;
   // _cameraPosZLabel.stringValue = [NSString stringWithFormat:@"z: %.2f", _renderer.CameraPosZ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (MTKView *)self.view;

    _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

    _renderer = [[Renderer alloc] initWithMetalKitView:_view];

    [_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];

    _view.delegate = _renderer;
    
    
    
    _renderer.CameraPosX = 0;
    _cameraPosXLabel.stringValue = [NSString stringWithFormat:@"x: %.2f", _renderer.CameraPosX];
    [_cameraPosXLabel setTextColor:[NSColor whiteColor]];
    
    _renderer.CameraPosY = 5;
    _cameraPosYLabel.stringValue = [NSString stringWithFormat:@"y: %.2f", _renderer.CameraPosY];
    [_cameraPosYLabel setTextColor:[NSColor whiteColor]];
    
    _renderer.CameraPosZ = 5;
    _cameraPosZLabel.stringValue = [NSString stringWithFormat:@"z: %.2f", _renderer.CameraPosZ];
    [_cameraPosZLabel setTextColor:[NSColor whiteColor]];
    
}
- (void) viewDidAppear
{
    [_view.window makeFirstResponder:self];
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void) keyDown:(NSEvent *)event

{
    NSLog(@"NSEvent (%d)", event.keyCode);
    switch(event.keyCode)
    {
        case kVK_ANSI_A:
        {
            _renderer.MoveCameraLeft = true;
            break;
        }
        case kVK_ANSI_D:
        {
            _renderer.MoveCameraRight = true;
            break;
        }
        case kVK_ANSI_W:
        {
            _renderer.MoveCameraForward = true;
            break;
        }
        case kVK_ANSI_S:
        {
            _renderer.MoveCameraBackward = true;
            break;
        }
        case kVK_ANSI_Q:
        {
            _renderer.MoveCameraUp = true;
            break;
        }
        case kVK_ANSI_E:
        {
            _renderer.MoveCameraDown = true;
            break;
        }
    }
    
    _cameraPosXLabel.stringValue = [NSString stringWithFormat:@"x: %.2f", _renderer.CameraPosX];
    [_cameraPosXLabel setTextColor:[NSColor whiteColor]];
    
    
    _cameraPosYLabel.stringValue = [NSString stringWithFormat:@"y: %.2f", _renderer.CameraPosY];
    [_cameraPosYLabel setTextColor:[NSColor whiteColor]];
    
   
    _cameraPosZLabel.stringValue = [NSString stringWithFormat:@"z: %.2f", _renderer.CameraPosZ];
    [_cameraPosZLabel setTextColor:[NSColor whiteColor]];
    
}
- (void) keyUp:(NSEvent *)event
{
    NSLog(@"NSEvent up");
    _renderer.MoveCameraLeft = false;
    _renderer.MoveCameraUp = false;
    _renderer.MoveCameraDown = false;
    _renderer.MoveCameraRight = false;
    _renderer.MoveCameraForward = false;
    _renderer.MoveCameraBackward = false;
    
}

@end
