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
 $Id: MyCameraInfo.m,v 1.5 2007/11/14 21:45:54 hxr Exp $
 */

#import "MyCameraInfo.h"

static unsigned long cidCount=1;

@implementation MyCameraInfo

- (id) init {
    self=[super init];
    if (self==NULL) return NULL;
    notification=IO_OBJECT_NULL;
    driver=NULL;
    driverClass=NULL;
    cid=cidCount++;
    central=NULL;
    name=NULL;
    pid=0;
    vid=0;
    lid=0;
    version = 0;
    return self;
}

- (id) copy {
    MyCameraInfo* c=[[MyCameraInfo alloc] init];
    if (c==NULL) return NULL;
    [c setNotification:[self notification]];
    [c setDriver:[self driver]];
    [c setDriverClass:[self driverClass]];
    [c setCentral:[self central]];
    [c setCameraName:[self cameraName]];
    [c setProductID:[self productID]];
    [c setVendorID:[self vendorID]];
    [c setLocationID:[self locationID]];
    [c setVersionNumber:[self versionNumber]];
    return c;
}

- (void) dealloc 
{
    if (name) 
        [name release];
    name = NULL;
    
    [super dealloc];
}

- (io_object_t) notification {
    return notification;
}

- (void) setNotification:(io_object_t)n {
    notification=n;
}

- (Class) driverClass {
    return driverClass;
}

- (void) setDriverClass:(Class)c {
    driverClass=c;
}

- (id) driver {
    return driver;
}

- (void) setDriver:(id)d {
    driver=d;
}
- (id) central {
    return central;
}

- (void) setCentral:(id)c {
    central=c;
}

- (unsigned long) cid {
    return cid;
}


- (NSString*) cameraName {
    return name;
}

- (void) setCameraName:(NSString*)camName {
    if (name) [name release]; name=NULL;
    if (camName!=NULL) name=[camName copy];
}

- (long) productID {
    return pid;
}

- (void) setProductID:(long)prodID {
    pid=prodID;
}

- (long) vendorID {
    return vid;
}

- (void) setVendorID:(long)vendID {
    vid=vendID;
}

- (UInt32) locationID {
    return lid;
}

- (void) setLocationID:(UInt32)locID {
    lid=locID;
}

- (UInt16) versionNumber
{
    return version;
}

- (void) setVersionNumber:(UInt16)vNum
{
    version = vNum;
}

@end
