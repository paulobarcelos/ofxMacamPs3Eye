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
 
    $Id: GlobalDefs.h,v 1.14 2009/05/01 20:27:23 hxr Exp $
*/

/*
This is the global definitions file. It includes some compiling options, some convenience macros and some common enumerations / names for things. I include this file in EVERY HEADER FILE. This has the downside of having to recompile everything when something is changed here, but it's for sure that the options are available everywhere.
*/


#ifndef _GLOBALDEFS_
#define _GLOBALDEFS_


typedef enum WhiteBalanceMode 
{
    WhiteBalanceLinear		= 1,
    WhiteBalanceIndoor		= 2,
    WhiteBalanceOutdoor		= 3,
    WhiteBalanceAutomatic 	= 4,
    WhiteBalanceManual    	= 5,
} WhiteBalanceMode;


typedef enum CameraResolution 
{
    ResolutionInvalid = 0,	// Indicates a wrong or not applicable resolution
    ResolutionMin   = 1,    // This should not need to change
    ResolutionSQSIF = 1,	// SQSIF =  128 x  96
    ResolutionQSIF  = 2,	//  QSIF =  160 x 120, also known as QQVGA
    ResolutionQCIF  = 3,	//  QCIF =  176 x 144
    ResolutionSIF   = 4,	//   SIF =  320 x 240, also known as QVGA
    ResolutionCIF   = 5,	//   CIF =  352 x 288
    ResolutionVGA   = 6,	//   VGA =  640 x 480
    ResolutionSVGA  = 7,	//  SVGA =  800 x 600
    ResolutionXGA   = 8,	//   XGA = 1024 x 768
    ResolutionUXGA  = 9,	//  UXGA = 1600 x 1200
    
    ResolutionMax   = 9,    // This should ytack the largest resolution
} CameraResolution;


#define MaximumFPS  180


typedef enum CameraError 
{
    CameraErrorOK		     = 0,	// Everything's fine
    CameraErrorBusy		     = 1,	// Access to device denied - probably already in use somewhere else
    CameraErrorNoPower		 = 2,	// Not enough usb power to use device (there's also an independent system alert)
    CameraErrorNoCam		 = 3,	// No camera found
    CameraErrorNoMem		 = 4,	// Some memory allocation failed
    CameraErrorNoBandwidth	 = 5,	// The usb data bandwidth would be exceeded
    CameraErrorTimeout		 = 6,	// Failed to maintain the data stream in time
    CameraErrorUSBProblem	 = 7,	// An important USB command failed for no known reason
    CameraErrorUnimplemented = 8,	// A feature that is not (yet) implemented
    CameraErrorInternal		 = 9,	// Some other, probably serious, error
    CameraErrorDecoding		 = 10,	// An error related to the decoding of image data
    CameraErrorUSBNeedsUSB2  = 11,  // This camera *needs* USB2
    NumberOfCameraErrors = 12
} CameraError;

typedef enum ColorMode 
{
    ColorModeColor		= 1,
    ColorModeGray		= 2
} ColorMode;

typedef enum OrientationMode 
{
    NormalOrientation = 1,
    FlipHorizontal = 2, 
    InvertVertical = 3, 
    Rotate180 = 4,
} OrientationMode;


//Global build settings. Comment unwanted stuff out
// set these in the configuration (Debug, Release etc) build settings (preprocessor macros) instead

//#define VERBOSE 1

//#define REALLY_VERBOSE 1

/*
malloc/free tracking: Since I sometimes have to do "remote debugging" (send the code to someone else and ask what happens), I cannot use elaborate tools there. So I use macros for malloc and free so we can switch on memory logging to the console. The testers then can send the console log back. To switch on or off, uncomment or comment the next #define statement.
*/

//#define LOG_MEM_CALLS 1

/*
 QuickTime call tracking. It's sometimes interesting to see what kinds of calls the clients of the QuickTime Component actually do and in which order. So this opens the opportunity to log all calls to the console. To switch on or off, uncomment or comment the next #define statement.
 */

//#define LOG_QT_CALLS 1

/*
USB control tracking. Another sometimes interesting thing is to track the sequence of USB commands passed to the device. To switch on or off, uncomment or comment the next #define statement. Please note that this is still being incorporated into the code so not all USB commands may be logged yet.
 */

//#define LOG_USB_CALLS 1

//Some convenience macros

#ifdef LOG_MEM_CALLS
#define MALLOC(ptr,type,size,msg) { NSLog(@"malloc: %s",(msg)); ptr=(type)malloc(size); NSLog(@"malloc result: %d",((int)(ptr))); }
#define FREE(ptr,msg) { NSLog(@"free: %s %d",(msg),(ptr)); free(ptr); NSLog(@"free done"); }
#else
#define MALLOC(ptr,type,size,msg) ptr=(type)malloc(size)
#define FREE(ptr,msg) free(ptr)
#endif

#ifndef MAX
#define MAX(a,b) (((a)>(b))?(a):(b))
#endif

#ifndef MIN
#define MIN(a,b) (((a)<(b))?(a):(b))
#endif

#define CLAMP(a,b,c) (MIN(MAX(a,b),c))

//A shortcut for localization
#define LStr(a) NSLocalizedString(a,NULL)	

// This was only defined in 10.4, and is needed for compilation on previous systems
#ifndef IO_OBJECT_NULL
#define IO_OBJECT_NULL  NULL
#endif

#endif