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
 $Id: MiscTools.c,v 1.6 2009/05/01 20:28:22 hxr Exp $
 */

#include "MiscTools.h"
#include "pthread.h"
#include "sched.h"
#include "Resolvers.h"

void CStr2PStr(const char* cstr, unsigned char* pstr) {
    short i=0;
    for (i=0;cstr[i]!=0;i++)  pstr[i+1]=cstr[i];
    pstr[0]=i;
}

void PStr2CStr(const unsigned char* pstr, char* cstr) {
    short i=0;
    for (i=0;i<pstr[0];i++)  cstr[i]=pstr[i+1];
    cstr[i]=0;
}

void PStr2PStr(const unsigned char* src, unsigned char* dst) {
    short i;
    for (i=0;i<=src[0];i++) dst[i]=src[i];
}

void CStr2CStr(const char* src,char* dst) {
    while (*src) *(dst++)=*(src++);
    *dst=0;
}

void DumpMem(unsigned char* buf, long len) {
    long i;
    for (i=0;i<len;i++) {
        printf("%02x ",buf[i]);
        if (((i%16)==15)||(i==len-1)) printf("\n");
    }
}

/*I have no idea about pthread scheduling and priorities, but this seems to work and seemed to be the most logical to me when I looked at the headers. Anyone with expertise? */

void ChangeMyThreadPriority(int delta) {
    pthread_t thread=pthread_self();
    struct sched_param param;
    int policy;
    if (pthread_getschedparam(thread,&policy,&param)==0) {
        param.sched_priority+=delta;
        pthread_setschedparam(thread,policy,&param);
    }	
}

int GetMyThreadPriority(void) {
    pthread_t thread=pthread_self();
    struct sched_param param;
    int policy;
    if (pthread_getschedparam(thread,&policy,&param)==0) return param.sched_priority;
    else return 0;
}

void OSXYieldToAnyThread(void) {
    sched_yield();
}

short CountPipes(IOUSBInterfaceInterface **intf) {
    UInt8 count;
    IOReturn err;
    if (!intf) return 0;
    err=(*intf)->GetNumEndpoints(intf,&count);
    if (err) printf("CountPipes: Error %d\n",err);
    return count;
}

void ShowPipeInfo(IOUSBInterfaceInterface **intf, short idx) {
    IOReturn				err;
    UInt8				direction;
    UInt8				number;
    UInt8				transferType;
    UInt16				maxPacketSize;
    UInt8				interval;

    err= (*intf)->GetPipeProperties(intf,idx,&direction,&number, &transferType,&maxPacketSize,&interval);
    CheckError(err,"GetPipeProperties");
    printf("Pipe %d: dir:",idx);
    switch (direction) {
        case kUSBOut: printf("out"); break;
        case kUSBIn: printf("in"); break;
        case kUSBAnyDirn: printf("bidirectional"); break;
        default: printf("invalid"); break;
    }
    printf (" number:%d type:",number);
    switch (transferType) {
        case kUSBControl: printf("control"); break;
        case kUSBIsoc: printf("isochronous"); break;
        case kUSBBulk: printf("bulk"); break;
        case kUSBInterrupt: printf("interrupt"); break;
        case kUSBAnyType: printf("any type"); break;
        default: printf("invalid"); break;
    }
    printf(" maxPacketSize:%d pollInterval:%d ",maxPacketSize,interval);
    err=(*intf)->GetPipeStatus(intf,idx);
    ShowError(err,"Status");
}

void ShowPipesInfo(IOUSBInterfaceInterface **intf) {
    short num=CountPipes(intf);
    short i;
    printf("Number Of Pipes: %d (+ default control pipe 0)\n",num);
    for (i=0;i<=num;i++) ShowPipeInfo(intf,i);
}

short WidthOfResolution(CameraResolution r) {
    short ret;
    switch (r) {
        case ResolutionSQSIF: ret = 128; break;
        case ResolutionQSIF:  ret = 160; break;
        case ResolutionQCIF:  ret = 176; break;
        case ResolutionSIF:   ret = 320; break;
        case ResolutionCIF:   ret = 352; break;
        case ResolutionVGA:   ret = 640; break;
        case ResolutionSVGA:  ret = 800; break;
        case ResolutionXGA:   ret = 1024; break;
        case ResolutionUXGA:  ret = 1600; break;
        default:              ret =  -1; break;
    }
    return ret;
}

short HeightOfResolution(CameraResolution r) {
    short ret;
    switch (r) {
        case ResolutionSQSIF: ret =  96; break;
        case ResolutionQSIF:  ret = 120; break;
        case ResolutionQCIF:  ret = 144; break;
        case ResolutionSIF:   ret = 240; break;
        case ResolutionCIF:   ret = 288; break;
        case ResolutionVGA:   ret = 480; break;
        case ResolutionSVGA:  ret = 600; break;
        case ResolutionXGA:   ret = 768; break;
        case ResolutionUXGA:  ret = 1200; break;
        default:              ret =  -1; break;
    }
    return ret;
}

// FPS item menu lookups

short MenuItem2FPS(int item)
{
    switch (item) 
    {
        case -1: return -1; // Looking up a non-item, return -1
            
        case 0: return 0;  // fastest
        case 1: return 5;
        case 2: return 10;
        case 3: return 15;
        case 4: return 20;
        case 5: return 25;
        case 6: return 30;
        case 7: return 40;
        case 8: return 45;
        case 9: return 50;
        case 10: return 60;
        case 11: return 75;
        case 12: return 90;
        case 13: return 100;
        case 14: return 120;
        case 15: return 180;
    }
    
    return -1; // error
}

int FPS2MenuItem(short fps)
{
    switch (fps) 
    {
        case 0: return 0;
        case 5: return 1;
        case 10: return 2;
        case 15: return 3;
        case 20: return 4;
        case 25: return 5;
        case 30: return 6;
        case 40: return 7;
        case 45: return 8;
        case 50: return 9;
        case 60: return 10;
        case 75: return 11;
        case 90: return 12;
        case 100: return 13;
        case 120: return 14;
        case 180: return 15;
    }
    
    return 0; // fastest
}


void SetQDRect(Rect  * rect, short left, short top, short right, short bottom)
{
    rect->left = left;
    rect->top = top;
    rect->right = right;
    rect->bottom = bottom;
}


