//
//  AGC.m
//  macam
//
//  Created by Harald on 3/16/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "AGC.h"
#import "Histogram.h"
#import "GenericDriver.h"

#include <unistd.h>


@implementation AGC

- (id) initWithDriver:(MyCameraDriver *) theDriver
{
	self = [super init];
	if (self == NULL) 
        return NULL;
    
    driver = theDriver;
    
    mode = agcNone;
    list = NULL;
    effectCount = 0;
    
    trackBrightness = NO;
    
    target = 128;
    delta = 10;
    
    frameInfo = NULL;
    
    fastUpdate = 200;  // in ms
    slowUpdate = 1000;
    updateInterval = fastUpdate;
    gettimeofday(&tvLastUpdate, NULL);
    
    return self;
}


- (void) setMode:(AGCMode) newMode
{
    mode = newMode;
}


- (void) setFrameInfo:(GenericFrameInfo *) info
{
    frameInfo = info;
}


- (void) setBrightnessTracking:(BOOL) track
{
    trackBrightness = track;
}


- (void) setEffects:(NSArray *) array
{
    list = array;
    
    effectCount = [list count];
    
    effect1 = (effectCount > 0) ? (AGCEffect)[[list objectAtIndex:0] intValue] : agcAffectNone;
    effect2 = (effectCount > 1) ? (AGCEffect)[[list objectAtIndex:1] intValue] : agcAffectNone;
    effect3 = (effectCount > 2) ? (AGCEffect)[[list objectAtIndex:2] intValue] : agcAffectNone;
}


- (float) getEffect:(AGCEffect) effect
{
    switch (effect)
    {
        case agcAffectGain:
            return [driver gain];
            break;
            
        case agcAffectOffset: 
            return [driver offset];
            break;
            
        case agcAffectShutter: 
            return [driver shutter];
            break;
            
        case agcAffectBrightness:
            return [driver brightness];
            break;
            
        case agcAffectNone:
        default:
            break;
    }
    
    return 0.0;
}


- (float) getEffectStep:(AGCEffect) effect
{
    switch (effect)
    {
        case agcAffectGain:
            return [driver gainStep];
            break;
            
        case agcAffectOffset: 
            return [driver offsetStep];
            break;
            
        case agcAffectShutter: 
            return [driver shutterStep];
            break;
            
        case agcAffectBrightness:
            return [driver brightnessStep];
            break;
            
        case agcAffectNone:
        default:
            break;
    }
    
    return 1 / 255.0;
}


- (void) setEffect:(AGCEffect)effect toValue:(float)value
{
    switch (effect)
    {
        case agcAffectGain: 
            [driver setGain:value];
            break;
            
        case agcAffectOffset: 
            [driver setOffset:value];
            break;
            
        case agcAffectShutter: 
            [driver setShutter:value];
            break;
            
        case agcAffectBrightness: 
            [driver setBrightness:value];
            break;
            
        case agcAffectNone: 
        default: 
            break;
    }
}


- (BOOL) update:(Histogram *) histogram
{
    if (mode == agcNone) 
        return NO;
    
    if (trackBrightness) 
        target = 255 * [driver brightness];
    
    if (mode == agcProvidedAverage) 
        return [self updateProvided];
    
    if (mode == agcHistogram) 
        return [self updateHistogram:histogram];
    
    return NO;
}


- (BOOL) updateProvided
{
    // use grabContext.frameInfo.averageLuminanceSet?
    
    if (frameInfo == NULL) 
        return NO;
    
    if (frameInfo->averageLuminanceSet) 
    {
        frameInfo->averageLuminanceSet = 0;
        return [self updateVersion1:frameInfo->averageLuminance];
    }
    else 
        return NO;
}


- (BOOL) updateHistogram:(Histogram *) histogram
{
    struct timeval currentTime, difference;
    int diffMilliSeconds;
    
    // check the time
    // update histogram oif necessary
    
    gettimeofday(&currentTime, NULL);
    timersub(&currentTime, &tvLastUpdate, &difference);
    diffMilliSeconds = (int) (difference.tv_sec * 1000 + difference.tv_usec / 1000);
    
//    NSLog(@"update difference = %d ms.\n", diffMilliSeconds);
    
    if (diffMilliSeconds < updateInterval) 
        return NO;
    
    tvLastUpdate = currentTime;
    if (![histogram processRGB]) 
        return NO;
    
    return [self updateVersion1:[histogram getMedian]];
}


- (BOOL) updateVersion1:(int) middle
{
    BOOL change = NO;
    
    float e1 = [self getEffect:effect1];
    float e2 = [self getEffect:effect2];
    
    float e1step = [self getEffectStep:effect1];
    float e2step = [self getEffectStep:effect2];
    
    if (middle < (target - delta)) 
    {
        if (e1 < 1.0) 
        {
            e1 += e1step;
            e1 = (e1 > 1.0) ? 1.0 : e1;
            change = YES;
        }
        else if (e2 < 1.0) 
        {
            e2 += e2step;
            e2 = (e2 > 1.0) ? 1.0 : e2;
            change = YES;
        }
    }
    
    if (middle > (target + delta)) 
    {
        if (e1 > 0.0) 
        {
            e1 -= e1step;
            e1 = (e1 < 0.0) ? 0.0 : e1;
            change = YES;
        }
        else if (e2 > 0.0) 
        {
            e2 -= e2step;
            e2 = (e2 < 0.0) ? 0.0 : e2;
            change = YES;
        }
    }
    
    if (change) 
    {
        [self setEffect:effect1 toValue:e1];
        [self setEffect:effect2 toValue:e2];
        
#if REALLY_VERBOSE
        NSLog(@"setting effect1 to %f", e1);
        NSLog(@"setting effect2 to %f", e2);
#endif
        updateInterval = fastUpdate;
    }
    else 
    {
        updateInterval = slowUpdate;
    }
    
    return change;
}

@end
