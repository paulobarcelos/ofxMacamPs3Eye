//
//  Histogram.m
//  macam
//
//  Created by Harald on 3/7/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "Histogram.h"

#include <unistd.h>


@implementation Histogram


- (id) init
{
    self = [super init];
    
    [self reset];
    threshold = 10;
    width = 0;
    height = 0;
    
    buffer = NULL;
    rowBytes = 0;
    bytesPerPixel = 3;
    newBuffer = FALSE;
    
    image = NULL;
    view = NULL;
    
    gettimeofday(&tvCurrent, NULL);
    gettimeofday(&tvNew, NULL);
    gettimeofday(&tvLastDraw, NULL);
    
    middle = 0;
    low = 0;
    height = 0;
    
    return self;
}


- (void) reset
{
    int i;
    
    for (i = 0; i < 256; i++) 
        value[i] = 0;
    
    max = 0;
    total = 0;
    median = -1;
    centroid = -1;
    
    lowThreshold = -1;
    highThreshold = -1;
    lowPower = -1;
    highPower = -1;
}


- (void) setView:(NSImageView *) newView
{
    view = newView;
}


- (void) setWidth:(int)newWidth andHeight:(int)newHeight
{
    width = newWidth;
    height = newHeight;
}


- (void) setupBuffer:(UInt8 *)aBuffer rowBytes:(int)aRowBytes bytesPerPixel:(int)bpp
{
    gettimeofday(&tvNew, NULL);
    
    newBuffer = YES;
    
    buffer = aBuffer;
    rowBytes = aRowBytes;
    bytesPerPixel = bpp;
}


- (BOOL) processRGB
{
    int i, j;
    
    if (!newBuffer) 
        return NO;
    
    [self reset];
    
    for (j = 0; j < height; j++) 
    {
        UInt8 * p = buffer + j * rowBytes;
        
        for (i = 0; i < width; i++, p += bytesPerPixel) 
        {
            value[p[0]]++;
            value[p[1]]++;
            value[p[2]]++;
        }
    }
    
    tvCurrent = tvNew;
    newBuffer = NO;
    
    return YES;
}


- (BOOL) processOne
{
    int i, j;
    
    if (!newBuffer) 
        return NO;
    
    [self reset];
    
    for (j = 0; j < height; j++) 
    {
        UInt8 * p = buffer + j * rowBytes;
        
        for (i = 0; i < width; i++, p += bytesPerPixel) 
            value[*p]++;
    }
    
    tvCurrent = tvNew;
    newBuffer = NO;
    
    return YES;
}


- (void) calculateStatistics
{
    int i;
    
    int sum = 0;
    int weighted = 0;
    
    for (i = 0; i < 256; i++) 
    {
        if (max < value[i]) 
            max = value[i];
        
        sum += value[i];
        weighted += i * value[i];
    }
    
    total = sum;
    centroid = weighted / total;
    
    sum = 0;
    for (i = 0; i < 256; i++) 
    {
        sum += value[i];
        if (sum > total / 2) 
        {
            median = i;
            break;
        }
    }
    
    int limit = total * threshold / 100;
    
    sum = 0;
    for (i = 0; i < 256; i++) 
    {
        sum += value[i];
        if (sum > limit) 
        {
            lowThreshold = i;
            break;
        }
    }
    
    sum = 0;
    for (i = 255; i >= 0; i--) 
    {
        sum += value[i];
        if (sum > limit) 
        {
            highThreshold = i;
            break;
        }
    }
    
    int power = total * threshold / 1000;
    
    for (i = 0; i < 256; i++) 
        if (value[i] >= power) 
        {
            lowPower = i;
            break;
        }
    
    for (i = 255; i >= 0; i--) 
        if (value[i] >= power) 
        {
            highPower = i;
            break;
        }
}


- (int) getMedian
{
    if (median < 0) 
        [self calculateStatistics];
    
    return median;
}


- (int) getLowThreshold
{
    if (lowThreshold < 0) 
        [self calculateStatistics];
    
    return lowThreshold;
}


- (int) getHighThreshold
{
    if (highThreshold < 0) 
        [self calculateStatistics];
    
    return highThreshold;
}


- (int) getCentroid
{
    if (centroid < 0) 
        [self calculateStatistics];
    
    return centroid;
}


- (int) getLowPower
{
    if (lowPower < 0) 
        [self calculateStatistics];
    
    return lowPower;
}


- (int) getHighPower
{
    if (highPower < 0) 
        [self calculateStatistics];
    
    return highPower;
}


- (void) draw
{
    struct timeval currentTime, difference;
    int diffMilliSeconds;
    
    if (view == NULL) 
        return;
    
    gettimeofday(&currentTime, NULL);
    timersub(&currentTime, &tvLastDraw, &difference);
    diffMilliSeconds = (int) (difference.tv_sec * 1000 + difference.tv_usec / 1000);
    
//  NSLog(@"Histogram drawing difference = %d ms.\n", diffMilliSeconds);
    
    if (diffMilliSeconds < 500) 
        return;
    
    tvLastDraw = currentTime;
    [self processRGB];
    
    middle = [self getMedian];
    low = [self getLowThreshold];
    high = [self getHighThreshold];
    
    // draw
    
    int i;
    NSPoint from, to;
    NSRect bounds = [view bounds];
    
    if (image != NULL) 
        [image release];
    
    image = [[NSImage alloc] initWithSize:bounds.size];
    
    [image lockFocus];
    
    // Clear image
    
    [[NSColor lightGrayColor] set];
    [NSBezierPath fillRect:bounds];
    
    // Draw each bar of the histogram
    
    [[NSColor blackColor] set];
    from.y = 0.0;
    
    for (i = 0; i < 256; i++) 
    {
        from.x = to.x = i + 0.5;
        to.y = value[i] * bounds.size.height / (float) max;
        
        [NSBezierPath strokeLineFromPoint:from toPoint:to];
    }
    
    to.y = bounds.size.height;
    
    // Draw the middle (green) line
    
    [[NSColor greenColor] set];
    from.x = to.x = middle + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    
    // Draw the low and high (red) bars
    
    [[NSColor redColor] set];
    from.x = to.x = low + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    from.x = to.x = high + 0.5;
    [NSBezierPath strokeLineFromPoint:from toPoint:to];
    
    [image unlockFocus];
    
    [view setImage:image];
}


@end
