#import <Cocoa/Cocoa.h>
#import "MyCameraCentral.h"

@interface PS3EyeWindowAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	NSImage* image;
	NSBitmapImageRep* imageRep;
	NSImageView* imageView;
	MyCameraCentral* central;
	MyCameraDriver* driver;
	
	BOOL cameraGrabbing;
	CameraResolution cameraResolution;
	int cameraWidth;
	int cameraHeight;
	int cameraFPS;
	
	BOOL frameNew;
}
- (void)connectTo:(unsigned long)cid;
- (void)useWidth:(int)w useHeight:(int)h useFps:(int)f;
- (void)startGrabbing;
- (void)shutdown;
- (BOOL)isFrameNew;

//delegate calls from camera central
- (void)cameraDetected:(unsigned long)cid;
//delegate calls from camera driver
- (void)imageReady:(id)cam;
//- (void)cameraHasShutDown:(id)cam;
//- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt;
- (void) updateStatus:(NSString *)status fpsDisplay:(float)fpsDisplay fpsReceived:(float)fpsReceived;

@property (readonly) NSWindow* window;
@property (readonly) MyCameraCentral* central;
@property (readonly) MyCameraDriver* driver;


@end
