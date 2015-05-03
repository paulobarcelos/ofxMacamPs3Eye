//
//  FrameCounter.m
//  macam
//
//  Created by Harald on 4/28/08.
//  Copyright 2008 hxr. All rights reserved.
//

#import "FrameCounter.h"

#include <unistd.h>


@implementation FrameCounter

- (id) init
{
	self = [super init];
	if (self == NULL) 
        return NULL;
    
    [self reset];
    
    interval = 1000;
    
    return self;
}


- (void) reset
{
    timeset = NO;
    frameCount = 0;
    cumulativeFPS = 0.0;
    currentFPS = 0.0;
    lastFPS = 0.0;
}


- (void) setInterval:(long) newInterval
{
    interval = newInterval;
}


- (void) addFrame
{
    if (!timeset) 
    {
        gettimeofday(&start, NULL);
        timeset = YES;
    }
    
    frameCount++;
}


- (BOOL) update
{
    struct timeval currentTime, difference;
    int diffMilliSeconds;
    
    if (frameCount < currentFPS) 
        return NO;
    
    // check the time
    // update if necessary
    
    gettimeofday(&currentTime, NULL);
    timersub(&currentTime, &start, &difference);
    diffMilliSeconds = (int) (difference.tv_sec * 1000 + difference.tv_usec / 1000);
    
    //    NSLog(@"update difference = %d ms.\n", diffMilliSeconds);
    
    if (diffMilliSeconds < interval) 
        return NO;
    
    int count = frameCount;
    frameCount = 0;
    float newFPS = 1000.0 * count / diffMilliSeconds;
    
    frameCount = 0;
    start = currentTime;
    
    lastFPS = currentFPS;
    currentFPS = newFPS;
    cumulativeFPS = (newFPS + cumulativeFPS) / 2;
    
    return YES;
}


- (float) getFPS
{
    [self update];
    
    return (currentFPS + lastFPS) / 2;
}


- (float) getCurrentFPS
{
    [self update];
    
    return currentFPS;
}


- (float) getCumulativeFPS
{
    [self update];
    
    return cumulativeFPS;
}

@end
