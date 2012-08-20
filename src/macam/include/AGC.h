//
//  AGC.h
//  macam
//
//  Created by Harald on 3/16/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "Histogram.h"


typedef enum AGCMode
{
    agcNone,
    agcProvidedAverage,
    agcHistogram,
    
} AGCMode;


typedef enum AGCEffect 
{
    agcAffectNone,
    agcAffectGain,
    agcAffectOffset,
    agcAffectShutter,
    agcAffectBrightness,
    
} AGCEffect;


//
// Algorithm for Automatic Gain Control
//
// Some cameras do not have AGC built-in, but require driver-level support. 
//

@class MyCameraDriver;

//
// connect with Histogram, or use other data?
// 
// update often, but not necessarily every frame
// 
// keep track of recent changes, to understand effects
//


@interface AGC : NSObject 
{
    MyCameraDriver * driver;
    
    AGCMode mode;
    NSArray * list;
    
    BOOL trackBrightness;
    
    int effectCount;
    AGCEffect effect1;
    AGCEffect effect2;
    AGCEffect effect3;   
    
    int target;
    int delta;
    
    struct GenericFrameInfo * frameInfo;
    
    int fastUpdate;
    int slowUpdate;
    int updateInterval;
    struct timeval tvLastUpdate;
}

- (id) initWithDriver:(MyCameraDriver *) driver;

- (void) setMode:(AGCMode) newMode;
- (void) setEffects:(NSArray *) array;
- (void) setFrameInfo:(struct GenericFrameInfo *) frameInfo;
- (void) setBrightnessTracking:(BOOL) track;

- (BOOL) update:(Histogram *) histogram;
- (BOOL) updateProvided;
- (BOOL) updateHistogram:(Histogram *) histogram;

- (BOOL) updateVersion1:(int) middle;

@end
