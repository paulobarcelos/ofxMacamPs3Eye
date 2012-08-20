//
//  Controller.h
//  macam
//
//  Created by Harald  on 10/29/07.
//  Copyright 2007 hxr. All rights reserved.
//

#import "MyCameraDriver.h"

//
// We use a category to extend the MyCameraDriver class to respond to 
// basic messages to do with sensors. We could edit the MyCameraDriver 
// class directly, and maybe we'll put this in there eventually. 
// 
@interface MyCameraDriver (ControllerInterface)

- (id) getSensor;  // Is this necessary for the sensor itself? Probably not.

- (int) setupSensorCommunication:(Class)sensor;

- (int) getSensorRegister:(UInt16)reg;
- (int) setSensorRegister:(UInt16)reg toValue:(UInt16)val;
- (int) setSensorRegister:(UInt16)reg toValue:(UInt16)val withMask:(UInt16)mask;

@end
