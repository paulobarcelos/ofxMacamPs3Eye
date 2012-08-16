/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id: MyCameraDriver.h,v 1.26 2009/05/01 03:02:41 hxr Exp $
*/

#import <Cocoa/Cocoa.h>
#include <QuickTime/QuickTime.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "sys/time.h"
#include "GlobalDefs.h"
#import "MyCameraInfo.h"

//CameraEvents are Events caused by the camera and propagated to the driver/client in some way. Extend if needed but please coordinate...
typedef enum CameraEvent {
    CameraEventSnapshotButtonDown,
    CameraEventSnapshotButtonUp,
} CameraEvent;

//CameraFeatures are custom feeatures of the camera

typedef enum CameraFeature {
    CameraFeatureInspectorClassName	//A NSString containing the name of a MyCameraInspector subclass. Read-only.
} CameraFeature;



struct code_table
{
	int is_abs;
	int len;
	int val;
};

// Exactly as defined in the USB Video Class standard

typedef enum FlickerType
{
    disableFlicker = 0,
    enableFlicker50Hz = 1,
    enableFlicker60Hz = 2,
} FlickerType;


@interface MyCameraDriver : NSObject 
{
// General stuff
    id delegate;			// The delegate to notify [imageReady], [grabFinished] and [cameraHasShutDown].
    id central;				// The central singleton to indicate [cameraHasShutDown].
    
// USB connection camera interfaces
    IOUSBDeviceInterface ** dev;                // An interface to the device
    IOUSBInterfaceInterface ** controlIntf;     // An interface to the control interface
    IOUSBInterfaceInterface ** streamIntf;      // An interface to the streaming interface (most of the time these are the same!)
    IOUSBConfigurationDescriptorPtr	confDesc;
    int interfaceID;                            // Store the interface version so we know what functions are available
    
    int altInterfacesAvailable;     // For isochronous devices, keep track of the the number of alternate interfaces
    int currentMaxPacketSize;       // Keep track of this to avoid figuring it out unecessarily
    
// Camera settings. 
    float brightness;
    float contrast;
    float saturation;
    float hue;
    float gamma;
    float sharpness;
    float shutter;
    float gain;
    BOOL autoGain;
    BOOL hFlip;
    FlickerType flicker;
    
    CameraResolution resolution;
    WhiteBalanceMode whiteBalanceMode;
    BOOL blackWhiteMode;	// is color or Black and White (greyscale)
    BOOL LEDon;             // is the LED on or off (Philips cameras)
    short fps;
    short compression;		// 0 = uncompressed, higher means more compressed
    BOOL usbReducedBandwidth;   // Reduce the USB bandwidth to accomodate audio, other devices etc.

// Driver states. Sorry, this has changed - the old version was too sensitive to racing conditions. Everything except atomic read access has to be mutexed with stateLock (there is an exception: drivers may unset shouldBeGrabbing from within their internal grabbing and decoding since it's for sure that isGrabbing is set in that situation)
        
    BOOL isStarted;		//If the driver has been started up
    BOOL isGrabbing;		//If the driver is in grabbing state
    BOOL shouldBeGrabbing;	//If the grabbing thread should stop running
    BOOL isShuttingDown;	//If the driver is shutting down and shouldn't accept new grabbing requests
    BOOL isShutDown;		//If the driver has already been down
    BOOL isUSBOK;		//If USB calls to intf and dev are ok. Unset without lock to be as fast as possible
    NSLock* stateLock;		//The Lock to mutex all of this stuff
    
/* Stuff for merging notifications. Init these if you want to use the merging notification forwarders and the client wants notifications on the main thread. This is a good candidate for refacturing... */
    
    BOOL doNotificationsOnMainThread;	//If the client wants main thread calls or accepts other thread notifications
    NSRunLoop* mainThreadRunLoop;
    NSConnection* mainThreadConnection;
    NSConnection* decodingThreadConnection;

/*

Image buffers. There are two sets: lastIamgeBuffer and nextImageBuffer. The client writes the next buffer to fill into nextImageBuffer via [setImageBuffer]. This also sets nextImageBufferSet to true, indicating the driver that image data may be written into it. The driver then writes the next available image into this buffer, copies the properties into lastImageBuffer and unsets nextImageBuffer. The read functions for the client may then read out lastImageBuffer. There is a lock to manage the access to these variables, imageBufferLock. The get functions don't use the lock since they don't change anything. They are only guaranteed to be valid during the [imageReady] notification. Setting nextImageBuffer is locked during the whole procedure of decoding the image. 

*/
        
    unsigned char *	lastImageBuffer;
    short 		    lastImageBufferBPP;
    long 		    lastImageBufferRowBytes;
	struct timeval  lastImageBufferTimeVal;
    
    unsigned char *	nextImageBuffer;
    short 		    nextImageBufferBPP;
    long 		    nextImageBufferRowBytes;
    
    BOOL            nextImageBufferSet;
    NSLock * 		imageBufferLock;
    MyCameraInfo *  cameraInfo;
}

// Get info about the camera specifics - simple mechanism
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
+ (BOOL) isUVC;  // Do the cameras supported by this driver implement the USB Video Class?

// Get info - new mechanism. Overload this one if you have more than one idVendor/idProduct pair

+ (NSArray*) cameraUsbDescriptions;
//Should return an array of dictionaries with keys "idVendor" (NSNumber), "idProduct" (NSNumber) and "name" (NSString). The default implementation creates an array with one entry with values of the above methods.

// get/set camera info
- (MyCameraInfo*) getCameraInfo;
- (void) setCameraInfo:(MyCameraInfo *)info;

//Start/stop
- (id) initWithCentral:(id)c;
- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId;
- (void) shutdown; // shuts the driver down or initiates this procedure. You will receive a [cameraHasShutDown] message.
- (void) stopUsingUSB; //Makes sure no further USB calls to intf and dev are sent.
- (void) dealloc;

//delegate management
- (id) delegate;
- (void) setDelegate:(id)d;
- (void) enableNotifyOnMainThread;	//Has to be enabled before [startupWithUsbLocationId]! Cannot be unset - anymore!
- (void) setCentral:(id)c;		//Don't use unless you know what you're doing!
- (id) central;				//Don't use unless you know what you're doing!

- (BOOL) canSetDisabled;
- (void) setDisabled:(BOOL)disable;
- (BOOL) disabled;

//Camera introspection
- (BOOL) realCamera;	//Returns if the camera is a real image grabber or a dummy
- (BOOL) hasSpecificName; // Returns is the camera has a more specific name (derived from USB connection perhaps)
- (NSString *) getSpecificName;

// Image / camera property get/set: All continuous data in the range [0 .. 1]. Their use should be quite obvious.

// Brightness
- (BOOL) canSetBrightness;
- (float) brightness;
- (void) setBrightness:(float)v;
- (float) brightnessStep;

// Offset -  a hardware-pnly setting
- (BOOL) canSetOffset;
- (float) offset;
- (void) setOffset:(float)v;
- (float) offsetStep;

    // Contrast
- (BOOL) canSetContrast;
- (float) contrast;
- (void) setContrast:(float)v;

// Saturation - colorfulness
- (BOOL) canSetSaturation;
- (float) saturation;
- (void) setSaturation:(float)v;

// Hue
- (BOOL) canSetHue;
- (float) hue;
- (void) setHue:(float)v;

// Gamma value - grey value
- (BOOL) canSetGamma;
- (float) gamma;
- (void) setGamma:(float)v;

// Sharpness value - contour enhancement
- (BOOL) canSetSharpness;
- (float) sharpness;
- (void) setSharpness:(float)v;

// gain - electronic amplification
- (BOOL) canSetGain;
- (float) gain;
- (void) setGain:(float)v;
- (float) gainStep;
- (BOOL) agcDisablesGain;

// Shutter speed
- (BOOL) canSetShutter;
- (float) shutter;
- (void) setShutter:(float)v;
- (float) shutterStep;
- (BOOL) agcDisablesShutter;

// Automatic exposure - will affect shutter and gain
- (BOOL) canSetAutoGain;
- (BOOL) isAutoGain;
- (void) setAutoGain:(BOOL)v;

// LED ON / OFF
- (BOOL) canSetLed;
- (BOOL) isLedOn;
- (void) setLed:(BOOL)v;

// Orientation
- (BOOL) canSetOrientationTo:(OrientationMode) m;
- (OrientationMode) orientation;
- (void) setOrientation:(OrientationMode) m;

// Horizontal flipping
- (BOOL) canSetHFlip;		//Horizontal flipping
- (BOOL) hFlip;
- (void) setHFlip:(BOOL)v;

// Flicker conmtrol
- (BOOL) canSetFlicker;
- (FlickerType) flicker;
- (void) setFlicker:(FlickerType)v;

// Compression
- (short) maxCompression;	//0 = no compression available
- (short) compression;
- (void) setCompression:(short)v;

// Reduced USB bandwidth
- (BOOL) canSetUSBReducedBandwidth;
- (BOOL) usbReducedBandwidth;
- (void) setUSBReducedBandwidth:(BOOL)v;

// White Balance
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode;
- (WhiteBalanceMode) defaultWhiteBalanceMode;
- (WhiteBalanceMode) whiteBalanceMode;
- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode;

// Black & White Mode
- (BOOL) canBlackWhiteMode;
- (BOOL) blackWhiteMode;
- (void) setBlackWhiteMode:(BOOL)newMode;


//Resolution and frame rate
- (short) width;						//Current image width
- (short) height;						//Current image height
- (CameraResolution) resolution;		//Current image predefined format constant
- (short) fps;							//Current frames per second, 0 means fastest possible
- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr;	//Does this combination work?
- (void) setResolution:(CameraResolution)r fps:(short)fr;	//Set a resolution and frame rate

//Resolution and fps negotiation - the default implementation will use [supportsResolution:fps:] to find something.
//Override these if you want to.
- (CameraResolution) findResolutionForWidth:(short)width height:(short) height;	//returns a (hopefully) good native resolution
- (short) findFrameRateForResolution:(CameraResolution)res;	//returns fps < 0 if resolution not supported
- (CameraResolution) defaultResolutionAndRate:(short*)fps;	//Override this to set the startup resolution

//Grabbing
- (BOOL) startGrabbing;					//start async grabbing. Returns if the camera is grabbing
- (BOOL) stopGrabbing;					//Stop async grabbing. Returns if the camera is grabbing
- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb;	//Set next image buffer to fill
- (BOOL) isGrabbing;					// Returns if the camera is grabbing

//Grabbing internal
- (void) decodingThreadWrapper:(id)data;		//Don't subclass this...
- (CameraError) decodingThread;				//Subclass this!

//Grabbing get info
- (unsigned char*) imageBuffer;				//last filled image buffer
- (short) imageBufferBPP;				//last BYTES per pixel
- (long) imageBufferRowBytes;				//last bytes per image row
- (struct timeval) imageBufferTimeVal;

//DSC (Digital Still Camera) management - for cameras that can store media / also operate USB-unplugged
- (BOOL) canStoreMedia;					//If the device supports DSC or similar functions
- (long) numberOfStoredMediaObjects;			//How many images are currently on the camera?
- (NSDictionary*) getStoredMediaObject:(long)idx;	//downloads a media object
//required keys: "type" and "data". Currently handled combinations:
//type		data
//"bitmap"	NSBitmapImageRep object
//"jpeg"	NSData with JPEG (JFIF) file contents

- (BOOL) canGetStoredMediaObjectInfo;	//does the camera support [getStoredMediaObjectInfo:]?
- (NSDictionary*) getStoredMediaObjectInfo:(long)idx;	//gets a media object info
//required fields: type (currently "bitmap","jpeg")
//required fields for type="bitmap" or "jpeg": "width", "height", recommended: "size"

- (BOOL) canDeleteAll;			//Does the camera support [deleteAll]?
- (CameraError) deleteAll;		//Clears the camera media memory

- (BOOL) canDeleteOne;			//Does the camera support [deleteOne:]?
- (CameraError) deleteOne:(long)idx;	//Clears one camera media object

- (BOOL) canDeleteLast;			//Does the camera support [deleteLast]?
- (CameraError) deleteLast;		//Clears the last camera media object

- (BOOL) canCaptureOne;			//Does the camera support [CaptureOne]?
- (CameraError) captureOne;		//Captures one image (or whatever - camera's current setting)


//Camera Custom features
- (BOOL) supportsCameraFeature:(CameraFeature)feature;
- (id) valueOfCameraFeature:(CameraFeature)feature;
- (void) setValue:(id)val ofCameraFeature:(CameraFeature)feature;

/*Note that "notifications" here are not exactly Cocoa notifications. They are delegate methods (the delegate concept matches a bit better to the Cocoa counterpart). But they also notify... */

//Merged Notification forwarders - should be used for notifications from decodingThread
- (void) mergeImageReady;
- (void) mergeGrabFinishedWithError:(CameraError)err;
- (void) mergeCameraHasShutDown;
//There's no mergeCameraEventHappened because most likely you won't call it from decodingThread. Merge yourself.
- (void) mergeCameraEventHappened:(CameraEvent)evt;  // Well. it seems useful now!

//Notification forwarders - should not be called from outside but may be overridden by subclasses
- (void) imageReady:(id)sender;				//sends "notification" to "delegate"
- (void) grabFinished:(id)sender withError:(CameraError)err;	//sends "notification" to "delegate"
- (void) cameraHasShutDown:(id)sender;			//sends "notification" to "delegate"
- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt;	//sends "notification" to "delegate"	

// Camera register functions, need to be defined for each controller
- (int) dumpRegisters;
- (int) getRegister:(UInt16)reg;
- (int) setRegister:(UInt16)reg toValue:(UInt16)val;
- (int) setRegister:(UInt16)reg toValue:(UInt16)val withMask:(UInt16)mask;

//USB tool functions - should be used internally only
- (BOOL) usbCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;//Sends a generic command
- (BOOL) usbGenericCmd:(IOUSBInterfaceInterface**)intf onPipe:(UInt8)pipe BRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;
- (BOOL) usbControlCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;
- (BOOL) usbStreamCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;
- (BOOL) usbControlCmdOnPipe:(UInt8)pipe withBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;
- (BOOL) usbStreamCmdOnPipe:(UInt8)pipe withBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len;

- (BOOL) usbReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;//Sends a IN|VENDOR|DEVICE command
- (BOOL) usbReadVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;//Sends a IN|VENDOR|INTERFACE command
- (BOOL) usbWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;//Sends a OUT|VENDOR|DEVICE command
- (BOOL) usbWriteVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len;//Sends a OUT|VENDOR|INTERFACE command 

- (BOOL) usbControlWritePipe:(UInt8)pipe buffer:(void *)buf length:(UInt32)size;
- (BOOL) usbControlReadPipe:(UInt8)pipe buffer:(void *)buf length:(UInt32 *)size;
- (BOOL) usbStreamWritePipe:(UInt8)pipe buffer:(void *)buf length:(UInt32)size;
- (BOOL) usbStreamReadPipe:(UInt8)pipe buffer:(void *)buf length:(UInt32 *)size;

- (BOOL) usbClearPipeStall: (UInt8) pipe;
- (BOOL) usbSetAltInterfaceTo:(short)alt testPipe:(short)pipe;	//Sets the alt interface and optionally tests if a pipe exists
- (BOOL) usbMaximizeBandwidth: (short) pipe  suggestedAltInterface: (short) suggested  numAltInterfaces: (short) max;

- (CameraError) usbConnectToCam:(UInt32)usbLocationId configIdx:(short)configIdx;
    //Standard open dev, reset device, set config (if>=0), open intf 
- (BOOL) separateControlAndStreamingInterfaces;
- (IOReturn) usbOpenInterface:(IOUSBInterfaceInterface ***)intfPtr using:(io_service_t)usbInterfaceRef;
- (void) usbCloseConnection;				//Close and release intf and dev
- (BOOL) usbGetSoon:(UInt64*)to;			//Get a bus frame number in the near future
- (int) usbGetIsocFrameSize;                //Get the isoc frame size

//Other tool functions - may also be used from outside
- (BOOL) makeErrorImage:(CameraError) err;		//Draws and sends an error image. Returns if the image was actually sent
- (BOOL) makeMessageImage:(char*)msg;			//Draws and sends a message image. Returns if the image was actually sent
- (BOOL) makeOKImage;					//Draws and sends a test pattern image. Returns if the image was actually sent

@end
