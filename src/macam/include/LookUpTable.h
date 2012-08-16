//
//  LookUpTable.h
//
//  macam - webcam app and QuickTime driver component
//
//  Created by hxr on 6/20/06.
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
//  The LookUpTable was created to permit the adjustment of brightness, contrast, 
//  saturation and gamma for those cameras that do not allow it in hardware, or 
//  use a Bayer decoding structure that allows it. Consequently, the interface 
//  follows the BayerDecoder; in fact, it may make sense to subclass the BayerDecoder
//  from this class, as the BayerDecoder extends the interface. 
//


#import <Cocoa/Cocoa.h>

#include "GlobalDefs.h"


@interface LookUpTable : NSObject 
{
    float contrast;
    float brightness;
    float gamma;
    long saturation;
    
    unsigned char redTransferLookup[256];
    unsigned char greenTransferLookup[256];
    unsigned char blueTransferLookup[256];
    
    BOOL updateGains;
    BOOL needsTransferLookup;
    
    // Individual gains for white balance correction
    
    float redGain;
    float greenGain;
    float blueGain;
    
    OrientationMode defaultMode;
    OrientationMode modeSetting;
}

// Start/stop
- (id) init;

// LUT functions
- (UInt8) red:(UInt8)r  green:(int)g;
- (UInt8) green:(UInt8)g;
- (UInt8) blue:(UInt8)b green:(int)g;
- (void) processTriplet:(UInt8 *)tripletIn toHere:(UInt8 *)tripletOut;
- (void) processTriplet:(UInt8 *)tripletIn toHere:(UInt8 *)tripletOut bidirectional:(BOOL)swap;

// Whole image functions
- (void) processImageFrom:(UInt8 *)srcBuffer into:(UInt8 *)dstBuffer numRows:(long)numRows fromRowBytes:(long)srcRowBytes intoRowBytes:(long)dstRowBytes fromBPP:(short)srcBPP alphaFirst:(BOOL)alphaFirst;
- (void) processImage:(UInt8 *)buffer numRows:(long)numRows rowBytes:(long)rowBytes bpp:(short)bpp;
- (void) processImageRep:(NSBitmapImageRep *)imageRep buffer:(UInt8 *)buffer numRows:(long)numRows rowBytes:(long)rowBytes bpp:(short)bpp;

- (void) untwistImage:(UInt8 *)srcBuffer width:(int)width height:(int)height into:(UInt8 *)dstBuffer rowBytes:(int)dstRowBytes bpp:(short)dstBPP;

// Get/set properties
- (float) brightness;	//[-1.0 ... 1.0], 0.0 = no change, more = brighter
- (void) setBrightness:(float)newBrightness;
- (float) contrast;	//[0.0 ... 2.0], 1.0 = no change, more = more contrast
- (void) setContrast:(float)newContrast;
- (float) gamma;	//[0.0 ... 2.0], 1.0 = no change, more = darker grey
- (void) setGamma:(float)newGamma;
- (float) saturation;	//[0.0 ... 2.0], 1.0 = no change, less = less saturation
- (void) setSaturation:(float)newSaturation;
- (void) setGainsRed:(float)r green:(float)g blue:(float)b;
- (void) setDefaultOrientation:(OrientationMode)mode;
- (void) setOrientationSetting:(OrientationMode)mode;
- (OrientationMode) getOrientationSetting;

- (OrientationMode) combineOrientationMode:(OrientationMode)mode1 with:(OrientationMode)mode2;

- (void) recalcTransferLookup;

@end
