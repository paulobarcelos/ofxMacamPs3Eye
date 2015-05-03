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
 $Id: MyCameraDriver.m,v 1.36 2009/05/01 03:02:41 hxr Exp $
*/

#import "MyCameraDriver.h"
#import "MyCameraCentral.h"
#import "Resolvers.h"
#import "MiniGraphicsTools.h"
#import "MiscTools.h"
#include <unistd.h>		//usleep

@implementation MyCameraDriver

+ (unsigned short) cameraUsbProductID {
    NSAssert(0,@"You must override cameraUsbProductID or cameraUsbDescriptions");
    return 0;
}

+ (unsigned short) cameraUsbVendorID {
    NSAssert(0,@"You must override cameraUsbVendorID or cameraUsbDescriptions");
    return 0;
}

+ (NSString*) cameraName {
    NSAssert(0,@"You must override cameraName or cameraUsbDescriptions");
    return @"";
}

+ (NSArray*) cameraUsbDescriptions {
    NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:[self cameraUsbProductID]],@"idProduct",
        [NSNumber numberWithUnsignedShort:[self cameraUsbVendorID]],@"idVendor",
        [self cameraName],@"name",NULL];
    return [NSArray arrayWithObject:dict];
}

+ (BOOL) isUVC
{
    return NO;
}

- (id) initWithCentral:(id)c {
//init superclass
    self=[super init];
    if (self==NULL) return NULL;
//setup simple defaults
    central=c;
    dev=NULL;
    controlIntf = NULL;
    streamIntf = NULL;
    confDesc = NULL;
    interfaceID = 0;
    
    altInterfacesAvailable = -1;
    currentMaxPacketSize = -1;
    
    brightness=0.0f;
    contrast=0.0f;
    saturation=0.0f;
    hue=0.0f;
    gamma=0.0f;
    shutter=0.0f;
    gain=0.0f;
    autoGain=NO;
    hFlip=NO;
    compression=0;
    usbReducedBandwidth = NO;
    whiteBalanceMode=WhiteBalanceLinear;
    blackWhiteMode = FALSE;
    
    isStarted=NO;
    isGrabbing=NO;
    shouldBeGrabbing=NO;
    isShuttingDown=NO;
    isShutDown=NO;
    isUSBOK=YES;
    lastImageBuffer=NULL;
    lastImageBufferBPP=0;
    lastImageBufferRowBytes=0;
    timerclear(&lastImageBufferTimeVal);
    nextImageBuffer=NULL;
    nextImageBufferBPP=0;
    nextImageBufferRowBytes=0;
    nextImageBufferSet=NO;
    imageBufferLock=[[NSLock alloc] init];
    //allocate lock
    if (imageBufferLock==NULL)
	{
        NSLog(@"MyCameraDriver:init: cannot instantiate imageBufferLock");
        return NULL;
    }
    stateLock=[[NSLock alloc] init];
    //allocate lock
	
    if (stateLock==NULL)
	{
        NSLog(@"MyCameraDriver:init: cannot instantiate stateLock");
        [imageBufferLock release];
        return NULL;
    }
	
    doNotificationsOnMainThread=NO;//[central doNotificationsOnMainThread]; // <-- Hardcoded this to NO as for some reason greater than my knowlege, YES was causing a memory leak.
    mainThreadRunLoop=[NSRunLoop currentRunLoop];
    mainThreadConnection=NULL;
    decodingThreadConnection=NULL;
    return self;    
}

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId
{
    CameraResolution r;
    short fr;
    WhiteBalanceMode wb;
    r=[self defaultResolutionAndRate:&fr];
    wb=[self defaultWhiteBalanceMode];
    [self setResolution:r fps:fr];
	//NSLog(@"JVC HIJACKING STARTUP PARAMS AT startupWithUsbLocationId");
	//[self setResolution:ResolutionVGA fps:60];
    [self setWhiteBalanceMode:wb];
    isStarted=YES;
    return CameraErrorOK;
}

- (void) shutdown {
    BOOL needsShutdown;
    [stateLock lock];
    isShuttingDown=YES;
    shouldBeGrabbing=NO;
    needsShutdown=!isShutDown;
    [stateLock unlock];
    [imageBufferLock lock];	//Make sure no external image buffer is used after this method returns
    nextImageBufferSet=NO;
    nextImageBuffer=NULL;
    [imageBufferLock unlock];
    if (!needsShutdown) return;
    if (![self stopGrabbing]) {	//We can handle it here - if not, do it on the end of the decodingThread
        [self usbCloseConnection];
        [stateLock lock];
        isShutDown=YES;
        [stateLock unlock];
        [self mergeCameraHasShutDown];
    }
}	

- (void) dealloc {
    if (imageBufferLock!=NULL)
	{
		[imageBufferLock release];
		imageBufferLock = NULL;
	}
    [super dealloc];
}

- (id) delegate {
    return delegate;
}

- (void) setDelegate:(id)d 
{
	NSLog(@"MyCameraDriver setDelegate");
    delegate=d;
}

- (void) enableNotifyOnMainThread {
    doNotificationsOnMainThread=YES;
}

- (void) setCentral:(id)c {
    central=c;
}

- (id) central {
    return central;
}

- (BOOL) canSetDisabled
{
    if (!central) 
        return NO;
    
    return YES;  // This is true for almost all cameras (not dummy cameras though)
}

- (void) setDisabled:(BOOL)disable
{
    if (!central) 
        return;
    
    [central setDisableCamera:self yesNo:disable];
}

- (BOOL) disabled
{
    if (!central) 
        return NO;
    
    return [central isCameraDisabled:self];
}

- (BOOL) realCamera {	//Returns if the camera is a real image grabber or a dummy
    return YES;		//By default, subclasses are real cams. Dummys should override this
}

- (BOOL) hasSpecificName { // Returns is the camera has a more specific name (derived from USB connection perhaps)
    return NO;
}

- (NSString *) getSpecificName {
    return @"Error!: Name has not been specified";
}

//Image / camera properties get/set
- (BOOL) canSetBrightness {
    return NO;
}

- (float) brightness {
    return brightness;
}

- (void) setBrightness:(float)v {
    brightness=v;
}

- (float) brightnessStep
{
    return 1 / 255.0;
}

// offset is a hardware-only setting

- (BOOL) canSetOffset
{
    return NO;
}

- (float) offset
{
    return 0;
}

- (void) setOffset:(float) v
{
}

- (float) offsetStep
{
    return 1 / 255.0;
}

- (BOOL) canSetContrast {
    return NO;
}

- (float) contrast {
    return contrast;
}

- (void) setContrast:(float)v {
    contrast=v;
}

- (BOOL) canSetSaturation {
    return NO;
}

- (float) saturation {
    return saturation;
}

- (void) setSaturation:(float)v {
    saturation=v;
}

- (BOOL) canSetHue {
    return NO;
}

- (float) hue {
    return hue;
}

- (void) setHue:(float)v {
    hue=v;
}

- (BOOL) canSetGamma {
    return NO;
}

- (float) gamma {
    return gamma;
}

- (void) setGamma:(float)v {
    gamma=v;
}

- (BOOL) canSetSharpness {
    return NO;
}

- (float) sharpness {
    return sharpness;
}

- (void) setSharpness:(float)v {
    sharpness=v;
}

- (BOOL) canSetGain {
    return NO;
}

- (float) gain {
    return gain;
}

- (void) setGain:(float)v {
    gain=v;
}

- (float) gainStep
{
    return 1 / 255.0;
}

- (BOOL) agcDisablesGain
{
    return YES;
}

- (BOOL) canSetShutter {
    return NO;
}

- (float) shutter {
    return shutter;
}

- (void) setShutter:(float)v {
    shutter=v;
}

- (float) shutterStep
{
    return 1 / 255.0;
}

- (BOOL) agcDisablesShutter
{
    return YES;
}

- (BOOL) canSetAutoGain {	//Gain and shutter combined (so far - let's see what other cams can do...)
    return NO;
}

- (BOOL) isAutoGain {
    return autoGain;
}

- (void) setAutoGain:(BOOL)v{
    autoGain=v;
}

// Orientation

- (BOOL) canSetOrientationTo:(OrientationMode) m
{
    if ([self canSetHFlip]) 
        if (m == FlipHorizontal) 
            return YES;
    
    return (m == NormalOrientation) ? YES : NO;
}

- (OrientationMode) orientation
{
    if ([self hFlip]) 
        return FlipHorizontal;
    
    return NormalOrientation;
}

- (void) setOrientation:(OrientationMode) m
{
    if ([self canSetHFlip]) 
    {
        if (m == NormalOrientation) 
            [self setHFlip:NO];
        
        if (m == FlipHorizontal) 
            [self setHFlip:YES];
    }
}

- (BOOL) canSetHFlip {
    return NO;
}

- (BOOL) hFlip {
    return hFlip;
}

- (void) setHFlip:(BOOL)v {
    hFlip=v;
}

- (BOOL) canSetFlicker {
    return NO;
}

- (FlickerType) flicker {
    return flicker;
}

- (void) setFlicker:(FlickerType)v {
    flicker=v;
}

- (short) maxCompression {
    return 0;
}

- (short) compression {
    return compression;
}

- (void) setCompression:(short)v {
    [stateLock lock];
    if (!isGrabbing) compression=CLAMP(v,0,[self maxCompression]);
    [stateLock unlock];
}

- (BOOL) canSetUSBReducedBandwidth
{
    return NO;
}

- (BOOL) usbReducedBandwidth 
{
    return usbReducedBandwidth;
}

- (void) setUSBReducedBandwidth:(BOOL)v 
{
    usbReducedBandwidth = v;
}

- (BOOL) canSetWhiteBalanceMode {
    return NO;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    return (newMode==[self defaultWhiteBalanceMode]);
}

- (WhiteBalanceMode) defaultWhiteBalanceMode {
    return WhiteBalanceLinear;
}

- (WhiteBalanceMode) whiteBalanceMode {
    return whiteBalanceMode;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    if ([self canSetWhiteBalanceModeTo:newMode]) {
        whiteBalanceMode=newMode;
    }
}


// ============== Color Mode ======================

- (BOOL) canBlackWhiteMode {
    return NO;
}


- (BOOL) blackWhiteMode {
    return blackWhiteMode;
}

- (void) setBlackWhiteMode:(BOOL)newMode {
    if ([self canBlackWhiteMode]) {
        blackWhiteMode=newMode;
    }
}
 
 
//================== Light Emitting Diode

- (BOOL) canSetLed {
    return NO;
}


- (BOOL) isLedOn {
    return LEDon;
}

- (void) setLed:(BOOL)v {
    if ([self canSetLed]) {
        LEDon=v;
    }
}
 

// =========================

- (short) width {						//Current image width
    return WidthOfResolution(resolution);
}

- (short) height {						//Current image height
    return HeightOfResolution(resolution);
}

- (CameraResolution) resolution {				//Current image predefined format constant
    return resolution;
}

- (short) fps {							//Current frames per second
    return fps;
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {	//Does this combination work?
    return NO;
}

// No need to return result as drivers that need to over-ride this
// probably must do thing inside the "lock" anyway
- (void) setResolution:(CameraResolution)r fps:(short)fr {	// Set a resolution and frame rate. 
    if (![self supportsResolution:r fps:fr]) return;
    [stateLock lock];
    if (!isGrabbing) {
        resolution=r;
        fps=fr;
    }
    [stateLock unlock];
}

//
//  Find the largest resolution that is supported and smaller than the given dimensions
//
- (CameraResolution) findResolutionForWidth:(short)width height:(short)height 
{
    int res;
    
    for (res = (int)ResolutionMax; res >= (int)ResolutionMin; res--) 
    {
        if ((WidthOfResolution((CameraResolution)res) <= width) && (HeightOfResolution((CameraResolution)res) <= height)) 
            if ([self findFrameRateForResolution:(CameraResolution)res] >= 0) 
                return (CameraResolution)res;
    }
    
    //  If there is no smaller resolution: Find the smallest availabe resolution
    
    for (res = (int)ResolutionMin; res <= (int)ResolutionMax; res++) 
    {
        if ([self findFrameRateForResolution:(CameraResolution)res] >= 0) 
            return (CameraResolution)res;
    }
    
#ifdef VERBOSE
    NSLog(@"MyCameraDriver:findResolutionForWidth:height: Cannot find any suitable resolution");
#endif
    return ResolutionQSIF;
}

- (short) findFrameRateForResolution:(CameraResolution)res 
{
    short fpsRun;
    
    for (fpsRun = MaximumFPS; fpsRun >= 0; fpsRun -= 5) 
    {
        if ([self supportsResolution:res fps:fpsRun]) 
            return fpsRun;
    }
    
    return -1;
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {	//Just some defaults. You should always override this.
    if (dFps) *dFps=5;
    return ResolutionSQSIF;
}

//Grabbing
- (BOOL) startGrabbing {					//start async grabbing
	NSLog(@"MyCameraDriver:startGrabbing");
    id threadData=NULL;
    BOOL needStartUp=YES;
    BOOL ret=NO;
    [stateLock lock];
    needStartUp=isStarted&&(!isShuttingDown)&&(!isGrabbing);
    if (needStartUp) { //update driver state
        shouldBeGrabbing=YES;
        isGrabbing=YES;
    }
    ret=isGrabbing;	
    [stateLock unlock];
    if (!needStartUp) return ret;
    if (doNotificationsOnMainThread) {
        NSPort* port1=[NSPort port];
        NSPort* port2=[NSPort port];
        mainThreadConnection=[[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
        [mainThreadConnection setRootObject:self];
        threadData=[NSArray arrayWithObjects:port2,port1,NULL];
    }
    [NSThread detachNewThreadSelector:@selector(decodingThreadWrapper:) toTarget:self withObject:threadData];    //start decodingThread
    return ret;
}

- (BOOL) stopGrabbing {		//Stop async grabbing
    BOOL res;
    [stateLock lock];
    if (isGrabbing) shouldBeGrabbing=NO;
    res=isGrabbing;
    [stateLock unlock];
    return res;
}

- (BOOL) isGrabbing {	// Returns if the camera is grabbing
    BOOL res;
    [stateLock lock];
        res = shouldBeGrabbing;
    [stateLock unlock];
    return res;
}

- (void) decodingThreadWrapper:(id)data {
    CameraError err;
    NSConnection* myMainThreadConnection;	//local copies for the end where possibly a new thread is using the object's variables
    NSConnection* myDecodingThreadConnection;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    if (data) {
        decodingThreadConnection=[[NSConnection alloc] initWithReceivePort:[data objectAtIndex:0] sendPort:[data objectAtIndex:1]];
    }
    err=[self decodingThread];
    myMainThreadConnection=mainThreadConnection;
    myDecodingThreadConnection=decodingThreadConnection;
    [stateLock lock];	//We have to lock because other tasks rely on a constant state within their lock
    isGrabbing=NO;
    [stateLock unlock];
    [self mergeGrabFinishedWithError:err];
    if (isShuttingDown) {
        [self usbCloseConnection];
        [self mergeCameraHasShutDown];
        [stateLock lock];
        isShutDown=YES;
        [stateLock unlock];
    }
    if (myDecodingThreadConnection) [myDecodingThreadConnection release]; 
    if (myMainThreadConnection) [myMainThreadConnection release];
    [pool release];
    [NSThread exit];
}

- (CameraError) decodingThread {
    return CameraErrorInternal;
}

- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb {
    if (((bpp!=3)&&(bpp!=4))||(rb<0))
	{
		NSLog(@"MyCameraDriver setImageBuffer invalid params - returning early" );
		return;
	}
    [imageBufferLock lock];
    if ((!isShuttingDown)&&(!isShutDown)) 
	{	//When shutting down, we don't accept buffers any more
        nextImageBuffer=buffer;
    } else 
	{
        nextImageBuffer=NULL;
    }
    nextImageBufferBPP=bpp;
    nextImageBufferRowBytes=rb;
    nextImageBufferSet=YES;
    [imageBufferLock unlock];
}

- (unsigned char*) imageBuffer {
    return lastImageBuffer;
}

- (short) imageBufferBPP {
    return lastImageBufferBPP;
}

- (long) imageBufferRowBytes {
    return lastImageBufferRowBytes;
}

- (struct timeval) imageBufferTimeVal 
{
    return lastImageBufferTimeVal;
}

- (BOOL) canStoreMedia {
    return NO;
}

- (long) numberOfStoredMediaObjects {
    return 0;
}

- (NSDictionary*) getStoredMediaObject:(long)idx {
    return NULL;
}

- (BOOL) canGetStoredMediaObjectInfo {
    return NO;
}

- (NSDictionary*) getStoredMediaObjectInfo:(long)idx {
    return NULL;
}

- (BOOL) canDeleteAll {
    return NO;
}

- (CameraError) deleteAll {
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteOne {
    return NO;
}

- (CameraError) deleteOne:(long)idx {
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteLast {
    return NO;
}

- (CameraError) deleteLast {
    return CameraErrorUnimplemented;
}

- (BOOL) canCaptureOne {
    return NO;
}

- (CameraError) captureOne {
    return CameraErrorUnimplemented;
}


- (BOOL) supportsCameraFeature:(CameraFeature)feature {
    BOOL supported=NO;
    switch (feature) {
        case CameraFeatureInspectorClassName:
            supported=YES;
            break;
        default:
            break;
    }
    return supported;
}

- (id) valueOfCameraFeature:(CameraFeature)feature {
    id ret=NULL;
    switch (feature) {
        case CameraFeatureInspectorClassName:
            ret=@"MyCameraInspector";
            break;
        default:
            break;
    }
    return ret;
}

- (void) setValue:(id)val ofCameraFeature:(CameraFeature)feature {
    switch (feature) {
        default:
            break;
    }
}


//Merging Notification forwarders - use these if you want to notify from decodingThread

- (void) mergeGrabFinishedWithError:(CameraError)err {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeGrabFinishedWithError:err];
            return;
        }
    }
    [self grabFinished:self withError:err];
}

- (void) mergeImageReady {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeImageReady];
            return;
        }
    }
    [self imageReady:self];
}

- (void) mergeCameraHasShutDown {
    if (doNotificationsOnMainThread) {
        if ([NSRunLoop currentRunLoop]!=mainThreadRunLoop) {
            [(id)[decodingThreadConnection rootProxy] mergeCameraHasShutDown];
            return;
        }
    }
    [self cameraHasShutDown:self];
}

//Simple Notification forwarders

- (void) imageReady:(id)sender {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(imageReady:)]) {
            [delegate imageReady:sender];
        }
    }
}

- (void) grabFinished:(id)sender withError:(CameraError)err{
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(grabFinished:withError:)]) [delegate grabFinished:sender withError:err];
    }
}

- (void) cameraHasShutDown:(id)sender {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(cameraHasShutDown:)]) [delegate cameraHasShutDown:sender];
    }
    if (central) {
        [central cameraHasShutDown:self];
    }
}

- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt {
    if (delegate!=NULL) {
        if ([delegate respondsToSelector:@selector(cameraEventHappened:event:)]) {
            [delegate cameraEventHappened:sender event:evt];
        }
    }
}

- (void) mergeCameraEventHappened:(CameraEvent)evt 
{
    if (doNotificationsOnMainThread) 
        if ([NSRunLoop currentRunLoop] != mainThreadRunLoop) 
            if (decodingThreadConnection) 
            {
                [(id)[decodingThreadConnection rootProxy] mergeCameraEventHappened:evt];
                return;
            }
    
    [self cameraEventHappened:self event:evt];
}

- (MyCameraInfo*) getCameraInfo {
       return cameraInfo;
}

- (void) setCameraInfo:(MyCameraInfo *)info {
       cameraInfo = info;
}


// Camera register functions
// they all return -1 if there is a problem

- (int) dumpRegisters
{
    NSLog(@"MyCameraDriver:dumpRegisters: not implemented");
    return -1;
}

- (int) getRegister:(UInt16)reg
{
    NSLog(@"MyCameraDriver:getRegister: not implemented");
    return -1;
}

- (int) setRegister:(UInt16)reg toValue:(UInt16)val
{
    NSLog(@"MyCameraDriver:setRegister:toValue: not implemented");
    return -1;
}

- (int) setRegister:(UInt16)reg toValue:(UInt16)val withMask:(UInt16)mask
{
    int result = [self getRegister:reg];
    UInt8 actualVal = result;
    
    if (result < 0) 
        return result;
    
    actualVal &= ~mask;  // clear out bits
    val &= mask;         // only set bits allowed by mask
    actualVal |= val;    // combine them
    
    return [self setRegister:reg toValue:actualVal];
}


// USB Tool functions for subclasses

//
// Sends a generic command
//
- (BOOL) usbGenericCmd:(IOUSBInterfaceInterface**)intf onPipe:(UInt8)pipe BRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    IOReturn err;
    IOUSBDevRequest req;
    req.bmRequestType=bReqType;
    req.bRequest=bReq;
    req.wValue=wVal; // no need to swap, in host endianness
    req.wIndex=wIdx; // no need to swap, in host endianness
    req.wLength=len; // no need to swap, in host endianness
    req.pData=buf;
    
    if ((!isUSBOK) || (!intf)) 
        return NO;
    
    err = (*intf)->ControlRequest(intf, pipe, &req);
    
#if LOG_USB_CALLS
    NSLog(@"usb command reqType:%i req:%i val:%i idx:%i len:%i ret:%i", bReqType, bReq, wVal, wIdx, len, err);
    if (len > 0) 
        DumpMem(buf, len);
#endif
    
    CheckError(err, "usbCmdWithBRequestType");
    if ((err == kIOUSBPipeStalled) && (intf)) 
        (*intf)->ClearPipeStall(intf, pipe);
    
    return (!err);
}

- (BOOL) usbCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    return [self usbControlCmdWithBRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
}

//
// Send a request to the control interface
//
- (BOOL) usbControlCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    if (controlIntf != NULL) 
        return [self usbGenericCmd:controlIntf onPipe:0 BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
    else 
        return [self usbGenericCmd:streamIntf onPipe:0 BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
}

//
// Send a request to the control interface
//
- (BOOL) usbControlCmdOnPipe:(UInt8)pipe withBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    if (controlIntf != NULL) 
        return [self usbGenericCmd:controlIntf onPipe:pipe BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
    else 
        return [self usbGenericCmd:streamIntf onPipe:pipe BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
}

//
// Send a request to the control interface
//
- (BOOL) usbStreamCmdOnPipe:(UInt8)pipe withBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    return [self usbGenericCmd:streamIntf onPipe:pipe BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
}

//
// Send a request to the streaming interface
//
- (BOOL) usbStreamCmdWithBRequestType:(UInt8)bReqType bRequest:(UInt8)bReq wValue:(UInt16)wVal wIndex:(UInt16)wIdx buf:(void*)buf len:(short)len 
{
    return [self usbGenericCmd:streamIntf onPipe:0 BRequestType:bReqType bRequest:bReq wValue:wVal wIndex:wIdx buf:buf len:len];
}

//sends a USB IN|VENDOR|DEVICE command
- (BOOL) usbReadCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB IN|VENDOR|INTERFACE command
- (BOOL) usbReadVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBInterface)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB OUT|VENDOR|DEVICE command
- (BOOL) usbWriteCmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

//sends a USB OUT|VENDOR|INTERFACE command
- (BOOL) usbWriteVICmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len {
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

- (BOOL) usbControlWritePipe:(UInt8)pipe buffer:(void *)buf length:(UInt32)size
{
    IOReturn err = (*controlIntf)->WritePipe(controlIntf, pipe, buf, size);
    
    return (err) ? NO : YES;
}

- (BOOL) usbControlReadPipe:(UInt8)pipe buffer:(void *)buf length:(UInt32 *)size
{
    IOReturn err = (*controlIntf)->ReadPipe(controlIntf, pipe, buf, size);
    
    return (err) ? NO : YES;
}

- (BOOL) usbStreamWritePipe:(UInt8)pipe buffer:(void *)buf length:(UInt32)size
{
    IOReturn err = (*streamIntf)->WritePipe(streamIntf, pipe, buf, size);
    
    return (err) ? NO : YES;
}

- (BOOL) usbStreamReadPipe:(UInt8)pipe buffer:(void *)buf length:(UInt32 *)size
{
    IOReturn err = (*streamIntf)->ReadPipe(streamIntf, pipe, buf, size);
    
    return (err) ? NO : YES;
}

// returns OK?
- (BOOL) usbClearPipeStall: (UInt8) pipe
{
    IOReturn ret;
    
    ret = (*streamIntf)->ClearPipeStall(streamIntf, pipe);
    
    return (ret == kIOReturnSuccess) ? YES : NO;
}

- (BOOL) usbSetAltInterfaceTo:(short)alt testPipe:(short)pipe {
    IOReturn err;
    BOOL ok=YES;
    if ((!isUSBOK)||(!streamIntf)) ok=NO;
    if (ok) {
        err=(*streamIntf)->SetAlternateInterface(streamIntf,alt);			//set alternate interface
        CheckError(err,"setAlternateInterface");
        if (err) ok=NO;
    }
    if ((!isUSBOK)||(!streamIntf)) ok=NO;
    if (ok&&(alt!=0)&&(pipe!=0)) {
        err=(*streamIntf)->GetPipeStatus(streamIntf,pipe);				//is the pipe ok?
        CheckError(err,"getPipeStatus");
        if (err) ok=NO;
    }
#if LOG_USB_CALLS
    if (ok) NSLog(@"alt interface switch to %i ok (pipe = %i)", alt, pipe);
    else NSLog(@"alt interface switch to %i failed (pipe = %i)", alt, pipe);
#endif
    return ok;
}

#define MAX_ALT_INTERFACES  20

//
// Find the alt-interface that provides the most bandwidth
//
- (BOOL) usbMaximizeBandwidth: (short) suggestedPipe  suggestedAltInterface: (short) altRequested  numAltInterfaces: (short) maxAlt
{
    static BOOL firstTime = YES;
    
    IOReturn err;
    BOOL ok = YES;
    BOOL done = NO;
    
    int pipe = suggestedPipe;
    int a, alt, numAltInterfaces = MAX_ALT_INTERFACES - 1;
    int maxPacketSizeList[MAX_ALT_INTERFACES];
    int maxPacketSizePipe[MAX_ALT_INTERFACES];
    int maxBandWidthAlt = 0;
    int maxBandWidthPS = -1;
    
    if ((!isUSBOK) || (!streamIntf)) 
        return NO;
    
    if (maxAlt < 0) // number of alt interfaces is not known
    {
        if (altRequested > numAltInterfaces) 
        {
            if (firstTime) 
                printf("The requested alt interface is higher than the max possible! (%d > %d)\n", altRequested, numAltInterfaces);
            
            altRequested = -1;
        }
        
        if (altRequested < 0) // no specific interface is requested
        {
            if (firstTime) 
            {
                printf("Neither the total number of alt interfaces or a suggestion given, \n");
                printf(" results may be unpredictable on some verssions of Mac OS X (esp. before 10.4)\n");
            }
        }
        else 
        {
            numAltInterfaces = altRequested; // safest to set this to be the max
        }
    }
    else 
    {
        if (altRequested > maxAlt) 
        {
            if (firstTime) 
                printf("The requested alt interface is higher than the max specified! (%d > %d)\n", altRequested, maxAlt);
        }
        
        if (maxAlt > numAltInterfaces) 
        {
            if (firstTime) 
                printf("Too many alt interfaces! (%d) Need to adjust constant MAX_ALT_INTERFACES and recompile!\n", maxAlt);
        }
        else 
            numAltInterfaces = maxAlt;
    }
    
    for (alt = 0; alt <= numAltInterfaces; alt++) 
    {
        maxPacketSizeList[alt] = 0;
        maxPacketSizePipe[alt] = 0;

#if DEBUG
        printf("Trying alt %d, ", alt);
#endif
        err = (*streamIntf)->SetAlternateInterface(streamIntf, alt);
#if DEBUG
        printf("return is %d\n", err);
#endif
        if (err != kIOReturnSuccess) 
        {
            numAltInterfaces = alt - 1;
        }
        else 
        {
#if VERBOSE
            if (firstTime) 
                printf("alt interface %d:\n", alt);
#endif
            
            for (pipe = 0; pipe < 10; pipe++) 
            {
                UInt8				direction, number, transferType, interval;
                UInt16				maxPacketSize;
                
                err = (*streamIntf)->GetPipeProperties(streamIntf, pipe, &direction, &number, &transferType, &maxPacketSize, &interval);
                
                if (err != kIOReturnSuccess) 
                {
                    break;
                }
                else 
                {
#if VERBOSE
                    char * dir = "???";
                    char * type = "???";
                    
                    switch (direction) 
                    {
                        case kUSBOut:
                            dir = "OUT";
                            break;
                            
                        case kUSBIn:
                            dir = "IN ";
                            break;
                            
                        case kUSBNone:
                            dir = "NONE";
                            break;
                            
                        case kUSBAnyDirn:
                        default:
                            dir = "ANY";
                            break;
                    }
                        
                    switch (transferType) 
                    {
                        case kUSBControl:
                            type = "CONTROL";
                            break;
                            
                        case kUSBIsoc:
                            type = "ISOC";
                            break;
                            
                        case kUSBBulk:
                            type = "BULK";
                            break;
                            
                        case kUSBInterrupt:
                            type = "INTERRUPT";
                            break;
                            
                        case kUSBAnyType:
                        default:
                            type = "ANY";
                            break;
                    }
                    
                    if (firstTime) 
                        printf("  pipe %d: %s %d %s %d %d\n", pipe, dir, 
                               number, type, maxPacketSize, interval);
#endif
                    
                    if (direction == kUSBIn && transferType == kUSBIsoc) 
                    {
                        if (maxPacketSizeList[alt] < maxPacketSize) 
                        {
                            maxPacketSizeList[alt] = maxPacketSize;
                            maxPacketSizePipe[alt] = pipe;
                        }
                        
                        if (maxBandWidthPS < maxPacketSize) 
                        {
                            maxBandWidthPS = maxPacketSize;
                            maxBandWidthAlt = alt;
                        }
                    }
                }
            }
        }
    }
    
    // find out about device, speed, alt-interfaces
// 197 IOReturn (*GetIOUSBLibVersion)(void *self, NumVersion *ioUSBLibVersion, NumVersion *usbFamilyVersion);

// all IOReturn (*GetLocationID)(void *self, UInt32 *locationID);
// all IOReturn (*GetDevice)(void *self, io_service_t *device);
    
// all IOReturn (*GetDeviceAddress)(void *device, USBDeviceAddress *addr);
// all IOReturn (*GetDeviceSpeed)(void *device, UInt8 *devSpeed);
// all IOReturn (*GetLocationID)(void *device, UInt32 *locationID);
// all IOReturn (*GetConfigurationDescriptorPtr)(void *device, UInt8 configIndex, IOUSBConfigurationDescriptorPtr *desc);

// 182 IOReturn (*USBDeviceSuspend)(void *device, Boolean suspend);
// 197 IOReturn (*GetIOUSBLibVersion)(void *device, NumVersion *ioUSBLibVersion, NumVersion *usbFamilyVersion);

// 190 IOReturn (*SetPipePolicy)(void *self, UInt8 pipeRef, UInt16 maxPacketSize, UInt8 maxInterval);
// 190 IOReturn (*GetBandwidthAvailable)(void *self, UInt32 *bandwidth);
// 190 IOReturn (*GetEndpointProperties)(void *self, UInt8 alternateSetting, UInt8 endpointNumber, UInt8 direction, UInt8 *transferType, UInt16 *maxPacketSize, UInt8 *interval);
    
    // find out about bus
    // find out about other devices hooked up to the bus
    
    firstTime = NO;
    
    // try to get the requested alt-interface
    // if none suggested (-1), then maximize
    // use the alt with maximum packet size, set the altRequested to this
    
    pipe = suggestedPipe;
    
    if ((altRequested >= 0) && (maxPacketSizeList[altRequested] > 0)) 
        alt = altRequested;
    else // none requested
    {
        alt = maxBandWidthAlt;

        // if usb bandwidth is reduced, then try a lower setting
        
        if ([self usbReducedBandwidth]) 
        {
            int reducedAlt = -1;
            
            // find the next highest one
            
            for (a = 0; a <= numAltInterfaces; a++) 
            {
                if (maxPacketSizeList[a] < maxPacketSizeList[maxBandWidthAlt]) 
                {
                    if (reducedAlt < 0)
                        reducedAlt = a;
                    else if (maxPacketSizeList[a] > maxPacketSizeList[reducedAlt]) 
                        reducedAlt = a;
                }
#if VERBOSE
                printf("a = %d, reducedAlt = %d, PS[a] = %d\n", a, reducedAlt, maxPacketSizeList[a]);
#endif
            }
            
            alt = reducedAlt;
        }
    }
    
    while (ok && !done) 
    {
        maxBandWidthPS = maxPacketSizeList[alt];
        
#if VERBOSE
        printf("Setting alt to %d, (with packet-size = %d), ", alt, maxBandWidthPS);
#endif
        err = (*streamIntf)->SetAlternateInterface(streamIntf, alt);
#if VERBOSE
        printf("return is %d\n", err);
#endif
        CheckError(err, "usbMaximizeBandwidth:SetAlternateInterface");
        
        if (!err && pipe == 0) 
            done = YES;
        
        if (!err) 
        {
#if VERBOSE
            printf("Checking pipe status, ");
#endif
            err = (*streamIntf)->GetPipeStatus(streamIntf, pipe);
#if VERBOSE
            printf("return is %d\n", err);
#endif
            CheckError(err, "usbMaximizeBandwidth:getPipeStatus");
        }
        
        // Must call GetPipeProperties() to really find out the status of the pipe
        
        if (!err) 
        {
            UInt8 direction, number, transferType, interval;
            UInt16 maxPacketSize;
            
#if VERBOSE
            char * dir = "???";
            char * type = "???";
            
            printf("Checking pipe properties, ");
#endif
            err = (*streamIntf)->GetPipeProperties(streamIntf, pipe, &direction, &number, &transferType, &maxPacketSize, &interval);
#if VERBOSE
            printf("return is %d\n", err);
            
            switch (direction) 
            {
                case kUSBOut:
                    dir = "OUT";
                    break;
                    
                case kUSBIn:
                    dir = "IN ";
                    break;
                    
                case kUSBNone:
                    dir = "NONE";
                    break;
                    
                case kUSBAnyDirn:
                default:
                    dir = "ANY";
                    break;
            }
            
            switch (transferType) 
            {
                case kUSBControl:
                    type = "CONTROL";
                    break;
                    
                case kUSBIsoc:
                    type = "ISOC";
                    break;
                    
                case kUSBBulk:
                    type = "BULK";
                    break;
                    
                case kUSBInterrupt:
                    type = "INTERRUPT";
                    break;
                    
                case kUSBAnyType:
                default:
                    type = "ANY";
                    break;
            }
            
            printf("  pipe %d: %s %d %s %d %d\n", pipe, dir, number, type, maxPacketSize, interval);
#endif
            CheckError(err, "usbMaximizeBandwidth:GetPipeProperties");
            
            if (!err && maxPacketSize > 0) 
                done = YES;
        }
        
        if (err || !done) 
        {
            int nextAlt = -1;
            
            // find the next one
            
            for (a = 0; a <= numAltInterfaces; a++) 
            {
                if (maxPacketSizeList[a] < maxBandWidthPS) 
                {
                    if (nextAlt < 0)
                        nextAlt = a;
                    else if (maxPacketSizeList[a] > maxPacketSizeList[nextAlt]) 
                        nextAlt = a;
                }
#if VERBOSE
                printf("a = %d, nextAlt = %d, PS[a] = %d\n", a, nextAlt, maxPacketSizeList[a]);
#endif
            }
            
            if (nextAlt < 0) 
            {
                ok = NO;
                printf("usbMaximizeBandwidth: no more interfaces to try!\n");
            }
            
            if (maxPacketSizeList[nextAlt] == 0) 
            {
                ok = NO;
                printf("usbMaximizeBandwidth: last interface has zero packet-size!\n");
            }
            
            alt = nextAlt;
        }
    }
    
    currentMaxPacketSize = maxBandWidthPS;
    
    // get the requestedPacketSize
    
    // now loop
    //   set the alt
    //   get the status
    //   if pipe is OK or no more choices, then end loop
    //   if pipe is not OK, then find the alt with the next lower packet-size
    //   if pipe is zero (and not requested) print some error message
    //  end loop
    
    // if none available but 0, (and not requested) then return NO
    // if anything other than 0 is available, return YES
    
    return ok;
}

- (BOOL) separateControlAndStreamingInterfaces
{
    return NO;
}

- (CameraError) usbConnectToCam:(UInt32)usbLocationId configIdx:(short)configIdx{
    IOReturn				err;
    IOCFPlugInInterface 		**iodev;		// requires <IOKit/IOCFPlugIn.h>
    SInt32 				score;
    UInt8				numConf;
    IOUSBFindInterfaceRequest		interfaceRequest;
    io_iterator_t			iterator;
    io_service_t			usbInterfaceRef;
    short    				retries;
    kern_return_t			ret;
    io_service_t			usbDeviceRef=IO_OBJECT_NULL;
    mach_port_t				masterPort;
    CFMutableDictionaryRef 		matchingDict;
    
//Get a master port (we should release it later...) *******

    ret=IOMasterPort(MACH_PORT_NULL,&masterPort);
    if (ret) {
#ifdef VERBOSE
        NSLog(@"usbConnectToCam: Could not get master port (err:%08x)",ret);
#endif
        return CameraErrorInternal;
    }

//Search device with given location Id
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
#ifdef VERBOSE
            NSLog(@"usbConnectToCam: Could not build matching dict");
#endif
            return CameraErrorNoMem;
    }
    ret = IOServiceGetMatchingServices(masterPort,
                                       matchingDict,
                                       &iterator);
    
    if ((ret)||(!iterator)) {
#ifdef VERBOSE
        NSLog(@"usbConnectToCam: Could not build iterate services");
#endif
        return CameraErrorNoMem;
    }

    //Go through results
    
    while (usbDeviceRef=IOIteratorNext(iterator)) {
        UInt32 locId;
        
        err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
        CheckError(err,"usbConnectToCam-IOCreatePlugInInterfaceForService");
        if ((!iodev)||(err)) return CameraErrorInternal;	//Bail - find better error code ***

        //ask plugin interface for device interface
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*)&dev);
        //IOPlugin interface is done
        (*iodev)->Release(iodev);
        if ((!dev)||(err)) return CameraErrorInternal;		//Bail - find better error code ***
        CheckError(err,"usbConnectToCam-QueryInterface1");

        ret = (*dev)->GetLocationID(dev,&locId);
        if (ret) {
#ifdef VERBOSE
            NSLog(@"could not get location id (err:%08x)",ret);
#endif
            (*dev)->Release(dev);
            return CameraErrorUSBProblem;
        }
        if (usbLocationId==locId) break;	//We found our device
        else {
            (*dev)->Release(dev);
            IOObjectRelease(usbDeviceRef);
            dev=NULL;
        }            
    }

    IOObjectRelease(iterator);
    iterator=IO_OBJECT_NULL;
    
    if (!dev) return CameraErrorNoCam;
    
    //Now we should have the correct device interface.    

    //open device interface. Retry this to get it from Classic (see ClassicUSBDeviceArb.html - simplified mechanism)
    for (retries=10;retries>0;retries--) {
        err = (*dev)->USBDeviceOpen(dev);
        CheckError(err,"usbConnectToCam-USBDeviceOpen");
        if (err!=kIOReturnExclusiveAccess) break;	//Loop only if the device is busy
        usleep(500000);
    }
    if (err) {			//If soneone else has our device, bail out as if nothing happened...
        err = (*dev)->Release(dev);
        CheckError(err,"usbConnectToCam-Release Device (exclusive access)");
        dev=NULL;
        return CameraErrorBusy;
    }

    if (configIdx>=0) {	//Set configIdx to -1 if you don't want a config to be selected
        //do a device reset. Shouldn't harm.
        err = (*dev)->ResetDevice(dev);
        CheckError(err,"usbConnectToCam-ResetDevice");
        //Count configurations
        err = (*dev)->GetNumberOfConfigurations(dev, &numConf);
        CheckError(err,"usbConnectToCam-GetNumberOfConfigurations");
        if (numConf<configIdx) {
            NSLog(@"Invalid configuration index");
            err = (*dev)->Release(dev);
            dev=NULL;
            return CameraErrorInternal;
        }
        err = (*dev)->GetConfigurationDescriptorPtr(dev, configIdx, &confDesc);
        CheckError(err,"usbConnectToCam-GetConfigurationDescriptorPtr");
        retries=3;
        do {
            err = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
            CheckError(err,"usbConnectToCam-SetConfiguration");
            if (err==kIOUSBNotEnoughPowerErr) {		//no power?
                err = (*dev)->Release(dev);
                CheckError(err,"usbConnectToCam-Release Device (low power)");
                dev=NULL;
                return CameraErrorNoPower;
            }
            if (err == kIOReturnNoResources)  // USB2 camera on USB1-only bus
            {
                IOUSBDevRequest req;
                req.bmRequestType = 0x40;
                req.bRequest = 0x52;
                req.wValue = 0x0101;
                req.wIndex = 1;  // Flip to the other speed
                req.wLength = 0;
                req.pData = NULL;
                err = (*dev)->DeviceRequest(dev, &req);
                CheckError(err,"usbConnectToCam-DeviceRequest");
                
                (*dev)->Release(dev);
                dev = NULL;
                
                if (err) 
                    return CameraErrorUSBNeedsUSB2;
                else 
                    return CameraErrorUSBProblem;
            }
        } while((err)&&((--retries)>0));
        if (err) {					//error opening interface?
            err = (*dev)->Release(dev);
            CheckError(err,"usbConnectToCam-Release Device (low power)");
            dev=NULL;
            return CameraErrorUSBProblem;
        }
    }
//    kIOReturnNoResources
//  GetFullConfigurationDescriptor
    
    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;		// requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;		// requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;		// requested protocol
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;		// requested alt setting
    
// take an iterator over the device interfaces...
    err = (*dev)->CreateInterfaceIterator(dev, &interfaceRequest, &iterator);
    CheckError(err,"usbConnectToCam-CreateInterfaceIterator");
    
// and find the right interface(s)
    if ([self separateControlAndStreamingInterfaces]) 
    {
        usbInterfaceRef = IOIteratorNext(iterator);
        assert(usbInterfaceRef);
        err = [self usbOpenInterface:&controlIntf using:usbInterfaceRef];
        
        usbInterfaceRef = IOIteratorNext(iterator);
        assert(usbInterfaceRef);
        err = [self usbOpenInterface:&streamIntf using:usbInterfaceRef];
    }
    else 
    {
        usbInterfaceRef = IOIteratorNext(iterator);
        assert(usbInterfaceRef);
        err = [self usbOpenInterface:&streamIntf using:usbInterfaceRef];
    }
    
    // We don't need the iterator any more
    IOObjectRelease(iterator);
    iterator = IO_OBJECT_NULL;
    
    if (interfaceID >= 197) 
    {
        NumVersion lib;
        NumVersion family;
        
        err = (* ((IOUSBInterfaceInterface197 **) streamIntf))->GetIOUSBLibVersion(streamIntf, &lib, &family);  // 197 and up
        
        if (!err) 
        {
            interfaceID = 100 * (family.majorRev) + 10 * (family.minorAndBugRev >> 4) + (family.minorAndBugRev & 0x0F);
#if VERBOSE
//          printf("USB Library Version = %d %d %d %d\n", lib.majorRev, lib.minorAndBugRev, lib.stage, lib.nonRelRev);
//          printf("USB Library Version = 0x%04x 0x%04x 0x%04x 0x%04x\n", lib.majorRev, lib.minorAndBugRev, lib.stage, lib.nonRelRev);
            printf("USB Library Version = %x.%x.%x\n", lib.majorRev, lib.minorAndBugRev >> 4, lib.minorAndBugRev & 0x0F);
//          printf("USB Family Version = %d %d %d %d\n", family.majorRev, family.minorAndBugRev, family.stage, family.nonRelRev);
//          printf("USB Family Version = 0x%04x 0x%04x 0x%04x 0x%04x\n", family.majorRev, family.minorAndBugRev, family.stage, family.nonRelRev);
            printf("USB Family Version = %x.%x.%x\n", family.majorRev, family.minorAndBugRev >> 4, family.minorAndBugRev & 0x0F);
#endif
        }
    }
#if VERBOSE
    printf("USB Interface ID = %d\n", interfaceID);
#endif
    
    // Set alternate on stream interface
    
    err = (*streamIntf)->SetAlternateInterface(streamIntf, 0);
    CheckError(err, "usbConnectToCam-SetAlternateInterface");
    
    return CameraErrorOK;
}

//
// function that takes the usbInterfaceRef and creates and opens the interface
//
- (IOReturn) usbOpenInterface:(IOUSBInterfaceInterface ***)intfPtr using:(io_service_t)usbInterfaceRef
{
    IOReturn			   err;
    IOCFPlugInInterface ** iodev;		// requires <IOKit/IOCFPlugIn.h>
    SInt32 				   score;
    
    // Get a plugin interface for the interface interface
    
    err = IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    CheckError(err, "usbOpenInterface-IOCreatePlugInInterfaceForService");
    assert(iodev);
    
    IOObjectRelease(usbInterfaceRef);  // Done with this
    
    // Get access to the interface interface
	err = 12345;
    
#if defined(kIOUSBInterfaceInterfaceID220)
	if (err) 
	{
		interfaceID = 220;
		err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID220), (LPVOID*) intfPtr);
    }
#endif
    if (err) 
    {
        interfaceID = 197;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID197), (LPVOID*) intfPtr);
    }
    if (err) 
    {
        interfaceID = 197;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID192), (LPVOID*) intfPtr);
    }
    if (err) 
    {
        interfaceID = 190;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID190), (LPVOID*) intfPtr);
    }
    if (err) 
    {
        interfaceID = 183;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID183), (LPVOID*) intfPtr);
    }
    if (err) 
    {
        interfaceID = 182;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID182), (LPVOID*) intfPtr);
    }
    if (err) 
    {
        interfaceID = 0;
        err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID*) intfPtr);
    }
    CheckError(err,"usbOpenInterface-QueryInterface");
    assert(*intfPtr);
    (*iodev)->Release(iodev);  // Done with this
    
    // Open interface
    
    err = (**intfPtr)->USBInterfaceOpen(*intfPtr);
    CheckError(err,"usbOpenInterface-USBInterfaceOpen");
    
    return err;
}

- (void) usbCloseConnection 
{
    IOReturn err = kIOReturnSuccess;
    
    if (streamIntf != NULL && streamIntf != controlIntf)  // Close the stream interface interface
    {
        if (isUSBOK) 
            err = (*streamIntf)->USBInterfaceClose(streamIntf);
        err = (*streamIntf)->Release(streamIntf);
        CheckError(err,"usbCloseConnection-Release Stream Interface");
        streamIntf = NULL;
    }
    
    if (controlIntf != NULL)  // Close the control interface interface
    {
        if (isUSBOK) 
            err = (*controlIntf)->USBInterfaceClose(controlIntf);
        err = (*controlIntf)->Release(controlIntf);
        CheckError(err,"usbCloseConnection-Release Interface");
        controlIntf = NULL;
        streamIntf = NULL;
    }
    
    if (dev != NULL)  // Close the device interface
    {
        if (isUSBOK) 
            err = (*dev)->USBDeviceClose(dev);
        err = (*dev)->Release(dev);
        CheckError(err,"usbCloseConnection-Release Device");
        dev = NULL;
    }
}

- (BOOL) usbGetSoon:(UInt64*)to {			//Get a bus frame number in the near future
    AbsoluteTime at;
    IOReturn err;
    UInt64 frame;
    
    if ((!to)||(!streamIntf)||(!isUSBOK)) return NO;
    err=(*streamIntf)->GetBusFrameNumber(streamIntf, &frame, &at);
    CheckError(err,"usbGetSoon");
    if (err) return NO;
    *to=frame+100;					//give it a little time to start
    return YES;
}

// Return the size needed for an isochronous frame
// Depends on whether it is high-speed device on a high-speed hub
- (int) usbGetIsocFrameSize
{
    int result, defaultSize = 1023;
	
#if defined(kUSBMaxHSIsocEndpointReqCount)
    UInt32 microsecondsInFrame = kUSBFullSpeedMicrosecondsInFrame;
    
    if (interfaceID >= 197) 
    {
		IOReturn err;
        err = (*(IOUSBInterfaceInterface197 **) streamIntf)->GetFrameListTime(streamIntf, &microsecondsInFrame);
        CheckError(err,"usbGetIsocFrameSize:GetFrameListTime");
    }
    
    if (microsecondsInFrame == kUSBHighSpeedMicrosecondsInFrame) 
        defaultSize = kUSBMaxHSIsocEndpointReqCount;
    else 
        defaultSize = kUSBMaxFSIsocEndpointReqCount;
#endif
	
    result = (currentMaxPacketSize < 0) ? defaultSize : currentMaxPacketSize;
    
#if VERBOSE
    printf("usbGetIsocFrameSize returning %d\n", result);
#endif
    
    return result;
}

//Other tool functions
- (BOOL) makeErrorImage:(CameraError) err {
    switch (err) {
        case CameraErrorOK:		return [self makeOKImage]; break;
        default:			return [self makeMessageImage:[central localizedCStrForError:err]]; break;
    }
}

- (BOOL) makeMessageImage:(char*) msg {
    BOOL draw;
    [imageBufferLock lock];
    lastImageBuffer=nextImageBuffer;
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    draw=nextImageBufferSet;
    nextImageBufferSet=NO;    
    if (draw) {
        if (lastImageBuffer) {
            memset(lastImageBuffer,0,lastImageBufferRowBytes*[self height]);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,10,msg);
        }
        [imageBufferLock unlock];
        [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
    } else {
        [imageBufferLock unlock];
    }
    return draw;
}	

- (BOOL) makeOKImage {
    BOOL draw;
    char cstr[20];
    short x,bar,y,width,height,barend;
    UInt8 r,g,b;
    UInt8* bufRun;
    BOOL alpha;
    CFTimeInterval time;
    short h,m,s,f;
    [imageBufferLock lock];
    lastImageBuffer=nextImageBuffer;
    lastImageBufferBPP=nextImageBufferBPP;
    lastImageBufferRowBytes=nextImageBufferRowBytes;
    draw=nextImageBufferSet;
    nextImageBufferSet=NO;
    [imageBufferLock unlock];
    if (draw) {
        if (lastImageBuffer) {
//Draw color stripes
            alpha=lastImageBufferBPP==4;
            width=[self width];
            height=[self height];
            bufRun=lastImageBuffer;
            for (y=0;y<height;y++) {
                x=0;
                for (bar=0;bar<8;bar++) {
                    switch (bar) {
                        case 0: r=255;g=255;b=255;break;
                        case 1: r=255;g=255;b=0  ;break;
                        case 2: r=255;g=0  ;b=255;break;
                        case 3: r=0  ;g=255;b=255;break;
                        case 4: r=255;g=0  ;b=0  ;break;
                        case 5: r=0  ;g=255;b=0  ;break;
                        case 6: r=0  ;g=0  ;b=255;break;
                        default:r=0  ;g=0  ;b=0  ;break;
                    }
                    barend=((bar+1)*width)/8;
                    while (x<barend) {
                        if (alpha) bufRun++;
                        *(bufRun++)=r;
                        *(bufRun++)=g;
                        *(bufRun++)=b;
                        x++;
                    }
                }
                bufRun+=lastImageBufferRowBytes-width*lastImageBufferBPP;
            }
            time=CFAbsoluteTimeGetCurrent();
            h=(((long long)time)/(60*60))%24;
            m=(((long long)time)/(60))%60;
            s=((long long)time)%60;
            time*=100.0;
            f=((long long)(time))%100;
            sprintf(cstr,"%02i:%02i:%02i:%02i",h,m,s,f);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,10,cstr);
            MiniDrawString(lastImageBuffer,lastImageBufferBPP,lastImageBufferRowBytes,10,23,
                            (char*)[[[self getCameraInfo] cameraName] UTF8String]);
        }
        [self mergeImageReady];				//notify delegate about the image. perhaps get a new buffer
    }
    return draw;
}


- (void) stopUsingUSB {
    isUSBOK=NO;
}

@end
