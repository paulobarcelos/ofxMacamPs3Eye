//
//  GenericDriver.m
//
//  macam - webcam app and QuickTime driver component
//  GenericDriver - base driver code for many cameras
//
//  Created by HXR on 3/6/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//

#import "GenericDriver.h"
#import "ControllerInterface.h"  // chip interface
//#import "MyController.h"         // user interface
#import "Histogram.h"
#import "AGC.h"
#import "FrameCounter.h"

#include "MiscTools.h"
#include "Resolvers.h"

#include <unistd.h>

// 
// This driver provides more of the common code that most drivers need, while 
// separating out the code that make cameras different into smaller routines. 
//
// The main methods that get called (points of entry, if you will) are:
//   [initWithCentral]
//   [startupWithUsbLocationId]
//   [dealloc]
//   [decodingThread]
//
// To implement a new driver, subclass this class (GenericDriver) and implement
// all the required methods and any other methods that are necessary for the 
// specific camera. See the ExampleDriver for an example.
//
// These methods *must* be implemented by a subclass:
//  [setGrabInterfacePipe]
//  [startupGrabStream]
//  [shutdownGrabStream]
//  [setIsocFrameFunctions]
//  [decodeBuffer]
//
// The following methods and functions might be implemented by a subclass if necessary:
//  [startupCamera]
//  [getGrabbingPipe]
//  specificIsocDataCopier()   // The existing version should work for most
//  specificIsocFrameScanner() // If a suitable one does not already exist
//

@implementation GenericDriver

//
// Initialize the driver
// This *must* be subclassed
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    driverType = isochronousDriver; // This is the default
    exactBufferLength = 0;
    minimumBufferLength = 0;
    
    grabbingThreadRunning = NO;
	bayerConverter = NULL;
    LUT = NULL;
    rotate = NO;
    
    histogram = [[Histogram alloc] init];
    agc = [[AGC alloc] initWithDriver:self];
    
    hardwareBrightness = NO;
    hardwareContrast = NO;
    hardwareSaturation = NO;
    hardwareGamma = NO;
    hardwareSharpness = NO;   
    hardwareHue = NO;   
    hardwareFlicker = NO;   
    
    buttonInterrupt = NO;
    buttonMessageLength = 0;
    
    decodingSkipBytes = 0;
    
    compressionType = unknownCompression;
    jpegVersion = 0;
    quicktimeCodec = 0;
    
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    CocoaDecoding.imageRep = NULL;
    CocoaDecoding.bitmapGC = NULL;
    CocoaDecoding.imageContext = NULL;
    
    QuicktimeDecoding.imageDescription = NULL;
    QuicktimeDecoding.gworldPtr = NULL;
    SetQDRect(&QuicktimeDecoding.boundsRect, 0, 0, [self width], [self height]);
    
    SequenceDecoding.sequenceIdentifier = 0;
    
    displayFPS = [[FrameCounter alloc] init];
    receiveFPS = [[FrameCounter alloc] init];
    
	return self;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [startupCamera]
//
- (CameraError) startupWithUsbLocationId: (UInt32) usbLocationId
{
	CameraError error;
    
    if (error = [self usbConnectToCam:usbLocationId configIdx:0]) 
        return error; // setup connection to camera
    
    mainToButtonThreadConnection = NULL;
    buttonToMainThreadConnection = NULL;
    
    if (error == CameraErrorOK && buttonInterrupt)  // Start a buttonThread if button sends an interrupt (USB)
    {
        id threadData = NULL;
        
        if (doNotificationsOnMainThread) 
        {
            NSPort * port1 = [NSPort port];
            NSPort * port2 = [NSPort port];
            mainToButtonThreadConnection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
            [mainToButtonThreadConnection setRootObject:self];
            threadData = [NSArray arrayWithObjects:port2,port1,NULL];
        }
        
        buttonThreadShouldBeActing = NO; // Not yet
        buttonThreadShouldBeRunning = YES;
        buttonThreadRunning = YES;
        [NSThread detachNewThreadSelector:@selector(buttonThread:) toTarget:self withObject:threadData];
    }
    
//#if REALLY_VERBOSE
    NSLog(@"GenericDriver init, info = \n");
    NSLog(@" cid = %i\n", [cameraInfo cid]);
    NSLog(@" VID = 0x%04X\n", [cameraInfo vendorID]);
    NSLog(@" PID = 0x%04X\n", [cameraInfo productID]);
    NSLog(@" lid = 0x%08X\n", [cameraInfo locationID]);
    NSLog(@" version = 0x%04X\n", [cameraInfo versionNumber]);
    NSLog(@" name = %@\n", [cameraInfo cameraName]);
    NSLog(@" driver = %i\n", [cameraInfo driver]);
    NSLog(@" driver class name = %@\n", NSStringFromClass([cameraInfo driverClass]));
//#endif
    
    [self startupCamera];
    
	return [super startupWithUsbLocationId:usbLocationId];
}

//
// Subclass this for more functionality
//
- (void) startupCamera
{
	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setHue:0.5];
	[self setSharpness:0.5];
    
    if ([self canSetAutoGain]) 
        [self setAutoGain:YES];
}

//
// Subclass if needed, don't forget to call [super]
//
- (void) dealloc 
{
	if (bayerConverter) 
        [bayerConverter release];
	bayerConverter = NULL;
    
    if (LUT) 
        [LUT release];
    LUT = NULL;
    
	[self cleanupGrabContext];
    
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
// The following methods work for drivers that use the BayerConverter
////////////////////////////////////////////////////////////////////////////////

//
// Brightness
//
- (BOOL) canSetBrightness 
{
    return (bayerConverter != NULL || LUT != NULL || hardwareBrightness) ? YES : NO;
}

- (void) setBrightness: (float) v 
{
	[super setBrightness:v];
    
    if (bayerConverter != NULL && !hardwareBrightness) 
        [bayerConverter setBrightness:[self brightness] - 0.5f];
    
    if (LUT != NULL && !hardwareBrightness) 
        [LUT setBrightness:[self brightness] - 0.5f];
}

//
// Contrast
//
- (BOOL) canSetContrast 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareContrast) ? YES : NO;
}

- (void) setContrast: (float) v 
{
	[super setContrast:v];
    
    if (bayerConverter != NULL && !hardwareContrast) 
        [bayerConverter setContrast:[self contrast] + 0.5f];
    
    if (LUT != NULL && !hardwareContrast) 
        [LUT setContrast:[self contrast] + 0.5f];
}

//
// Gamma
//
- (BOOL) canSetGamma 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareGamma) ? YES : NO;
}

- (void) setGamma: (float) v 
{
    [super setGamma:v];
    
    if (bayerConverter != NULL && !hardwareGamma) 
        [bayerConverter setGamma:[self gamma] + 0.5f];
    
    if (LUT != NULL && !hardwareGamma) 
        [LUT setGamma:[self gamma] + 0.5f];
}

//
// Saturation
//
- (BOOL) canSetSaturation 
{ 
    return (bayerConverter != NULL || LUT != NULL || hardwareSaturation) ? YES : NO;
}

- (void) setSaturation: (float) v 
{
    [super setSaturation:v];
    
    if (bayerConverter != NULL && !hardwareSaturation) 
        [bayerConverter setSaturation:[self saturation] * 2.0f];
    
    if (LUT != NULL && !hardwareSaturation) 
        [LUT setSaturation:[self saturation] * 2.0f];
}

//
// Hue
//
- (BOOL) canSetHue 
{ 
    return (hardwareHue) ? YES : NO;
}

//
// Sharpness
//
- (BOOL) canSetSharpness 
{ 
    return (bayerConverter != NULL || hardwareSharpness) ? YES : NO;
}

- (void) setSharpness: (float) v 
{
    [super setSharpness:v];
    
    if (bayerConverter != NULL && !hardwareSharpness) 
        [bayerConverter setSharpness:[self sharpness]];
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return (bayerConverter != NULL) ? YES : NO;
}


- (void) setAutoGain:(BOOL) v
{
    [super setAutoGain:v];
    
    if (bayerConverter != NULL) 
        [bayerConverter setMakeImageStats:v];
}

// Orientation

- (BOOL) canSetOrientationTo:(OrientationMode) m
{
    if (LUT != NULL) 
        return YES;
    else if (bayerConverter != NULL) 
        return YES;
    else 
        return [super canSetOrientationTo:m];
}

- (OrientationMode) orientation
{
    if (LUT != NULL) 
        return [LUT getOrientationSetting];
    else if (bayerConverter != NULL) 
    {
        if (rotate && hFlip) 
            return InvertVertical;
        else if (rotate) 
            return Rotate180;
        else if (hFlip) 
            return FlipHorizontal;
        else 
            return NormalOrientation;
    }
    else 
        return [super orientation];
}

- (void) setOrientation:(OrientationMode) m
{
    if (LUT != NULL) 
        [LUT setOrientationSetting:m];
    else if (bayerConverter != NULL) 
    {
        switch (m) 
        {
            case NormalOrientation:
                hFlip = NO;
                rotate = NO;
                break;
                
            case FlipHorizontal:
                hFlip = YES;
                rotate = NO;
                break;
                
            case InvertVertical:
                hFlip = YES;
                rotate = YES;
                break;
                
            case Rotate180:
                hFlip = NO;
                rotate = YES;
                break;
        }
    }
    else 
        [super setOrientation:m];
}

//
// Horizontal flip (mirror)
// Remember to pass the hFlip value to [BayerConverter convertFromSrc...]
//
- (BOOL) canSetHFlip 
{
    return (bayerConverter != NULL) ? YES : NO;
}

//
// Flicker
//
- (BOOL) canSetFlicker
{ 
    return (hardwareFlicker) ? YES : NO;
}

//
// WhiteBalance
//
- (BOOL) canSetWhiteBalanceMode 
{
    return (bayerConverter != NULL || LUT != NULL) ? YES : NO;
}

- (BOOL) canSetWhiteBalanceModeTo: (WhiteBalanceMode) newMode 
{
    BOOL ok = NO;
    
    switch (newMode) 
    {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
            ok = bayerConverter != NULL || LUT != NULL;
            break;
            
        case WhiteBalanceAutomatic:
            ok = bayerConverter != NULL;
            break;
            
        default:
            ok = NO;
            break;
    }
    
    return ok;
}

- (void) setWhiteBalanceMode: (WhiteBalanceMode) newMode 
{
    [super setWhiteBalanceMode:newMode];
    
    if (bayerConverter == NULL && LUT == NULL) 
        return;
    
    switch (whiteBalanceMode) 
    {
        case WhiteBalanceLinear:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
            
        case WhiteBalanceIndoor:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:0.8f green:0.97f blue:1.25f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:0.8f green:0.97f blue:1.25f];
            break;
            
        case WhiteBalanceOutdoor:
            if (bayerConverter != NULL) 
            {
                [bayerConverter setGainsDynamic:NO];
                [bayerConverter setGainsRed:1.1f green:0.95f blue:0.95f];
            }
            if (LUT != NULL) 
                [LUT setGainsRed:1.1f green:0.95f blue:0.95f];
            break;
            
        case WhiteBalanceAutomatic:
            if (bayerConverter != NULL) 
                [bayerConverter setGainsDynamic:YES];
            break;
            
        case WhiteBalanceManual:
            // not handled yet
            break;
    }
}

////////////////////////////////////////////////////////////////////////////////

//
// Returns the pipe used for grabbing
// Subclass if necessary
//
- (UInt8) getGrabbingPipe
{
    return 1;
}

//
// Setup the alt-interface and pipe to use for grabbing
// This *must* be subclassed for non-Bulk drivers
//
// Return YES if everything is ok
//
- (BOOL) setGrabInterfacePipe
{
//  return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]]; // copy and change the alt-interface
    return (driverType == bulkDriver) ? YES : NO;
}

//
// Make the right sequence of USB calls to get the stream going
// If anything goes wrong, return NO
// This *must* be subclassed
//
- (BOOL) startupGrabStream 
{
    return NO;
}

//
// Make the right sequence of USB calls to shut the stream down
// This *must* be subclassed
//
- (void) shutdownGrabStream 
{
//  [self usbSetAltInterfaceTo:0 testPipe:0]; // Reset to control pipe -- normal could be a different alt than 0!
}

//
// A new function for scanning the isochronous frames must be provided if a suitable 
// one does not already exist. 
//
IsocFrameResult  genericIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    return invalidFrame;
}

//
// This version can probably be used by most cameras
// Headers and footers can be skipped by specifying the proper start and lengths in the scanner
//
// If data needs to be modified (and it cannot be [efficiently] done in the decoder) 
// then this is place to make those modifications
//
int  genericIsocDataCopier(void * destination, const void * source, size_t length, size_t available)
{
    if (length > available-1) 
        length = available-1;
    
    memcpy(destination, source, length);
    
    return length;
}

//
// This *must* be subclassed
// Provide the correct functions for the camera
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = genericIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


//
// Avoid subclassing this method if possible
// Instead put functionality into [setIsocFrameFunctions]
// and of course [startupGrabStream] and [shutdownGrabStream]
//
- (BOOL) setupGrabContext 
{
    BOOL ok = YES;
    int i, j;
    
    for (i = 0; i < GENERIC_MAX_TRANSFERS; i++) 
    {
        grabContext.transferPointers[i].transferIndex = i;
        grabContext.transferPointers[i].context = &grabContext;
    }
    
    if (driverType == isochronousDriver) 
    {
        grabContext.numberOfTransfers = GENERIC_NUM_TRANSFERS;
        grabContext.numberOfFramesPerTransfer = GENERIC_FRAMES_PER_TRANSFER;
    }
    else 
    {
        grabContext.numberOfTransfers = GENERIC_NUM_TRANSFERS;
        grabContext.numberOfFramesPerTransfer = 1;
    }
    grabContext.numberOfChunkBuffers = GENERIC_NUM_CHUNK_BUFFERS;
    
    grabContext.imageWidth = [self width];
    grabContext.imageHeight = [self height];
    grabContext.chunkBufferLength = [self width] * [self height] * 4 + 10000; // That should be more than enough, but should include any JPEG header
    
    grabContext.maxFramesBetweenChunks = 1000; // That's a second. Normally we should get at least one chunk per second
    
    grabContext.headerLength = 0;
    grabContext.headerData = NULL;
    
    [self setIsocFrameFunctions];  // can also adjust number of transfers, frames, buffers, buffer-sizes
    
    if (grabContext.numberOfTransfers > GENERIC_MAX_TRANSFERS) 
        grabContext.numberOfTransfers = GENERIC_MAX_TRANSFERS;
    
    if (grabContext.numberOfFramesPerTransfer > GENERIC_FRAMES_PER_TRANSFER) 
        grabContext.numberOfFramesPerTransfer = GENERIC_FRAMES_PER_TRANSFER;
    
    if (grabContext.numberOfChunkBuffers > GENERIC_MAX_CHUNK_BUFFERS) 
        grabContext.numberOfChunkBuffers = GENERIC_MAX_CHUNK_BUFFERS;
    
    // Clear things that have to be set back if init() fails
    
    grabContext.chunkListLock = NULL;
    
    for (i = 0; i < grabContext.numberOfTransfers; i++) 
        grabContext.transferContexts[i].buffer = NULL;
    
    // Setup simple things
    
    grabContext.intf = streamIntf;
    grabContext.grabbingPipe = [self getGrabbingPipe];
    grabContext.bytesPerFrame = (driverType == isochronousDriver) ? [self usbGetIsocFrameSize] : 0;
    
    grabContext.shouldBeGrabbing = &shouldBeGrabbing;
    grabContext.contextError = CameraErrorOK;
    
    grabContext.initiatedUntil = 0; // Will be set later (directly before start)
    grabContext.finishedTransfers = 0;
    grabContext.framesSinceLastChunk = 0;
    
    grabContext.numFullBuffers = 0;
    grabContext.numEmptyBuffers = 0;
    grabContext.fillingChunk = false;
    
    grabContext.frameInfo.averageLuminance = 0;
    grabContext.frameInfo.averageLuminanceSet = 0;
    grabContext.frameInfo.averageSurroundLuminance = 0;
    grabContext.frameInfo.averageSurroundLuminanceSet = 0;
    grabContext.frameInfo.averageBlueGreen = 0;
    grabContext.frameInfo.averageBlueGreenSet = 0;
    grabContext.frameInfo.averageRedGreen = 0;
    grabContext.frameInfo.averageRedGreenSet = 0;
    
    [agc setFrameInfo:&grabContext.frameInfo];
    
    // Setup things that have to be set back if init fails
    
    if (ok) 
    {
        grabContext.chunkListLock = [[NSLock alloc] init];
        if (grabContext.chunkListLock == NULL) 
            ok = NO;
    }
    
    // Initialize transfer contexts
    
    if (ok) 
    {
        for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) 
        {
            for (j = 0; j < grabContext.numberOfFramesPerTransfer; j++) 
            {
                grabContext.transferContexts[i].frameList[j].frStatus = 0;
                grabContext.transferContexts[i].frameList[j].frReqCount = grabContext.bytesPerFrame;
                grabContext.transferContexts[i].frameList[j].frActCount = 0;
            }
            
            MALLOC(grabContext.transferContexts[i].buffer, UInt8 *,
                   grabContext.numberOfFramesPerTransfer * grabContext.bytesPerFrame, "isoc transfer buffer");
            
            if (grabContext.transferContexts[i].buffer == NULL) 
                ok = NO;
        }
    }
    
    // Initialize chunk buffers
    
    for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) 
    {
        MALLOC(grabContext.transferBuffers[i].buffer, UInt8 *, grabContext.chunkBufferLength, "Chunk transfer buffer");
        
        if (grabContext.transferBuffers[i].buffer == NULL) 
            ok = NO;
        else 
		{
            timerclear(&(grabContext.transferBuffers[i].tv));
            timerclear(&(grabContext.transferBuffers[i].tvStart));
            timerclear(&(grabContext.transferBuffers[i].tvDone));
		}
    }
    
    for (i = 0; ok && (i < grabContext.numberOfChunkBuffers); i++) 
    {
        MALLOC(grabContext.emptyChunkBuffers[i].buffer, UInt8 *, grabContext.chunkBufferLength, "Chunk buffer");
        
        if (grabContext.emptyChunkBuffers[i].buffer == NULL) 
            ok = NO;
        else 
		{
            grabContext.numEmptyBuffers = i + 1;
            timerclear(&(grabContext.emptyChunkBuffers[i].tv));
            timerclear(&(grabContext.emptyChunkBuffers[i].tvStart));
            timerclear(&(grabContext.emptyChunkBuffers[i].tvDone));
		}
    }
    
    // Cleanup if anything went wrong
    
    if (!ok) 
    {
        NSLog(@"setupGrabContext failed");
        [self cleanupGrabContext];
    }
    
    grabContext.receiveFPS = receiveFPS;
    
    return ok;
}

//
// Avoid subclassing this method if possible
//
- (void) cleanupGrabContext 
{
    int i;
    
    // Cleanup chunk list lock
    
    if (grabContext.chunkListLock != NULL) 
    {
        [grabContext.chunkListLock release];
        grabContext.chunkListLock = NULL;
    }
    
    // Cleanup bulk buffers
    
    for (i = 0; i < grabContext.numberOfTransfers; i++) 
    {
        if (grabContext.transferBuffers[i].buffer) 
        {
            FREE(grabContext.transferBuffers[i].buffer, "bulk data buffer");
            grabContext.transferBuffers[i].buffer = NULL;
        }
    }
    
    // Cleanup isoc buffers
    
    for (i = 0; i < grabContext.numberOfTransfers; i++) 
    {
        if (grabContext.transferContexts[i].buffer) 
        {
            FREE(grabContext.transferContexts[i].buffer, "isoc data buffer");
            grabContext.transferContexts[i].buffer = NULL;
        }
    }
    
    // Cleanup empty chunk buffers
    
    for (i = grabContext.numEmptyBuffers - 1; i >= 0; i--) 
    {
        if (grabContext.emptyChunkBuffers[i].buffer != NULL) 
        {
            FREE(grabContext.emptyChunkBuffers[i].buffer, "empty chunk buffer");
            grabContext.emptyChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numEmptyBuffers = 0;
    
    // Cleanup full chunk buffers
    
    for (i = grabContext.numFullBuffers - 1; i >= 0; i--) 
    {
        if (grabContext.fullChunkBuffers[i].buffer != NULL) 
        {
            FREE(grabContext.fullChunkBuffers[i].buffer, "full chunk buffer");
            grabContext.fullChunkBuffers[i].buffer = NULL;
        }
    }
    
    grabContext.numFullBuffers = 0;
    
    // Cleanup filling chunk buffer
    
    if (grabContext.fillingChunk) 
    {
        if (grabContext.fillingChunkBuffer.buffer != NULL) 
        {
            FREE(grabContext.fillingChunkBuffer.buffer, "filling chunk buffer");
            grabContext.fillingChunkBuffer.buffer = NULL;
        }
        
        grabContext.fillingChunk = false;
    }
}

//
// Forward declaration because both isocComplete() and startNextIsochRead() refer to each other
//
static bool startNextIsochRead(GenericGrabContext * grabbingContext, int transferIndex);
static bool startNextBulkRead(GenericGrabContext * grabbingContext, int transferIndex);

//
// Avoid recreating this function if possible
//
static void isocComplete(void * refcon, IOReturn result, void * arg0) 
{
    GenericGrabContext * gCtx = (GenericGrabContext *) refcon;
    IOUSBIsocFrame * myFrameList = (IOUSBIsocFrame *) arg0;
    short transferIdx = 0;
    bool frameListFound = false;
    UInt8 * frameBase;
    int i;
    
    static int droppedFrames = 0;
    static int droppedChunks = 0;
    
    // Handle result from isoc transfer
    
    switch (result) 
    {
        case kIOReturnSuccess: // No error -> alright
        case kIOReturnUnderrun: // Data hickup - not so serious
            result = 0;
            break;
            
        case kIOReturnOverrun:
        case kIOReturnTimeout:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorTimeout;
            break;
            
        default:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
            break;
    }
    CheckError(result, "isocComplete"); // Show errors (really needed here? -- actually yes!)

    // Look up which transfer we are
    
    if (*gCtx->shouldBeGrabbing) 
    {
        while (!frameListFound && (transferIdx < gCtx->numberOfTransfers)) 
        {
            if (gCtx->transferContexts[transferIdx].frameList == myFrameList) 
                frameListFound = true;
            else 
                transferIdx++;
        }
        
        if (!frameListFound) 
        {
            NSLog(@"isocComplete: Didn't find my frameList, very strange.");
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorInternal;
        }
    }

    // Parse returned data
    
    if (*gCtx->shouldBeGrabbing) 
    {
        for (i = 0; i < gCtx->numberOfFramesPerTransfer; i++) // Let's have a look into the usb frames we got
        {
            UInt32 dataStart, dataLength, tailStart, tailLength;
            
            frameBase = gCtx->transferContexts[transferIdx].buffer + gCtx->bytesPerFrame * i; // Is this right? It assumes possibly non-contiguous writing, if actual count < requested count [yes, seems to work, look at USB spec?]
            
            IsocFrameResult frameResult = (*gCtx->isocFrameScanner)(&myFrameList[i], frameBase, 
                                                &dataStart, &dataLength, &tailStart, &tailLength, &gCtx->frameInfo);
            
            if (frameResult == invalidFrame || myFrameList[i].frActCount == 0) 
            {
                droppedFrames++;
            }
            else if (frameResult == invalidChunk) 
            {
                droppedFrames = 0;
                droppedChunks++;
                gCtx->fillingChunkBuffer.numBytes = 0;
            }
            else if (frameResult == newChunkFrame) 
            {
                droppedFrames = 0;
                droppedChunks = 0;
                
                // When the new chunk starts in the middle of a frame, we must copy the tail to the old chunk
                
                if (gCtx->fillingChunk && tailLength > 0) 
                {
                    int add = (*gCtx->isocDataCopier)(gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes, frameBase + tailStart, tailLength, gCtx->chunkBufferLength - gCtx->fillingChunkBuffer.numBytes);
                    gCtx->fillingChunkBuffer.numBytes += add;
                }
                
                // Now we need to get a new chunk
                // Wait for access to the chunk buffers
                
                [gCtx->chunkListLock lock];
                
                // We were filling, first deal with the old chunk that is now full
                
                if (gCtx->fillingChunk) 
                {
                    int j;
                    
//                  printf("Chunk filled with %ld bytes\n", gCtx->fillingChunkBuffer.numBytes);
                    
					gettimeofday(&gCtx->fillingChunkBuffer.tvDone, NULL); // set the time of the buffer
					[gCtx->receiveFPS addFrame];
                    
                    // Pass the complete chunk to the full list
                    // Move full buffers one up
                    
                    for (j = gCtx->numFullBuffers - 1; j >= 0; j--) 
                        gCtx->fullChunkBuffers[j + 1] = gCtx->fullChunkBuffers[j];
                    
                    gCtx->fullChunkBuffers[0] = gCtx->fillingChunkBuffer; // Insert the filling one as newest
                    gCtx->numFullBuffers++;				// We have inserted one buffer
                                                        //  What if the list was already full? - That is not possible
                    gCtx->fillingChunk = false;			// Now we're not filling (still in the lock to be sure no buffer is lost)
                    gCtx->framesSinceLastChunk = 0;     // Reset watchdog
                } 
                // else // There was no current filling chunk. Just get a new one.
                
                // We still have the list access lock. Get a new buffer to fill.
                
                if (gCtx->numEmptyBuffers > 0) 			// There's an empty buffer to use
                {
                    gCtx->numEmptyBuffers--;
                    gCtx->fillingChunkBuffer = gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
                } 
                else // No empty buffer: discard a full one (there are enough, both lists can't be empty)
                {
                    gCtx->numFullBuffers--;             // Use the oldest one
                    gCtx->fillingChunkBuffer = gCtx->fullChunkBuffers[gCtx->numFullBuffers];
                }
                gCtx->fillingChunk = true;				// Now we're filling (still in the lock to be sure no buffer is lost)
                gCtx->fillingChunkBuffer.numBytes = 0;	// Start with empty buffer
                
                if (gCtx->headerLength > 0) 
                {
                    int add = (*gCtx->isocDataCopier)(gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes, 
                                                      gCtx->headerData, gCtx->headerLength, gCtx->chunkBufferLength - gCtx->fillingChunkBuffer.numBytes);
                    gCtx->fillingChunkBuffer.numBytes += add;
                }
                
                [gCtx->chunkListLock unlock];			// Free access to the chunk buffers
				
				gettimeofday(&gCtx->fillingChunkBuffer.tvStart, NULL); // set the time of the buffer
                gCtx->fillingChunkBuffer.tv = gCtx->fillingChunkBuffer.tvStart;
            }
            // else // validFrame 
            
            if (gCtx->fillingChunk && (dataLength > 0)) 
            {
                [gCtx->chunkListLock lock];
                int add = (*gCtx->isocDataCopier)(gCtx->fillingChunkBuffer.buffer + gCtx->fillingChunkBuffer.numBytes, 
                                                  frameBase + dataStart, dataLength, gCtx->chunkBufferLength - gCtx->fillingChunkBuffer.numBytes);
                gCtx->fillingChunkBuffer.numBytes += add;
                [gCtx->chunkListLock unlock];
            }
        }
        
        gCtx->framesSinceLastChunk += gCtx->numberOfFramesPerTransfer; // Count frames (not necessary to be too precise here...)
        
        if (gCtx->framesSinceLastChunk > gCtx->maxFramesBetweenChunks) // Too long without a frame? Something is wrong. 
        {
            NSLog(@"GenericDriver: grab aborted because of invalid data stream (too long without a frame, %i invalid frames, %i invalid chunks)", droppedFrames, droppedChunks);
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
        }
    }
    
    // Initiate next transfer
    
    if (*gCtx->shouldBeGrabbing) 
    {
        if (!startNextIsochRead(gCtx, transferIdx)) 
            *gCtx->shouldBeGrabbing = NO;
    }
    
    // Shutdown cleanup: Collect finished transfers and exit if all transfers have ended
    
    if (!(*gCtx->shouldBeGrabbing)) 
    {
        droppedFrames = 0;
        gCtx->finishedTransfers++;
        if (gCtx->finishedTransfers >= gCtx->numberOfTransfers) 
            CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

//
// Avoid recreating this function if possible
// Return true if everything is OK
//
static bool startNextIsochRead(GenericGrabContext * gCtx, int transferIdx) 
{
    IOReturn error;
    
    error = (*gCtx->intf)->ReadIsochPipeAsync(gCtx->intf,
                                                 gCtx->grabbingPipe,
                                                 gCtx->transferContexts[transferIdx].buffer,
                                                 gCtx->initiatedUntil,
                                                 gCtx->numberOfFramesPerTransfer,
                                                 gCtx->transferContexts[transferIdx].frameList,
                                                 (IOAsyncCallback1) (isocComplete),
                                                 gCtx);
    
    gCtx->initiatedUntil += gCtx->numberOfFramesPerTransfer;
    
    switch (error) 
    {
        case kIOReturnSuccess:
            break;
            
        case kIOReturnNoDevice:
        case kIOReturnNotOpen:
        default:
            CheckError(error, "startNextIsochRead-ReadIsochPipeAsync");
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
            break;
    }
    
    return (error == kIOReturnSuccess);
}


static void bulkComplete(void * refcon, IOReturn result, void * arg0) 
{
    ContextAndIndex * ref = (ContextAndIndex *) refcon;
    GenericGrabContext * gCtx = (GenericGrabContext *) ref->context;
    short transferIdx = ref->transferIndex;
    UInt32 bytesReceived = (UInt32) arg0;
    
    // Handle result from bulk transfer
    
    switch (result) 
    {
        case kIOReturnSuccess: // No error -> alright
        case kIOReturnUnderrun: // Data hickup - not so serious
            result = 0;
            break;
            
        case kIOReturnOverrun:
        case kIOReturnTimeout:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorTimeout;
                break;
            
        default:
            *gCtx->shouldBeGrabbing = NO;
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
                break;
    }
    
    CheckError(result, "bulkComplete"); // Show errors (really needed here? -- actually yes!)
    
    // Parse returned data
    
    if (*gCtx->shouldBeGrabbing && bytesReceived > 0) 
    {
        int j;
        GenericChunkBuffer chunk;
        unsigned char * savePointer;
        
        // Now we need to get a new chunk
        // Wait for access to the chunk buffers
        
        [gCtx->chunkListLock lock];
        
        // First get a chunk
        // Switch the buffers
        // Put it in the full list
        
        // We have the list access lock. Get a new buffer to fill.
        
        if (gCtx->numFullBuffers == GENERIC_MAX_CHUNK_BUFFERS ||
            gCtx->numEmptyBuffers == 0) 
        {
            gCtx->numFullBuffers--;  // Use the oldest one
            chunk = gCtx->fullChunkBuffers[gCtx->numFullBuffers];
        }
        else  // There's an empty buffer to use
        {
            gCtx->numEmptyBuffers--;
            chunk = gCtx->emptyChunkBuffers[gCtx->numEmptyBuffers];
        }
        
        chunk.numBytes = bytesReceived;
        gettimeofday(&chunk.tvStart, NULL); // set the time of the buffer
        chunk.tv = chunk.tvDone = chunk.tvStart;
        [gCtx->receiveFPS addFrame];
        
        // Pass the complete chunk to the full list
        // Move full buffers one up
        
        for (j = gCtx->numFullBuffers - 1; j >= 0; j--) 
            gCtx->fullChunkBuffers[j + 1] = gCtx->fullChunkBuffers[j];
        
        // Switch the pointers around
        
        savePointer = chunk.buffer;
        chunk.buffer = gCtx->transferBuffers[transferIdx].buffer;
        gCtx->transferBuffers[transferIdx].buffer = savePointer;
        
        // We have anew full buffer
        
        gCtx->fullChunkBuffers[0] = chunk;  // Insert the filling one as newest
        gCtx->numFullBuffers++;				// We have inserted one buffer
        
        [gCtx->chunkListLock unlock];		// Free access to the chunk buffers
    }
    
    // Initiate next transfer
    
    if (*gCtx->shouldBeGrabbing) 
    {
        if (!startNextBulkRead(gCtx, transferIdx)) 
            *gCtx->shouldBeGrabbing = NO;
    }
    
    // Shutdown cleanup: Collect finished transfers and exit if all transfers have ended
    
    if (!(*gCtx->shouldBeGrabbing)) 
    {
        gCtx->finishedTransfers++;
        if (gCtx->finishedTransfers >= gCtx->numberOfTransfers) 
            CFRunLoopStop(CFRunLoopGetCurrent());
    }
}


static bool startNextBulkRead(GenericGrabContext * gCtx, int transferIdx) 
{
    IOReturn error;
    
    error = (*gCtx->intf)->ReadPipeAsync(gCtx->intf,
                                         gCtx->grabbingPipe,
                                         gCtx->transferBuffers[transferIdx].buffer,
                                         gCtx->chunkBufferLength,
                                         (IOAsyncCallback1) (bulkComplete),
                                         &gCtx->transferPointers[transferIdx]);
    
    switch (error) 
    {
        case kIOReturnSuccess:
            break;
            
        case kIOReturnNoDevice:
        case kIOReturnNotOpen:
        default:
            CheckError(error, "startNextBulkRead-ReadPipeAsync");
            if (gCtx->contextError == CameraErrorOK) 
                gCtx->contextError = CameraErrorUSBProblem;
                break;
    }
    
    return (error == kIOReturnSuccess);
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [setGrabInterfacePipe], [startupGrabStream] and [shutdownGrabStream]
//
- (void) grabbingThread:(id) data 
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    CFRunLoopSourceRef cfSource;
    IOReturn error;
    BOOL ok = YES;
    long i;
    
    [histogram setWidth:[self width] andHeight:[self height]];
#ifdef DEBUG
    [histogram setView:[(MyController *) [[self central] delegate] getHistogramView]];
#endif
    
    if (ok && driverType == isochronousDriver) 
        ChangeMyThreadPriority(10);	// We need to update the isoch read in time, so timing is important for us
    
    // Start the stream
    
    if (ok) 
        ok = [self startupGrabStream];
    
    // Get USB timing info
    
    if (ok && driverType == isochronousDriver) 
    {
        if (![self usbGetSoon:&(grabContext.initiatedUntil)]) 
        {
            ok = NO;
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorUSBProblem; // Did the pipe stall perhaps?
        }
    }
    
    // Set up the asynchronous read calls
    
    if (ok) 
    {
        error = (*streamIntf)->CreateInterfaceAsyncEventSource(streamIntf, &cfSource); // Create an event source
        CheckError(error, "CreateInterfaceAsyncEventSource");
        if (error) 
        {
            ok = NO;
            shouldBeGrabbing = NO;
            if (grabContext.contextError == CameraErrorOK) 
                grabContext.contextError = CameraErrorNoMem;
        }
    }
    
    if (ok)
    {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Add it to our run loop
        
        if (driverType == bulkDriver) 
            for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) // Initiate transfers
                ok = startNextBulkRead(&grabContext, i);
        
        if (driverType == isochronousDriver) 
            for (i = 0; ok && (i < grabContext.numberOfTransfers); i++) // Initiate transfers
                ok = startNextIsochRead(&grabContext, i);
    }
    
    // Activate the snapshot mechanism (thread is already running if there is one)
    
    buttonThreadShouldBeActing = YES;
    
    // Go into the RunLoop until we are done
    
    if (ok) 
    {
        CFRunLoopRun(); // Do our run loop
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode); // Remove the event source
    }
    
    // Stop the stream, reset the USB, close down 
    
    [self shutdownGrabStream];
    
    shouldBeGrabbing = NO; // Error in grabbingThread or abort? initiate shutdown of everything else
    
    // Exit the thread cleanly
    
    [pool release];
    grabbingThreadRunning = NO;
    [NSThread exit];
}


- (BOOL) setupDecoding 
{
    BOOL ok = NO;
    
    switch (compressionType) 
    {
        case noCompression: 
            ok = YES;
            break;
            
        case jpegCompression:
#if VERBOSE
            printf("JPEG compression is being used, ");
            printf("decompression using method %d\n", jpegVersion);
#endif
            ok = [self setupJpegCompression];
            break;
            
        case quicktimeImage:
#if VERBOSE
            printf("QuickTime image-based decoding is being used.\n");
#endif
            ok = [self setupQuicktimeImageCompression];
            break;
            
        case quicktimeSequence:
#if VERBOSE
            printf("QuickTime sequence-based decoding is being used.\n");
#endif
            ok = [self setupQuicktimeSequenceCompression];
            break;
            
        case gspcaCompression:
            ok = YES;
            break;
            
        case proprietaryCompression:
            ok = YES;
            break;
            
        case unknownCompression: 
        default:
            break;
    }
    
    return ok;
}


- (BOOL) setupJpegCompression
{
    BOOL result = NO;
    
    switch (jpegVersion) 
    {
        case 0:
            printf("Error: [setupJpegCompression] should be implemented in current driver!\n");
            break;
            
        case 1:
            result = [self setupJpegVersion1];
            break;
            
        case 2:
            result = [self setupJpegVersion2];
            break;
            
        case 3:
            quicktimeCodec = kJPEGCodecType;
            compressionType = quicktimeImage;
            break;
            
        case 4:
            quicktimeCodec = kJPEGCodecType;
            compressionType = quicktimeSequence;
            break;
            
        case 5:
            quicktimeCodec = kMotionJPEGACodecType;
            compressionType = quicktimeImage;
            break;
            
        case 6:
            quicktimeCodec = kMotionJPEGACodecType;
            compressionType = quicktimeSequence;
            break;
            
        case 7:
            quicktimeCodec = kMotionJPEGBCodecType;
            compressionType = quicktimeImage;
            break;
            
        case 8:
            quicktimeCodec = kMotionJPEGBCodecType;
            compressionType = quicktimeSequence;
            break;
            
        default:
            printf("Error: JPEG decoding version %d does not exist yet!\n", jpegVersion);
            break;
    }
    
    if (compressionType != jpegCompression) 
        result = [self setupDecoding];  // Call this again in the same chain, hope this works OK
    
    return result;
}


- (BOOL) setupJpegVersion1
{
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    
    CocoaDecoding.imageRep = [NSBitmapImageRep alloc];
    CocoaDecoding.imageRep = [CocoaDecoding.imageRep initWithBitmapDataPlanes:NULL
                                                               pixelsWide:[self width]
                                                               pixelsHigh:[self height]
                                                            bitsPerSample:8
                                                          samplesPerPixel:4
                                                                 hasAlpha:YES
                                                                 isPlanar:NO
                                                           colorSpaceName:NSDeviceRGBColorSpace
                                                              bytesPerRow:4 * [self width]
                                                             bitsPerPixel:4 * 8];
    
    // use CGBitmapContextCreate() instead??
    /*
     00270                 CGColorSpaceRef colorspace_ref = (image_depth == 8) ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
     00271                 
     00272                 if (!colorspace_ref)
     00273                         return false;
     00274                 
     00275                 CGImageAlphaInfo alpha_info = (image_depth == 8) ? kCGImageAlphaNone : kCGImageAlphaPremultipliedLast; //kCGImageAlphaLast; //RGBA format
     00276 
     00277                 context_ref = CGBitmapContextCreate(buffer->data, (size_t)image_size.width, (size_t)image_size.height, 8, buffer_rowbytes, colorspace_ref, alpha_info);
     00278 
     00279                 if (context_ref)
     00280                 {
         00281                         CGContextSetFillColorSpace(context_ref, colorspace_ref);
         00282                         CGContextSetStrokeColorSpace(context_ref, colorspace_ref);
         00283                         // move down, and flip vertically 
             00284                         // to turn postscript style coordinates to "screen style"
             00285                         CGContextTranslateCTM(context_ref, 0.0, image_size.height);
         00286                         CGContextScaleCTM(context_ref, 1.0, -1.0);
         00287                 }
     00288                 
     00289                 CGColorSpaceRelease(colorspace_ref);
     00290                 colorspace_ref = NULL;
     */
    
    /*
     CGColorSpaceRef CreateSystemColorSpace () 
     {
         CMProfileRef sysprof = NULL;
         CGColorSpaceRef dispColorSpace = NULL;
         
         // Get the Systems Profile for the main display
         if (CMGetSystemProfile(&sysprof) == noErr)
         {
             // Create a colorspace with the systems profile
             dispColorSpace = CGColorSpaceCreateWithPlatformColorSpace(sysprof);
             
             // Close the profile
             CMCloseProfile(sysprof);
         }
         
         return dispColorSpace;
     }
     */
    
    CMProfileRef sysprof = NULL;
    CGColorSpaceRef dispColorSpace = NULL;
    
    // Get the Systems Profile for the main display
    if (CMGetSystemProfile(&sysprof) == noErr)
    {
        // Create a colorspace with the systems profile
        dispColorSpace = CGColorSpaceCreateWithPlatformColorSpace(sysprof);
        
        // Close the profile
        CMCloseProfile(sysprof);
    }
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    CocoaDecoding.imageContext = CGBitmapContextCreate( [CocoaDecoding.imageRep bitmapData],
                                                        [self width], [self height], 8, 4 * [self width],
                                                        colorspace, kCGImageAlphaPremultipliedLast);
    
    CGColorSpaceRelease(colorspace);
    CGColorSpaceRelease(dispColorSpace);
    
    return YES;
}


- (BOOL) setupJpegVersion2
{
    CocoaDecoding.rect = CGRectMake(0, 0, [self width], [self height]);
    
    CocoaDecoding.imageRep = [NSBitmapImageRep alloc];
    CocoaDecoding.imageRep = [CocoaDecoding.imageRep initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:[self width]
                                                                   pixelsHigh:[self height]
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:4 * [self width]
                                                                 bitsPerPixel:4 * 8];
    
    //  This only works with 32 bits/pixel ARGB
    //  bitmapGC = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    
    //  Need this for pre 10.4 compatibility?
    CocoaDecoding.bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:
        [NSDictionary dictionaryWithObject:CocoaDecoding.imageRep forKey:NSGraphicsContextDestinationAttributeName]];
    //  NSGraphicsContext * bitmapGC = [NSGraphicsContext graphicsContextWithAttributes:<#(NSDictionary *)attributes#>];
    
    CocoaDecoding.imageContext = (CGContextRef) [CocoaDecoding.bitmapGC graphicsPort];
    
    return YES;
}

- (BOOL) setupQuicktimeImageCompression
{
//    OSErr err;
    BOOL ok = YES;
    
    SetQDRect(&QuicktimeDecoding.boundsRect, 0, 0, [self width], [self height]);
    
/*    
    err = QTNewGWorld(&QuicktimeDecoding.gworldPtr,     // returned GWorld
    				  k32ARGBPixelFormat,               // pixel format
    				  &QuicktimeDecoding.boundsRect,    // bounding rectangle
    				  0,                                // color table
    				  NULL,                             // graphic device handle
    				  0);                               // flags
    
    if (err) 
        ok = NO;
    
    QuicktimeDecoding.imageRep = [NSBitmapImageRep alloc];
    QuicktimeDecoding.imageRep = [QuicktimeDecoding.imageRep initWithBitmapDataPlanes:GetPixBaseAddr(GetGWorldPixMap(QuicktimeDecoding.gworldPtr)) 
                                                                   pixelsWide:[self width]
                                                                   pixelsHigh:[self height]
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:4 * [self width]
                                                                 bitsPerPixel:4 * 8];
    
    if (QuicktimeDecoding.imageRep == NULL) 
        ok = NO;
*/    
    
    QuicktimeDecoding.imageDescription = (ImageDescriptionHandle) NewHandle(sizeof(ImageDescription));
        
    (**QuicktimeDecoding.imageDescription).idSize = sizeof(ImageDescription);
    (**QuicktimeDecoding.imageDescription).cType = quicktimeCodec;
    (**QuicktimeDecoding.imageDescription).resvd1 = 0;
    (**QuicktimeDecoding.imageDescription).resvd2 = 0;
    (**QuicktimeDecoding.imageDescription).dataRefIndex = 0;
    (**QuicktimeDecoding.imageDescription).version = 1;
    (**QuicktimeDecoding.imageDescription).revisionLevel = 1;
    (**QuicktimeDecoding.imageDescription).vendor = 'appl';
    (**QuicktimeDecoding.imageDescription).temporalQuality = codecNormalQuality;
    (**QuicktimeDecoding.imageDescription).spatialQuality = codecNormalQuality;
    
    (**QuicktimeDecoding.imageDescription).width = [self width];
    (**QuicktimeDecoding.imageDescription).height = [self height];
    (**QuicktimeDecoding.imageDescription).hRes = (72 << 16);
    (**QuicktimeDecoding.imageDescription).vRes = (72 << 16);
    (**QuicktimeDecoding.imageDescription).dataSize = 0;
    (**QuicktimeDecoding.imageDescription).frameCount = 1;
    (**QuicktimeDecoding.imageDescription).name[0] =  6;
    (**QuicktimeDecoding.imageDescription).name[1] = 'C';
    (**QuicktimeDecoding.imageDescription).name[2] = 'a';
    (**QuicktimeDecoding.imageDescription).name[3] = 'm';
    (**QuicktimeDecoding.imageDescription).name[4] = 'e';
    (**QuicktimeDecoding.imageDescription).name[5] = 'r';
    (**QuicktimeDecoding.imageDescription).name[6] = 'a';
    (**QuicktimeDecoding.imageDescription).name[7] =  0;
    (**QuicktimeDecoding.imageDescription).depth = 24;
    (**QuicktimeDecoding.imageDescription).clutID = -1;
    
    return ok;
}

// Not working yet
- (BOOL) setupQuicktimeSequenceCompression
{
    BOOL ok = [self setupQuicktimeImageCompression];
    MatrixRecord scaleMatrix;
    OSErr err;
    
    RectMatrix(&scaleMatrix, &QuicktimeDecoding.boundsRect, &QuicktimeDecoding.boundsRect);
    
    err = QTNewGWorld(&QuicktimeDecoding.gworldPtr,     // returned GWorld
                      (nextImageBufferBPP == 4) ? k32ARGBPixelFormat : k24RGBPixelFormat,               // pixel format
                      &QuicktimeDecoding.boundsRect,    // bounding rectangle
                      0,                                // color table
                      NULL,                             // graphic device handle
                      0);                               // flags
    
    if (err) 
        ok = NO;
    
    err = DecompressSequenceBeginS(&SequenceDecoding.sequenceIdentifier, 
                            QuicktimeDecoding.imageDescription, 
                                   NULL, 
                                   0, 
                            QuicktimeDecoding.gworldPtr, 
                            NULL, 
                            NULL, 
                            &scaleMatrix, 
                            srcCopy,
                            NULL, 
                            0, // codecFlagUseImageBuffer, // codecFlagUseImageBuffer ? or 0 ?
                            codecNormalQuality, 
                            NULL);
    
    if (err) 
        ok = NO;
    
    return ok;
}

- (void) cleanupDecoding
{
    if (CocoaDecoding.imageRep != NULL) 
       [CocoaDecoding.imageRep release];
    CocoaDecoding.imageRep = NULL;
    
    if (QuicktimeDecoding.imageDescription != NULL) 
        DisposeHandle((Handle) QuicktimeDecoding.imageDescription);
    QuicktimeDecoding.imageDescription = NULL;
    
    // gworld
    
    // imagerep
    
    if (SequenceDecoding.sequenceIdentifier != 0) 
        CDSequenceEnd(SequenceDecoding.sequenceIdentifier);
    SequenceDecoding.sequenceIdentifier = 0;
}

//
// Avoid subclassing this method if possible
// Instead put functionality into [decodeBuffer]
//
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    grabbingThreadRunning = NO;
    
    // Try to get as much bandwidth as possible somehow?
    
    if (shouldBeGrabbing && ![self setGrabInterfacePipe]) 
    {
        error = CameraErrorNoBandwidth; // Probably means not enough bandwidth
        shouldBeGrabbing = NO;
    }
    
    // Initialize grab context
    
    if (shouldBeGrabbing && ![self setupGrabContext]) 
    {
        error = CameraErrorNoMem;
        shouldBeGrabbing = NO;
    }
    
    // Initialize image decoding
    
    if (shouldBeGrabbing && ![self setupDecoding]) 
    {
        error = CameraErrorDecoding;
        shouldBeGrabbing = NO;
    }
    
    // Start the grabbing thread
    
    if (shouldBeGrabbing) 
    {
        grabbingThreadRunning = YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];
    }
    
    // The decoding loop
    
    while (shouldBeGrabbing) 
    {
        if (grabContext.numFullBuffers == 0) 
            usleep(1000); // 1 ms (1000 micro-seconds)
        
        while (shouldBeGrabbing && (grabContext.numFullBuffers > 0)) 
        {
//            int j;
            GenericChunkBuffer currentBuffer;   // The buffer to decode
            
            // Get a full buffer
            
            [grabContext.chunkListLock lock];   // Get access to the buffer lists
            grabContext.numFullBuffers--;       // There's always one since no one else can empty it completely
            
            currentBuffer = grabContext.fullChunkBuffers[grabContext.numFullBuffers];  // Grab oldest
            
//            currentBuffer = grabContext.fullChunkBuffers[0];  // Grab newest
//            for (j = 0; j < grabContext.numFullBuffers; j++) 
//                grabContext.fullChunkBuffers[j] = grabContext.fullChunkBuffers[j + 1];
            
            [grabContext.chunkListLock unlock]; // Release access to the buffer lists
            
            // Do the decoding
            
            if (nextImageBufferSet) 
            {
                BOOL decodingOK = NO;
                
                [imageBufferLock lock]; // Lock image buffer access
                
                if (nextImageBuffer != NULL) 
                {
                    // decode start time
                    decodingOK = [self decodeBuffer:&currentBuffer]; // Into nextImageBuffer
                    // decode end time
                }
                
                if (decodingOK) 
                {
                    lastImageBuffer = nextImageBuffer; // Copy nextBuffer info into lastBuffer
                    lastImageBufferBPP = nextImageBufferBPP;
                    lastImageBufferRowBytes = nextImageBufferRowBytes;
                    
                    lastImageBufferTimeVal = currentBuffer.tv;
                    
                    nextImageBufferSet = NO;  // nextBuffer has been eaten up
                }
                
                [imageBufferLock unlock]; // Release lock
                
                if (decodingOK) 
                    [self mergeImageReady];   // Notify delegate about the image. Perhaps get a new buffer
            }
            
            // Put the chunk buffer back to the empty ones
            
            [grabContext.chunkListLock lock];   // Get access to the buffer lists
            grabContext.emptyChunkBuffers[grabContext.numEmptyBuffers] = currentBuffer;
            grabContext.numEmptyBuffers++;
            [grabContext.chunkListLock unlock]; // Release access to the buffer lists            
        }
    }
    
    // Shutdown, but wait for grabbingThread finish first
    
    while (grabbingThreadRunning) 
    {
        usleep(10000); // Sleep for 10 ms, then try again
    }
    
    [self cleanupGrabContext];
    [self cleanupDecoding];
    
    if (error == CameraErrorOK) 
        error = grabContext.contextError; // Return the error from the context if there was one
    
    return error;
}


- (UInt8) getButtonPipe
{
    return 2;
}


- (void) shutdown
{
    if (buttonThreadRunning || buttonThreadShouldBeRunning) 
    {
        buttonThreadShouldBeRunning = NO;
        buttonThreadShouldBeActing = NO;
        
        if ((streamIntf) && (isUSBOK)) 
            (*streamIntf)->AbortPipe(streamIntf, [self getButtonPipe]);
        
        while (buttonThreadRunning) 
            usleep(10000); 
    }
    
    if (buttonToMainThreadConnection) 
    {
        [buttonToMainThreadConnection release];
        buttonToMainThreadConnection = NULL;
    }
    
    if (mainToButtonThreadConnection) 
    {
        [mainToButtonThreadConnection release];
        mainToButtonThreadConnection = NULL;
    }
    
    [super shutdown];
}

//
//  This must be sub-classed for a real button handler
//
- (BOOL) buttonDataHandler:(UInt8 *)data length:(UInt32)length
{
#ifdef VERBOSE
    NSLog(@"Button Down?: unknown data on interrupt pipe:%i, %i (%i)", data[0], data[1], length);
#endif
    
    return NO;
}


- (void) buttonThread:(id)data 
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    if (data) 
    {
        buttonToMainThreadConnection=[[NSConnection alloc] initWithReceivePort:[data objectAtIndex:0] sendPort:[data objectAtIndex:1]];
    }
    
    while (buttonThreadShouldBeRunning && isUSBOK) 
    {
        UInt32 length = buttonMessageLength;
        unsigned char camData[length];
        
        (*streamIntf)->ReadPipe(streamIntf, [self getButtonPipe], camData, &length);
        
        if ([self buttonDataHandler:camData length:length]) 
            if (buttonThreadShouldBeRunning && buttonThreadShouldBeActing) 
                [self mergeCameraEventHappened:CameraEventSnapshotButtonDown];

            /*
            switch (camData) 
            {
                case 16:	//Button down
                    [self mergeCameraEventHappened:CameraEventSnapshotButtonDown];
                    break;
                case 17:	//Button up
                    [self mergeCameraEventHappened:CameraEventSnapshotButtonUp];
                    break;
				case   0:
					// with CIF happening on grab start/stopon my QCE w/o button [added by mark.asbach]
                case 194:	//sometimes sent on grab start / stop
                    break;
                default:
            */
    }
    
    buttonThreadRunning = NO;
    
    [pool release];
    [NSThread exit];
}


- (void) mergeCameraEventHappened:(CameraEvent)evt
{
    if (doNotificationsOnMainThread) 
        if ([NSRunLoop currentRunLoop] != mainThreadRunLoop) 
            if (buttonToMainThreadConnection) 
            {
                [(id)[buttonToMainThreadConnection rootProxy] mergeCameraEventHappened:evt];
                return;
            }
    
    [self cameraEventHappened:self event:evt];
}


void BufferProviderRelease(void * info, const void * data, size_t size)
{
    if (info != NULL) 
    {
        // Odd
    }
    
    if (data != NULL) 
    {
        // Normal
    }
}


- (BOOL) decodeBufferCocoaJPEG: (GenericChunkBuffer *) buffer
{
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer->buffer, buffer->numBytes, BufferProviderRelease);
    CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, false /* interpolate */, kCGRenderingIntentDefault);
    
    CGContextDrawImage(CocoaDecoding.imageContext, CocoaDecoding.rect, image);
    
    CGContextFlush(CocoaDecoding.imageContext);
    
    CGDataProviderRelease(provider);
    CGImageRelease(image);
    
    [LUT processImageRep:CocoaDecoding.imageRep 
                  buffer:nextImageBuffer 
                 numRows:[self height] 
                rowBytes:nextImageBufferRowBytes 
                     bpp:nextImageBufferBPP];
    
    return YES;  // Wish there was a way to detect errors!
}


- (BOOL) decodeBufferQuicktimeImage: (GenericChunkBuffer *) buffer
{
    OSErr err;
    GWorldPtr gw;
    CGrafPtr oldPort;
    GDHandle oldGDev;
    
    err = QTNewGWorldFromPtr(&gw, (nextImageBufferBPP == 4) ? k32ARGBPixelFormat : k24RGBPixelFormat,
                             &QuicktimeDecoding.boundsRect,
                             NULL, NULL, 0,
                             nextImageBuffer,
                             nextImageBufferRowBytes);
    if (err) 
        return NO;
    
    (**QuicktimeDecoding.imageDescription).dataSize = buffer->numBytes;
    
    GetGWorld(&oldPort,&oldGDev);
    SetGWorld(gw, NULL);
    
    err = DecompressImage((Ptr) (buffer->buffer), 
                          QuicktimeDecoding.imageDescription,
                          GetGWorldPixMap(gw), 
                          NULL, 
                          &QuicktimeDecoding.boundsRect, 
                          srcCopy, NULL);
    
    SetGWorld(oldPort, oldGDev);
    DisposeGWorld(gw);
    
#if REALLY_VERBOSE
    if (err) 
        printf("QuickTime image decoding error!\n");
#endif
    
    if (LUT != NULL) 
        [LUT processImage:nextImageBuffer 
                  numRows:[self height] 
                 rowBytes:nextImageBufferRowBytes 
                      bpp:nextImageBufferBPP];
    
    return (err) ? NO : YES;
}



- (BOOL) decodeBufferQuicktimeSequence: (GenericChunkBuffer *) buffer
{
    OSErr err;
    
    err = DecompressSequenceFrameS(SequenceDecoding.sequenceIdentifier, 
                             (Ptr) (buffer->buffer + decodingSkipBytes),
                             buffer->numBytes - decodingSkipBytes, 0, NULL, NULL);
            
    [LUT processImageFrom:(UInt8 *) (* GetGWorldPixMap(QuicktimeDecoding.gworldPtr))->baseAddr
                     into:nextImageBuffer
                  numRows:[self height]
             fromRowBytes:(* GetGWorldPixMap(QuicktimeDecoding.gworldPtr))->rowBytes
             intoRowBytes:nextImageBufferRowBytes
                  fromBPP:(* GetGWorldPixMap(QuicktimeDecoding.gworldPtr))->pixelSize/8
               alphaFirst:NO];
    
#if REALLY_VERBOSE
    if (err) 
        printf("QuickTime Sequence decoding error!\n");
#endif
    
    return (err) ? NO : YES;
}

- (BOOL) decodeBufferJPEG: (GenericChunkBuffer *) buffer
{
    NSLog(@"Oops: [decodeBufferJPEG] needs to be implemented in current driver!");
    return NO;
}

- (BOOL) decodeBufferGSPCA: (GenericChunkBuffer *) buffer
{
    NSLog(@"Oops: [decodeBufferGSPCA] needs to be implemented in current driver!");
    return NO;
}

- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    NSLog(@"Oops: [decodeBufferProprietary] needs to be implemented in current driver!");
    return NO;
}

//
// Decode the chunk buffer into the nextImageBuffer
// This *must* be subclassed as the decoding is camera dependent
//
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    BOOL ok = YES;
    GenericChunkBuffer newBuffer;
    
    if ((exactBufferLength > 0) && (exactBufferLength != buffer->numBytes)) 
        return NO;
    
    if ((minimumBufferLength > 0) && (minimumBufferLength > buffer->numBytes)) 
        return NO;
    
#if REALLY_VERBOSE
//    printf("decoding a chunk with %ld bytes\n", buffer->numBytes);
    if (0) 
    {
        int b = 0;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
        b = 8;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
        b = buffer->numBytes - 8;
        printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);

        if (0) 
            for (b = 0; b < buffer->numBytes; b += 8) 
                printf("buffer[%3d..%3d] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", b, b+7, buffer->buffer[b+0], buffer->buffer[b+1], buffer->buffer[b+2], buffer->buffer[b+3], buffer->buffer[b+4], buffer->buffer[b+5], buffer->buffer[b+6], buffer->buffer[b+7]);
    }
#endif
    
    newBuffer.numBytes = buffer->numBytes - decodingSkipBytes;
    newBuffer.buffer = buffer->buffer + decodingSkipBytes;
    
    if (compressionType == jpegCompression) 
    {
        switch (jpegVersion) 
        {
            case 0:
                ok = [self decodeBufferJPEG:&newBuffer];
                break;
                
            default:
                NSLog(@"GenericDriver - decodeBuffer encountered unknown jpegVersion (%i)", jpegVersion);
            case 2:
            case 1:
                ok = [self decodeBufferCocoaJPEG:&newBuffer];
                break;
        }
    }
    else if (compressionType == quicktimeImage) 
    {
        ok = [self decodeBufferQuicktimeImage:&newBuffer];
    }
    else if (compressionType == quicktimeSequence) 
    {
        ok = [self decodeBufferQuicktimeSequence:&newBuffer];
    }
    else if (compressionType == noCompression) 
    {
        // ??? just the LUT copy?
    }
    else if (compressionType == gspcaCompression) 
    {
        ok = [self decodeBufferGSPCA:&newBuffer];
    }
    else if (compressionType == proprietaryCompression) 
    {
        ok = [self decodeBufferProprietary:&newBuffer];
    }
    else 
        NSLog(@"GenericDriver - decodeBuffer must be implemented");
    
    if (ok) 
    {
        [histogram setupBuffer:nextImageBuffer rowBytes:nextImageBufferRowBytes bytesPerPixel:nextImageBufferBPP];  // store (pointers to) data
        
        if ([self isAutoGain]) 
            [agc update:histogram];  // update histogram if necessary, compute agc
        
        [histogram draw];  // update histogram if necessary, draw in view already specified
    }
    
    [displayFPS addFrame];
    
    if ([displayFPS update]) 
    {
		[[central delegate] updateStatus:NULL fpsDisplay:[displayFPS getCumulativeFPS] fpsReceived:[receiveFPS getFPS]];
    }
    
    return ok;
}


- (int) dumpRegisters
{
	UInt8 regLN, regHN;
    
	printf("Camera Registers: ");
	for (regHN = 0; regHN < 0xf0; regHN += 0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self getRegister:regHN + regLN]);
	}
	printf("\n\n");
    
    if ([self getSensorRegister:0x00] < 0) 
        return 0; // probably not implemented
    
	printf("Sensor Registers: ");
	for (regHN = 0; regHN < 0x80; regHN += 0x10) {
		printf("\n    ");
		for (regLN = 0; regLN < 0x10; ++regLN)
			printf(" %02X=%02X", regHN + regLN, [self getSensorRegister:regHN + regLN]);
	}
	printf("\n\n");
    
    return 0;
}


- (NSTextField *) getDebugMessageField
{
    return [[central delegate] getDebugMessageField];
}

@end

// Some web-references for QuickTime image decoding
//
// The Image Description structure
// http://developer.apple.com/documentation/QuickTime/RM/CompressDecompress/ImageComprMgr/F-Chapter/chapter_1000_section_15.html
//
// http://developer.apple.com/documentation/QuickTime/Rm/CompressDecompress/ImageComprMgr/G-Chapter/chapter_1000_section_5.html#//apple_ref/doc/uid/TP40000878-HowtoCompressandDecompressSequencesofImages-ASampleProgramforCompressingandDecompressingaSequenceofImages
// http://developer.apple.com/quicktime/icefloe/dispatch008.html
// http://www.extremetech.com/article2/0,1697,1843577,00.asp
// http://www.cs.cf.ac.uk/Dave/Multimedia/node292.html
// http://developer.apple.com/documentation/QuickTime/RM/Fundamentals/QTOverview/QTOverview_Document/chapter_1000_section_2.html
// http://developer.apple.com/documentation/QuickTime/Rm/CompressDecompress/ImageComprMgr/A-Intro/chapter_1000_section_1.html
// http://homepage.mac.com/gregcoats/jp2.html
// http://www.google.com/search?client=safari&rls=en&q=quicktime+decompress+image+sample+code&ie=UTF-8&oe=UTF-8
// 
