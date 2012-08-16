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
 $Id: MiscTools.h,v 1.3 2009/05/01 02:55:41 hxr Exp $
 */

#ifndef _MISC_TOOLS_
#define _MISC_TOOLS_

#include <Carbon/Carbon.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "GlobalDefs.h"

//String copy and conversion functions
void CStr2PStr(const char* cstr, unsigned char* pstr);
void PStr2CStr(const unsigned char* pstr, char* cstr);
void PStr2PStr(const unsigned char* src, unsigned char* dst);
void CStr2CStr(const char* src,char* dst);

//Memory dump - for debugging
void DumpMem(unsigned char* buf, long len);

//Wrappers for thread stuff
void ChangeMyThreadPriority(int delta);
int GetMyThreadPriority(void);
void OSXYieldToAnyThread(void);

//Pipes info
short CountPipes(IOUSBInterfaceInterface **intf);
void ShowPipeInfo(IOUSBInterfaceInterface **intf, short idx);
void ShowPipesInfo(IOUSBInterfaceInterface **intf);

//Resoultion lookup
short WidthOfResolution(CameraResolution r);
short HeightOfResolution(CameraResolution r);

// FPS item menu lookup
short MenuItem2FPS(int item);
int FPS2MenuItem(short fps);

// Replace deprecated calls
void SetQDRect(Rect  * rect, short left, short top, short right, short bottom);

#endif