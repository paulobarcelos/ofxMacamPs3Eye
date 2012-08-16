//
//  GenericDriver.h
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

// 
// This driver provides more of the common code that most drivers need, while 
// separating out the code that make cameras different into smaller routines. 
//
// To implement a new driver, subclass this class (GenericDriver) and implement
// all the required methods and any other methods that are necessary for the 
// specific camera. See the ExampleDriver for an example.
//

//
// Functionality still neeed:
// - working with JPEG images
// - USB2 high-speed transfers
//

#import "MyCameraDriver.h"
#import "BayerConverter.h"
#import "LookUpTable.h"

#include "sys/time.h"

typedef enum DriverType
{
    isochronousDriver,
    bulkDriver,
} DriverType;

// These seem to work well for many cameras

#define GENERIC_FRAMES_PER_TRANSFER  50
#define GENERIC_MAX_TRANSFERS         5
#define GENERIC_NUM_TRANSFERS         2
#define GENERIC_MAX_CHUNK_BUFFERS     9
#define GENERIC_NUM_CHUNK_BUFFERS     3

// Define some compression constants
// In general, these are for general algorithms that are used by more than one driver
// Proprietary compression code is provided in the specific drivers (e.g. Sonix)

typedef enum CompressionType
{
    unknownCompression,
    noCompression,
    jpegCompression,
    quicktimeImage,
    quicktimeSequence,
    gspcaCompression,
    proprietaryCompression,
} CompressionType;

// Some constants and functions for proccessing isochronous frames

typedef enum IsocFrameResult
{
    invalidFrame = 0,
    invalidChunk,
    validFrame,
    newChunkFrame
} IsocFrameResult;

typedef struct GenericFrameInfo
{
    int averageLuminance;
    int averageLuminanceSet;
    int averageSurroundLuminance;
    int averageSurroundLuminanceSet;
    int averageBlueGreen;
    int averageBlueGreenSet;
    int averageRedGreen;
    int averageRedGreenSet;
    
    int locationHint;
} GenericFrameInfo;

// Forward declarations

@class AGC;
@class Histogram;
@class FrameCounter;

// The scanner is just a placeholder whereas the copier is fully usable

IsocFrameResult  genericIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, UInt32 * dataStart, UInt32 * dataLength, UInt32 * tailStart, UInt32 * tailLength, GenericFrameInfo * frameInfo);
int  genericIsocDataCopier(void * destination, const void * source, size_t length, size_t available);

// Other versions can be added here in case of commonalities

IsocFrameResult  pac207IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, UInt32 * dataStart, UInt32 * dataLength, UInt32 * tailStart, UInt32 * tailLength, GenericFrameInfo * frameInfo);

// ...

// Everything a USB completion callback needs to know is stored in the GrabContext and related structures

typedef struct GenericTransferContext 
{
    IOUSBIsocFrame frameList[GENERIC_FRAMES_PER_TRANSFER]; // The results of the USB frames received
    UInt8 * buffer;                                        // This is the place the transfer goes to
} GenericTransferContext;

typedef struct GenericChunkBuffer 
{
    unsigned char * buffer; // The raw data for an image, it will need to be decoded in various ways
    long numBytes;          // The amount of valid data filled in so far
	struct timeval tv;      // The one to use for synchronization purposes
	struct timeval tvStart;
	struct timeval tvDone;
} GenericChunkBuffer;

typedef struct ContextAndIndex 
{
    int transferIndex;
    struct GenericGrabContext * context;
} ContextAndIndex;

typedef struct GenericGrabContext 
{
    ContextAndIndex transferPointers[GENERIC_MAX_TRANSFERS];
    
    int numberOfFramesPerTransfer;
    int numberOfTransfers;
    int numberOfChunkBuffers;
    
    int imageWidth;
    int imageHeight;
    
    IOUSBInterfaceInterface ** intf; // Just a copy of our interface interface so the callback can issue USB
    BOOL * shouldBeGrabbing;         // Ref to the global indicator if the grab should go on
    CameraError contextError;        // Return value for common errors during grab
    
    // function pointers for scanning the frames, different cameras have different frame information
    
    IsocFrameResult (* isocFrameScanner)(IOUSBIsocFrame * frame, UInt8 * buffer, UInt32 * dataStart, UInt32 * dataLength, UInt32 * tailStart, UInt32 * tailLength, GenericFrameInfo * frameInfo);
    int (* isocDataCopier)(void * destination, const void * source, size_t length, size_t available);
    
    UInt64 initiatedUntil;		  // The next USB frame number to initiate a transfer for
    short bytesPerFrame;		  // So many bytes are at max transferred per USB frame
    short finishedTransfers;	  // So many transfers have already finished (for cleanup)
    long framesSinceLastChunk;	  // Watchdog counter to detect invalid isoc data stream
    long maxFramesBetweenChunks;  // Normally abot a second, but may be set longer for long-exposures
    
    UInt8 grabbingPipe;           // The pipe used by the camer for grabbing, usually 1, but not always
    
    NSLock * chunkListLock;		  // The lock for access to the empty buffer pool/ full chunk queue
    long chunkBufferLength;		  // The size of the chunk buffers
    GenericTransferContext transferContexts[GENERIC_MAX_TRANSFERS];  // The transfer contexts
    GenericChunkBuffer transferBuffers[GENERIC_MAX_TRANSFERS]; // The pool of chunk buffers used for bulk 
    GenericChunkBuffer emptyChunkBuffers[GENERIC_MAX_CHUNK_BUFFERS]; // The pool of empty (ready-to-fill) chunk buffers
    GenericChunkBuffer fullChunkBuffers[GENERIC_MAX_CHUNK_BUFFERS];	 // The queue of full (ready-to-decode) chunk buffers (oldest=last)
    GenericChunkBuffer fillingChunkBuffer; // The chunk buffer currently filling up (only if fillingChunk == true)
    short numEmptyBuffers;		  // The number of empty (ready-to-fill) buffers in the array above
    short numFullBuffers;		  // The number of full (ready-to-decode) buffers in the array above
    bool  fillingChunk;			  // (true) if we're currently filling a buffer
    
    size_t  headerLength;
    void *  headerData;
    
    GenericFrameInfo frameInfo;   // Use this to get more information from the frame scanner
    
    FrameCounter * receiveFPS;
    
//  ImageType imageType;          // Is it Bayer, JPEG or something else?
} GenericGrabContext;

// Define the driver proper

@interface GenericDriver : MyCameraDriver 
{
    DriverType driverType;
    
    GenericGrabContext grabContext;
    BOOL grabbingThreadRunning;
    int videoBulkReadsPending;
    long exactBufferLength;
    long minimumBufferLength;
    
    BayerConverter * bayerConverter; // Our decoder for Bayer Matrix sensors, will be NULL if not a Bayer image
    LookUpTable * LUT; // Process brightness, contrast, saturation, and gamma for those without BayerConverters
    BOOL rotate;
    
    Histogram * histogram;
    AGC * agc;  // Automatic Gain Control software algorithm used for some cameras
    
    BOOL hardwareBrightness;
    BOOL hardwareContrast;
    BOOL hardwareSaturation;
    BOOL hardwareGamma;
    BOOL hardwareSharpness;
    BOOL hardwareHue;
    BOOL hardwareFlicker;
    
    BOOL buttonInterrupt;
    UInt32 buttonMessageLength;
    
    int decodingSkipBytes;
    
    CompressionType compressionType;
    int jpegVersion;
    UInt32 quicktimeCodec;
    
    struct // Using Cocoa decoding
    {
        CGRect              rect;
        NSBitmapImageRep  * imageRep;
        NSGraphicsContext * bitmapGC;
        CGContextRef        imageContext;
    } CocoaDecoding;
    
    struct // Using QuickTime decoding
    {
        GWorldPtr               gworldPtr;
        Rect                    boundsRect;
        NSBitmapImageRep  *     imageRep;
        ImageDescriptionHandle  imageDescription;
    } QuicktimeDecoding;
    
    struct // Using Image Compression Manager for decoding sequences
    {
        ImageSequence           sequenceIdentifier;
    } SequenceDecoding;
    
    BOOL buttonThreadRunning;
    BOOL buttonThreadShouldBeRunning;
    BOOL buttonThreadShouldBeActing;
    NSConnection * mainToButtonThreadConnection;
    NSConnection * buttonToMainThreadConnection;
    
    FrameCounter * displayFPS;
    FrameCounter * receiveFPS;
}

#pragma mark -> Subclass Unlikely to Implement (generic implementation) <-

- (CameraError) startupWithUsbLocationId: (UInt32) usbLocationId;
- (void) dealloc;
- (BOOL) setupGrabContext;
- (void) cleanupGrabContext;
- (void) grabbingThread: (id) data;
- (CameraError) decodingThread;

- (void) buttonThread:(id)data;
- (void) mergeCameraEventHappened:(CameraEvent)evt;

- (BOOL) setupDecoding;
- (BOOL) setupJpegCompression;
- (BOOL) setupJpegVersion1;
- (BOOL) setupJpegVersion2;
- (BOOL) setupQuicktimeImageCompression;
- (BOOL) setupQuicktimeSequenceCompression;
- (void) cleanupDecoding;

- (BOOL) decodeBufferCocoaJPEG: (GenericChunkBuffer *) buffer;
- (BOOL) decodeBufferQuicktimeImage: (GenericChunkBuffer *) buffer;
- (BOOL) decodeBufferQuicktimeSequence: (GenericChunkBuffer *) buffer;

- (NSTextField *) getDebugMessageField;

#pragma mark -> Subclass May Implement (works for BayerConverter) <-

- (BOOL) canSetBrightness;
- (void) setBrightness: (float) v;
- (BOOL) canSetContrast;
- (void) setContrast: (float) v;
- (BOOL) canSetGamma;
- (void) setGamma: (float) v;
- (BOOL) canSetSaturation;
- (void) setSaturation: (float) v;
- (BOOL) canSetHue;
- (BOOL) canSetSharpness;
- (void) setSharpness: (float) v;
- (BOOL) canSetHFlip;
- (BOOL) canSetFlicker;
- (BOOL) canSetWhiteBalanceMode;
- (BOOL) canSetWhiteBalanceModeTo: (WhiteBalanceMode) newMode;
- (void) setWhiteBalanceMode: (WhiteBalanceMode) newMode;

- (UInt8) getButtonPipe;
- (BOOL) buttonDataHandler:(UInt8 *)data length:(UInt32)length;

#pragma mark -> Subclass May Implement (default implementation works) <-

- (BOOL) canSetOrientationTo:(OrientationMode) m;
- (OrientationMode) orientation;
- (void) setOrientation:(OrientationMode) m;

- (void) startupCamera;
- (UInt8) getGrabbingPipe;
// specificIsocDataCopier()   // The existing version should work for most
// specificIsocFrameScanner() // If a suitable one does not already exist
- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer;  // Works for JPEG anyway
- (BOOL) decodeBufferJPEG: (GenericChunkBuffer *) buffer;
- (BOOL) decodeBufferGSPCA: (GenericChunkBuffer *) buffer;
- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer;

#pragma mark -> Subclass Must Implement! (Mostly stub implementations) <-

- (id) initWithCentral: (id) c; // Not a stub, make sure to call super in subclass
- (BOOL) setGrabInterfacePipe;
- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;
- (void) setIsocFrameFunctions;

@end
