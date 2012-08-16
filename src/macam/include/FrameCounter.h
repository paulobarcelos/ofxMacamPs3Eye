//
//  FrameCounter.h
//  macam
//
//  Created by Harald on 4/28/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#include <sys/time.h>

// add every frame, no need to compre times, just store if needed
// getFPS checks if time difference greaterthan interval, compute new FPS, new time etc
// otherwise return 


@interface FrameCounter : NSObject 
{
    BOOL timeset;
    struct timeval start;
    int frameCount;
    long interval;  // milli-seconds
    
    float cumulativeFPS;
    float currentFPS;
    float lastFPS;
}

- (id) init;

- (void) reset;
- (void) setInterval:(long) newInterval;

- (BOOL) update;
- (void) addFrame;

- (float) getFPS;
- (float) getCurrentFPS;
- (float) getCumulativeFPS;

@end
