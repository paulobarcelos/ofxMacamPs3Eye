//
//  Histogram.h
//  macam
//
//  Created by Harald on 3/7/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#include <sys/time.h>


@interface Histogram : NSObject 
{
    int value[256];
    
    int max;
    int total;
    int median;
    int centroid;
    
    int threshold;
    int lowThreshold;
    int highThreshold;
    int lowPower;
    int highPower;
    
    int width;
    int height;
    struct timeval tvCurrent;

    UInt8 * buffer;
    int rowBytes;
    int bytesPerPixel;
    BOOL  newBuffer;
    struct timeval tvNew;
    
    NSImage * image;
    NSImageView * view;
    int middle;
    int low;
    int high;
    struct timeval tvLastDraw;
}

- (id) init;
- (void) reset;

- (void) setWidth:(int)newWidth andHeight:(int)newHeight;
- (void) setupBuffer:(UInt8 *)buffer rowBytes:(int)rowBytes bytesPerPixel:(int)bpp;

- (BOOL) processRGB;
- (BOOL) processOne;

- (void) calculateStatistics;

- (int) getMedian;
- (int) getLowThreshold;
- (int) getHighThreshold;

- (int) getCentroid;
- (int) getLowPower;
- (int) getHighPower;

- (void) setView:(NSImageView *)view;
- (void) draw;

@end
