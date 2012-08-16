//
//  LookUpTable.m
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


#import "LookUpTable.h"


@implementation LookUpTable

- (id) init 
{
    self = [super init];
    
    brightness=0.0f;
    contrast=1.0f;
    gamma=1.0f;
    saturation=65536;
    redGain=1.0f;
    greenGain=1.0f;
    blueGain=1.0f;
    [self recalcTransferLookup];
    
    defaultMode = NormalOrientation;
    modeSetting = NormalOrientation;
    
    return self;
}

- (float) brightness { return brightness; }

- (void) setBrightness:(float)newBrightness 
{
    brightness=CLAMP(newBrightness,-1.0f,1.0f);
    [self recalcTransferLookup];
}

- (float) contrast { return contrast; }

- (void) setContrast:(float)newContrast 
{
    contrast=CLAMP(newContrast,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) gamma { return gamma; }

- (void) setGamma:(float)newGamma {
    gamma=CLAMP(newGamma,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) saturation { return ((float)saturation)/65536.0f; }

- (void) setSaturation:(float)newSaturation 
{
    saturation=65536.0f*CLAMP(newSaturation,0.0f,2.0f);
}


- (void) setGainsRed:(float)r green:(float)g blue:(float)b 
{
    redGain=r;
    greenGain=g;
    blueGain=b;
    [self recalcTransferLookup];
}


- (void) setDefaultOrientation:(OrientationMode)mode
{
    defaultMode = mode;
}

- (void) setOrientationSetting:(OrientationMode)mode
{
    modeSetting = mode;
}

- (OrientationMode) getOrientationSetting
{
    return modeSetting;
}


- (OrientationMode) combineOrientationMode:(OrientationMode)mode1 with:(OrientationMode)mode2
{
    OrientationMode result = NormalOrientation;
    
    if (mode1 == mode2) 
        return NormalOrientation;
    
    if (mode1 == NormalOrientation) 
        return mode2;
    
    if (mode2 == NormalOrientation) 
        return mode1;
    
    if (mode1 == FlipHorizontal) 
    {
        if (mode2 == InvertVertical) 
            return Rotate180;
        
        if (mode2 == Rotate180) 
            return InvertVertical;
        
        // error, should not get here
        
        return result;
    }
    else if (mode1 == InvertVertical) 
    {
        if (mode2 == FlipHorizontal) 
            return Rotate180;
        
        if (mode2 == Rotate180) 
            return FlipHorizontal;
        
        // error, should not get here
        
        return result;
    }
    else if (mode1 == Rotate180) 
    {
        if (mode2 == FlipHorizontal) 
            return InvertVertical;
        
        if (mode2 == InvertVertical) 
            return FlipHorizontal;
        
        // error, should not get here
        
        return result;
    }
    
    // error, should not get here
    
    return result;
}



- (UInt8) red: (UInt8) r  green: (int) g
{
    int rr = (((r - g) * saturation) / 65536) + g;
    return redTransferLookup[CLAMP(rr,0,255)];
}


- (UInt8) green: (UInt8) g
{
    return greenTransferLookup[g];
}


- (UInt8) blue: (UInt8) b  green: (int) g
{
    int bb = (((b - g) * saturation) / 65536) + g;
    return blueTransferLookup[CLAMP(bb,0,255)];
}


- (void) processTriplet:(UInt8 *)tripletIn toHere:(UInt8 *)tripletOut
{
    if (needsTransferLookup) 
    {
        int g =    tripletIn[1];
        int r = (((tripletIn[0] - g) * saturation) / 65536) + g;
        int b = (((tripletIn[2] - g) * saturation) / 65536) + g;
        
        tripletOut[0] = redTransferLookup[CLAMP(r,0,255)];
        tripletOut[1] = greenTransferLookup[CLAMP(g,0,255)];
        tripletOut[2] = blueTransferLookup[CLAMP(b,0,255)];
    }
    else 
    {
        tripletOut[0] = tripletIn[0];
        tripletOut[1] = tripletIn[1];
        tripletOut[2] = tripletIn[2];
    }
}

- (void) processTriplet:(UInt8 *)tripletIn toHere:(UInt8 *)tripletOut bidirectional:(BOOL)swap
{
    if (swap) 
    {
        UInt8 swap[3];
        
        swap[0] = tripletOut[0];
        swap[1] = tripletOut[1];
        swap[2] = tripletOut[2];
            
        [self processTriplet:tripletIn toHere:tripletOut];
        [self processTriplet:swap toHere:tripletIn];
    }
    else 
        [self processTriplet:tripletIn toHere:tripletOut];
}


//
// processImage - applies a bunch of processing to the image "in place"
// 
// including:
// - orientation, taking into account default mode as well as current setting
// - gamma
// - brightness
// - contrast
// - saturation
// - gain (separate for red, green. blue)
//
// In general, the processing is efficient, operations are combined, done ony if necessary etc.
// Assuming the destination is a RGB buffer (no alpha, RGB order)
//
- (void) processImageFrom:(UInt8 *)srcBuffer into:(UInt8 *)dstBuffer numRows:(long)numRows fromRowBytes:(long)srcRowBytes intoRowBytes:(long)dstRowBytes fromBPP:(short)srcBPP alphaFirst:(BOOL)alphaFirst
{
    UInt8 * srcPtr;
    UInt8 * dstPtr;
    long  w, h;
    BOOL swap = NO;
    short dstBPP = 3;
    short useBPP = dstBPP;
    long endRows = numRows;
    long endRowBytes = srcRowBytes;
    
    OrientationMode orientation = [self combineOrientationMode:defaultMode with:modeSetting];
    
    if (srcBuffer == dstBuffer) 
    {
        swap = YES;
        
        if (orientation == FlipHorizontal)
            endRowBytes = endRowBytes / 2;
        
        if (orientation == InvertVertical) 
            endRows = endRows / 2;
        
        if (orientation == Rotate180) 
            endRows = endRows / 2;  // cut either rows or columns in half, but not both
    }
    
    if (orientation != NormalOrientation) 
    {
        for (h = 0; h < endRows; h++) 
        {
            srcPtr = srcBuffer + h * srcRowBytes;
            dstPtr = dstBuffer + h * dstRowBytes;
            
            if (orientation == InvertVertical || orientation == Rotate180) 
                dstPtr = dstBuffer + (numRows - h - 1) * dstRowBytes;
            
            if (orientation == FlipHorizontal || orientation == Rotate180) 
            {
                dstPtr += dstRowBytes - dstBPP;
                useBPP = - dstBPP;
            }
            
            if (srcBPP == 4 && alphaFirst) 
                srcPtr++;
            
            for (w = 0; w < endRowBytes; w += srcBPP, srcPtr += srcBPP, dstPtr += useBPP) 
                [self processTriplet:srcPtr toHere:dstPtr bidirectional:swap];
        }
    }
    else if (srcBuffer != dstBuffer || needsTransferLookup) 
    {
        for (h = 0; h < endRows; h++) 
        {
            srcPtr = srcBuffer + h * srcRowBytes;
            dstPtr = dstBuffer + h * dstRowBytes;
            
            if (srcBPP == 4 && alphaFirst) 
                srcPtr++;
            
            for (w = 0; w < endRowBytes; w += srcBPP, srcPtr += srcBPP, dstPtr += useBPP) 
                [self processTriplet:srcPtr toHere:dstPtr];
        }
    }
    // else orintation is normal AND no lookuptransfer AND buffers are the same
}

//
// old version of call, always into itself
//
- (void) processImage:(UInt8 *)buffer numRows:(long)numRows rowBytes:(long)rowBytes bpp:(short)bpp
{
    [self processImageFrom:buffer into:buffer numRows:numRows fromRowBytes:rowBytes intoRowBytes:rowBytes fromBPP:bpp alphaFirst:NO];
}

//
// process a BitMap
//
- (void) processImageRep:(NSBitmapImageRep *)imageRep buffer:(UInt8 *)dstBuffer numRows:(long)numRows rowBytes:(long)dstRowBytes bpp:(short)dstBpp
{
    UInt8 * srcBuffer = [imageRep bitmapData];
    int srcBpp = [imageRep samplesPerPixel];
    int srcRowBytes = [imageRep bytesPerRow];
    BOOL alphaFirst = NO;
    
    if (dstBpp != 3) 
    {
        NSLog(@"Whoa! Trying to copy to a buffer that is *not* 3 samples per pixel. Can't do that!\n");
    }
    
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
    if ([imageRep respondsToSelector:@selector(bitmapFormat)]) 
    {
        NSBitmapFormat format = [imageRep bitmapFormat];
        alphaFirst = (format & NSAlphaFirstBitmapFormat) ? YES : NO;
    }
#endif
    
    [self processImageFrom:srcBuffer into:dstBuffer numRows:numRows fromRowBytes:srcRowBytes intoRowBytes:dstRowBytes fromBPP:srcBpp alphaFirst:alphaFirst];
    
/*    
    for (h = 0; h < numRows; h++) 
    {
        src = srcBuffer + h * srcRowBytes;
        dst = dstBuffer + h * dstRowBytes;
        
        for (w = 0; w < numColumns; w++) 
        {
            [self processTriplet:src toHere:dst];
            
            if (dstBpp == 4 && srcBpp == 4) 
                dst[3] = src[3];
            
            src += srcBpp;
            dst += dstBpp;
        }
    }
*/
}


//
//  take a column first image and turn it into a row first image
//  assume input image has 3bpp
//
- (void) untwistImage:(UInt8 *)srcBuffer width:(int)width height:(int)height into:(UInt8 *)dstBuffer rowBytes:(int)dstRowBytes bpp:(short)dstBPP
{
    UInt8 * srcPtr;
    UInt8 * dstPtr;
    long  w, h;
    short srcBPP = 3;
    int srcRowBytes = width * srcBPP;
    
    for (h = 0; h < height; h++) 
    {
        srcPtr = srcBuffer + h * srcRowBytes;

        for (w = 0; w < width; w++) 
        {
            dstPtr = dstBuffer + w * dstRowBytes + h * dstBPP;

            dstPtr[0] = srcPtr[0];
            dstPtr[1] = srcPtr[1];
            dstPtr[2] = srcPtr[2];
            
            srcPtr += srcBPP;
        }
    }
}


- (void) recalcTransferLookup 
{
    float f,r,g,b;
    short i;
    float sat=((float)saturation)/65536.0f;
    
    for (i=0;i<256;i++) 
    {
        f=((float)i)/255;
        f=pow(f,gamma);					//Bend to gamma
        f+=brightness;					//Offset brightness
        f=((f-0.5f)*contrast)+0.5f;			//Scale around 0.5
        f*=255.0f;					//Scale to [0..255]
        r=f*(sat*redGain+(1.0f-sat));			//Scale to red gain (itself scaled by saturation)
        g=f*(sat*greenGain+(1.0f-sat));			//Scale to green gain (itself scaled by saturation)
        b=f*(sat*blueGain+(1.0f-sat));			//Scale to blue gain (itself scaled by saturation)
        redTransferLookup[i]=CLAMP(r,0.0f,255.0f);	//Clamp and set
        greenTransferLookup[i]=CLAMP(g,0.0f,255.0f);	//Clamp and set
        blueTransferLookup[i]=CLAMP(b,0.0f,255.0f);;	//Clamp and set
    }
    
    // set this to avoid using these lookup tables if not necessary!
    
    needsTransferLookup=(gamma!=1.0f)||(brightness!=0.0f)||(contrast!=1.0f)
        ||(saturation!=65536)||(redGain!=1.0f)||(greenGain!=1.0f)||(blueGain!=1.0f);
}

@end
