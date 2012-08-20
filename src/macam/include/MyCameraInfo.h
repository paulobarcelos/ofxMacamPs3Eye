/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id: MyCameraInfo.h,v 1.3 2007/11/14 21:45:54 hxr Exp $
 */

/*
This is a container class. It serves multiple organizing purposes:

MyCameraCentral keeps an object for each available driver.
MyCameraCentral uses these objects as refCon for the attach/detach-callbacks (to have the kind of camera handy)
MyCameraCentral keeps an object for each connected camera and sets the driver object to remember if the camera is actually used
*/

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "GlobalDefs.h"
#import <Cocoa/Cocoa.h>

@interface MyCameraInfo : NSObject {
    io_object_t		notification;	//A reference to our notification we want when we are unplugged
    Class		driverClass;	//The driver class if we want a driver
    id			driver;		//A driver - if we have one
    unsigned long 	cid;		//Our runtime unique id - generated on init
    id			central;	//for the callbacks to find the camera central 
    NSString*		name;		//the name of the camera type (e.g. "Philips ToUCam Pro")
    long 		pid;		//the usb product id
    long 		vid;		//the usb vendor id
    UInt32		lid;		//The usb location id (only for connected cameras)
    UInt16      version;    // bcdDevice, the evice version number (only for connected cameras)
}

- (id) init;
- (void) dealloc;
- (id) copy;

- (io_object_t) notification;
- (void) setNotification:(io_object_t)n;

- (Class) driverClass;
- (void) setDriverClass:(Class)c;

- (id) driver;
- (void) setDriver:(id)d;

- (id) central;
- (void) setCentral:(id)c;

- (unsigned long) cid;

- (NSString*) cameraName;
- (void) setCameraName:(NSString*)camName;

- (long) productID;
- (void) setProductID:(long)prodID;

- (long) vendorID;
- (void) setVendorID:(long)vendID;

- (UInt32) locationID;
- (void) setLocationID:(UInt32)locID;

- (UInt16) versionNumber;
- (void) setVersionNumber:(UInt16)vNum;

@end
