//
//  Sensor.m
//  macam
//
//  Created by Harald on 10/29/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import "Sensor.h"


@implementation Sensor


+ (id) findSensor:(MyCameraDriver*)driver
{
    id sensor = NULL;
    
    
    return sensor;
}


+ (UInt8) i2cReadAddress
{
    return 0x00;  //  return i2cAddress + 1;
}


+ (UInt8) i2cWriteAddress
{
    return 0x00;  //  return i2cAddress;
}


- (id) init
{
    self = [super init];
    
    return self;
}


- (int) configure
{
    return 0;
}

/*
registerStart
registerEnd
registerValid
registerWriteable
*/


- (int) getRegister:(UInt8)reg
{
    return [controller getSensorRegister:reg];
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val
{
    return [controller setSensorRegister:reg toValue:val];
}


- (int) setRegister:(UInt8)reg toValue:(UInt8)val withMask:(UInt8)mask
{
    int result = [self getRegister:reg];
    UInt8 actualVal = result;
    
    if (result < 0) 
        return result;
    
    actualVal &= ~mask;  // clear out bits
    val &= mask;         // only set bits allowed by mask
    actualVal |= val;    // combine them
    
    return [self setRegister:reg toValue:actualVal];
}


- (int) setRegisterArray:(struct register_array *) array
{
	while (array->bus != register_array::END_OF_ARRAY) 
    {
		if (array->bus == register_array::CONTROLLER_REGISTER) 
        {
			[controller setRegister:array->reg toValue:array->val];
		} 
        else if (array->bus == register_array::SENSOR_REGISTER) 
        {
			[self setRegister:array->reg toValue:array->val];
		} 
        else 
        {
			return -1;
		}
		array++;
	}
    
	return 0;
}


- (int) reset
{
    // Not implemented
    
    NSLog(@"Sensor:reset not implemented");
    
    return -1;
}


- (void) setResolution1:(CameraResolution)r fps:(short)fr
{
}


- (void) setResolution2:(CameraResolution)r fps:(short)fr
{
}


- (void) setResolution3:(CameraResolution)r fps:(short)fr
{
}


- (void) setResolution:(CameraResolution)r fps:(short)fr
{
}


- (BOOL) canSetBrightness
{
    return NO;
}


- (void) setBrightness:(float)v
{
}


- (BOOL) canSetSaturation
{
    return NO;
}


- (void) setSaturation:(float)v
{
}


- (BOOL) canSetGain
{
    return NO;
}


- (void) setGain:(float)v
{
}

@end
