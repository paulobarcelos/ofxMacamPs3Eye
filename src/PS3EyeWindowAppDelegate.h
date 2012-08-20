#import <Cocoa/Cocoa.h>
#import "MyCameraCentral.h"

#define PS3EYE_DELEGATE_BUFFER_SIZE 2

@interface PS3EyeWindowAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	NSImage* image;
	NSBitmapImageRep* imageRep;
	NSImageView* imageView;
	MyCameraCentral* central;
	MyCameraDriver* driver;
	
	unsigned char * buffer[PS3EYE_DELEGATE_BUFFER_SIZE];
	int bufferIndex;
	int bufferNextIndex;
	
	struct timeval currentTime;
	
	BOOL cameraGrabbing;
	CameraResolution cameraResolution;
	int cameraWidth;
	int cameraHeight;
	int cameraFPS;
	
	BOOL frameNew;
	
	float realFps;
}
- (BOOL)connectTo:(unsigned long)cid;
- (void)useWidth:(int)w useHeight:(int)h useFps:(int)f;
- (BOOL)startGrabbing;
- (BOOL)isFrameNew;
- (unsigned char *) imageBuffer;
- (void)shutdown;

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
@property (readonly) float realFps;


@end
