//
//  OV534Driver.h
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "GenericDriver.h"


@interface OV534Driver : GenericDriver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral:(id)c;

- (void) startupCamera;
- (void) setResolution:(CameraResolution)r fps:(short)fr;

- (void) setGain:(float)v;
- (BOOL) canSetGain;

- (void) setShutter:(float)v;
- (BOOL) canSetShutter;

- (void) setHue:(float)v;
- (BOOL) canSetHue;

- (BOOL) canSetFlicker;
- (void) setFlicker:(FlickerType)fType;

// Gain and shutter combined
- (BOOL) canSetAutoGain;
- (void) setAutoGain:(BOOL) v;
- (BOOL) isUVC;

- (int) getRegister:(UInt16)reg;
- (int) setRegister:(UInt16)reg toValue:(UInt16)val;
- (int) verifySetRegister:(UInt16)reg toValue:(UInt8)val;

- (void) initSCCB;
- (BOOL) sccbStatusOK;

- (int) getSensorRegister:(UInt8)reg;
- (int) setSensorRegister:(UInt8)reg toValue:(UInt8)val;

@end


@interface OV538Driver : OV534Driver 

+ (NSArray *) cameraUsbDescriptions;

@end
