//
//  Sensor.h
//  macam
//
//  Created by Harald  on 10/29/07.
//  Copyright 2007 hxr. All rights reserved.
//

#import "MyCameraDriver.h"
#import "ControllerInterface.h"


typedef struct register_array 
{
	enum 
    {
        END_OF_ARRAY = 0,
        CONTROLLER_REGISTER = 1,
        SENSOR_REGISTER = 2,
        
		OV511_DONE_BUS = 0,
		OV511_REG_BUS = 1,
		OV511_I2C_BUS = 2,
	} bus;
	unsigned char reg;
	unsigned char val;
} register_array;


//
// This is the interface for all sensors
// 
// This is also be a default implementation
// so "Sensor" is not an abstract class, although 
// it is pretty useless as most methods just 
// complain that there is no implementation!
//
// Each sensor knows best what kinds of settings it 
// has and how they should be modified. However, the 
// controller knows how to "talk" to the sensor. 
// Therefore we need to add some methods to the 
// basic driver as well as som default implementations. 
//
@interface Sensor : NSObject 
{
    MyCameraDriver * controller;
}

+ (id) findSensor:(MyCameraDriver*)driver;

+ (UInt8) i2cReadAddress;
+ (UInt8) i2cWriteAddress;

- (id) init;
- (int) configure;

- (int) getRegister:(UInt8)reg;
- (int) setRegister:(UInt8)reg toValue:(UInt8)val;
- (int) setRegister:(UInt8)reg toValue:(UInt8)val withMask:(UInt8)mask;
- (int) setRegisterArray:(struct register_array *) array;

- (int) reset;

/*
reset
initialize

numRegisters
- (BOOL) validRegister

setGain
- (void) setFormat
setBrightness
setContrast
setHue
setFramerate
*/

- (void) setResolution1:(CameraResolution)r fps:(short)fr;
- (void) setResolution2:(CameraResolution)r fps:(short)fr;
- (void) setResolution3:(CameraResolution)r fps:(short)fr;
- (void) setResolution:(CameraResolution)r fps:(short)fr;

- (BOOL) canSetBrightness;
- (void) setBrightness:(float)v;

- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;

- (BOOL) canSetGain;
- (void) setGain:(float)v;



@end


// Sensor -> OmniVison -> OV76xx -> OV7648 -> OV7660 -> OV7670