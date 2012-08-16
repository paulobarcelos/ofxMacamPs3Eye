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
 $Id: Resolvers.c,v 1.3 2006/10/12 14:15:39 hxr Exp $
*/

#include "Resolvers.h"
#include <QuickTime/QuickTime.h>


bool ErrorName (IOReturn err, char* out_buf) {
    bool ok=true;
    switch (err) {
        case 0: sprintf(out_buf,"ok"); break; 	
        case kIOReturnError: sprintf(out_buf,"kIOReturnError - general error"); break; 	
        case kIOReturnNoMemory: sprintf(out_buf,"kIOReturnNoMemory - can't allocate memory");  break;
        case kIOReturnNoResources: sprintf(out_buf,"kIOReturnNoResources - resource shortage"); break;
        case kIOReturnIPCError: sprintf(out_buf,"kIOReturnIPCError - error during IPC"); break;
        case kIOReturnNoDevice: sprintf(out_buf,"kIOReturnNoDevice - no such device"); break;
        case kIOReturnNotPrivileged: sprintf(out_buf,"kIOReturnNotPrivileged - privilege violation"); break;
        case kIOReturnBadArgument: sprintf(out_buf,"kIOReturnBadArgument - invalid argument"); break;
        case kIOReturnLockedRead: sprintf(out_buf,"kIOReturnLockedRead - device read locked"); break;
        case kIOReturnLockedWrite: sprintf(out_buf,"kIOReturnLockedWrite - device write locked"); break;
        case kIOReturnExclusiveAccess: sprintf(out_buf,"kIOReturnExclusiveAccess - exclusive access and device already open"); break;
        case kIOReturnBadMessageID: sprintf(out_buf,"kIOReturnBadMessageID - sent/received messages had different msg_id"); break;
        case kIOReturnUnsupported: sprintf(out_buf,"kIOReturnUnsupported - unsupported function"); break;
        case kIOReturnVMError: sprintf(out_buf,"kIOReturnVMError - misc. VM failure"); break;
        case kIOReturnInternalError: sprintf(out_buf,"kIOReturnInternalError - internal error"); break;
        case kIOReturnIOError: sprintf(out_buf,"kIOReturnIOError - General I/O error"); break;
        case kIOReturnCannotLock: sprintf(out_buf,"kIOReturnCannotLock - can't acquire lock"); break;
        case kIOReturnNotOpen: sprintf(out_buf,"kIOReturnNotOpen - device not open"); break;
        case kIOReturnNotReadable: sprintf(out_buf,"kIOReturnNotReadable - read not supported"); break;
        case kIOReturnNotWritable: sprintf(out_buf,"kIOReturnNotWritable - write not supported"); break;
        case kIOReturnNotAligned: sprintf(out_buf,"kIOReturnNotAligned - alignment error"); break;
        case kIOReturnBadMedia: sprintf(out_buf,"kIOReturnBadMedia - Media Error"); break;
        case kIOReturnStillOpen: sprintf(out_buf,"kIOReturnStillOpen - device(s) still open"); break;
        case kIOReturnRLDError: sprintf(out_buf,"kIOReturnRLDError - rld failure"); break;
        case kIOReturnDMAError: sprintf(out_buf,"kIOReturnDMAError - DMA failure"); break;
        case kIOReturnBusy: sprintf(out_buf,"kIOReturnBusy - Device Busy"); break;
        case kIOReturnTimeout: sprintf(out_buf,"kIOReturnTimeout - I/O Timeout"); break;
        case kIOReturnOffline: sprintf(out_buf,"kIOReturnOffline - device offline"); break;
        case kIOReturnNotReady: sprintf(out_buf,"kIOReturnNotReady - not ready"); break;
        case kIOReturnNotAttached: sprintf(out_buf,"kIOReturnNotAttached - device not attached"); break;
        case kIOReturnNoChannels: sprintf(out_buf,"kIOReturnNoChannels - no DMA channels left"); break;
        case kIOReturnNoSpace: sprintf(out_buf,"kIOReturnNoSpace - no space for data"); break;
        case kIOReturnPortExists: sprintf(out_buf,"kIOReturnPortExists - port already exists"); break;
        case kIOReturnCannotWire: sprintf(out_buf,"kIOReturnCannotWire - can't wire down physical memory"); break;
        case kIOReturnNoInterrupt: sprintf(out_buf,"kIOReturnNoInterrupt - no interrupt attached"); break;
        case kIOReturnNoFrames: sprintf(out_buf,"kIOReturnNoFrames - no DMA frames enqueued"); break;
        case kIOReturnMessageTooLarge: sprintf(out_buf,"kIOReturnMessageTooLarge - oversized msg received on interrupt port"); break;
        case kIOReturnNotPermitted: sprintf(out_buf,"kIOReturnNotPermitted - not permitted"); break;
        case kIOReturnNoPower: sprintf(out_buf,"kIOReturnNoPower - no power to device"); break;
        case kIOReturnNoMedia: sprintf(out_buf,"kIOReturnNoMedia - media not present"); break;
        case kIOReturnUnformattedMedia: sprintf(out_buf,"kIOReturnUnformattedMedia - media not formatted"); break;
        case kIOReturnUnsupportedMode: sprintf(out_buf,"kIOReturnUnsupportedMode - no such mode"); break;
        case kIOReturnUnderrun: sprintf(out_buf,"kIOReturnUnderrun - data underrun"); break;
        case kIOReturnOverrun: sprintf(out_buf,"kIOReturnOverrun - data overrun"); break;
        case kIOReturnDeviceError: sprintf(out_buf,"kIOReturnDeviceError - the device is not working properly!"); break;
        case kIOReturnNoCompletion: sprintf(out_buf,"kIOReturnNoCompletion - a completion routine is required"); break;
        case kIOReturnAborted: sprintf(out_buf,"kIOReturnAborted - operation aborted"); break;
        case kIOReturnNoBandwidth: sprintf(out_buf,"kIOReturnNoBandwidth - bus bandwidth would be exceeded"); break;
        case kIOReturnNotResponding: sprintf(out_buf,"kIOReturnNotResponding - device not responding"); break;
        case kIOReturnIsoTooOld: sprintf(out_buf,"kIOReturnIsoTooOld - isochronous I/O request for distant past!"); break;
        case kIOReturnIsoTooNew: sprintf(out_buf,"kIOReturnIsoTooNew - isochronous I/O request for distant future"); break;
        case kIOReturnNotFound: sprintf(out_buf,"kIOReturnNotFound - data was not found"); break;
        case kIOReturnInvalid: sprintf(out_buf,"kIOReturnInvalid - should never be seen"); break;
        case kIOUSBUnknownPipeErr:sprintf(out_buf,"kIOUSBUnknownPipeErr - Pipe ref not recognised"); break;
        case kIOUSBTooManyPipesErr:sprintf(out_buf,"kIOUSBTooManyPipesErr - Too many pipes"); break;
        case kIOUSBNoAsyncPortErr:sprintf(out_buf,"kIOUSBNoAsyncPortErr - no async port"); break;
        case kIOUSBNotEnoughPipesErr:sprintf(out_buf,"kIOUSBNotEnoughPipesErr - not enough pipes in interface"); break;
        case kIOUSBNotEnoughPowerErr:sprintf(out_buf,"kIOUSBNotEnoughPowerErr - not enough power for selected configuration"); break;
        case kIOUSBEndpointNotFound:sprintf(out_buf,"kIOUSBEndpointNotFound - Not found"); break;
        case kIOUSBConfigNotFound:sprintf(out_buf,"kIOUSBConfigNotFound - Not found"); break;
        case kIOUSBTransactionTimeout:sprintf(out_buf,"kIOUSBTransactionTimeout - time out"); break;
        case kIOUSBTransactionReturned:sprintf(out_buf,"kIOUSBTransactionReturned - The transaction has been returned to the caller"); break;
        case kIOUSBPipeStalled:sprintf(out_buf,"kIOUSBPipeStalled - Pipe has stalled, error needs to be cleared"); break;
        case kIOUSBInterfaceNotFound:sprintf(out_buf,"kIOUSBInterfaceNotFound - Interface ref not recognised"); break;
        case kIOUSBLinkErr:sprintf(out_buf,"kIOUSBLinkErr - <no error description available>"); break;
        case kIOUSBNotSent2Err:sprintf(out_buf,"kIOUSBNotSent2Err - Transaction not sent"); break;
        case kIOUSBNotSent1Err:sprintf(out_buf,"kIOUSBNotSent1Err - Transaction not sent"); break;
        case kIOUSBBufferUnderrunErr:sprintf(out_buf,"kIOUSBBufferUnderrunErr - Buffer Underrun (Host hardware failure on data out, PCI busy?)"); break;
        case kIOUSBBufferOverrunErr:sprintf(out_buf,"kIOUSBBufferOverrunErr - Buffer Overrun (Host hardware failure on data out, PCI busy?)"); break;
        case kIOUSBReserved2Err:sprintf(out_buf,"kIOUSBReserved2Err - Reserved"); break;
        case kIOUSBReserved1Err:sprintf(out_buf,"kIOUSBReserved1Err - Reserved"); break;
        case kIOUSBWrongPIDErr:sprintf(out_buf,"kIOUSBWrongPIDErr - Pipe stall, Bad or wrong PID"); break;
        case kIOUSBPIDCheckErr:sprintf(out_buf,"kIOUSBPIDCheckErr - Pipe stall, PID CRC Err:or"); break;
        case kIOUSBDataToggleErr:sprintf(out_buf,"kIOUSBDataToggleErr - Pipe stall, Bad data toggle"); break;
        case kIOUSBBitstufErr:sprintf(out_buf,"kIOUSBBitstufErr - Pipe stall, bitstuffing"); break;
        case kIOUSBCRCErr:sprintf(out_buf,"kIOUSBCRCErr - Pipe stall, bad CRC"); break;
        
        default: sprintf(out_buf,"Unknown Error:%d Sub:%d System:%d",err_get_code(err),
                err_get_sub(err),err_get_system(err)); ok=false; break;
    }
    return ok;
}

void ShowError(IOReturn err, char* where) {
    char buf[256];
    if (where) {
        printf(where);
        printf(": ");
    }
    if (err==0) {
        printf("ok");
    } else {
        printf("Error: ");
        ErrorName(err,buf);
        printf(buf);
    }
    printf("\n");
}

void CheckError(IOReturn err, char* where) {
    if (err) {
        ShowError(err,where);
    }
}

bool ResolveVDSelector(short sel, char* str) {
    switch (sel) {
        case kComponentRegisterSelect:sprintf(str,"kComponentRegisterSelect"); break;
        case kComponentOpenSelect:sprintf(str,"kComponentOpenSelect"); break;
        case kComponentCloseSelect:sprintf(str,"kComponentCloseSelect"); break;
        case kComponentCanDoSelect:sprintf(str,"kComponentCanDoSelect"); break;
        case kComponentVersionSelect:sprintf(str,"kComponentVersionSelect"); break;
        case kVDGetMaxSrcRectSelect: sprintf(str,"kVDGetMaxSrcRectSelect"); break; //                     = 0x0001,
        case kVDGetActiveSrcRectSelect: sprintf(str,"kVDGetActiveSrcRectSelect"); break; //                  = 0x0002,
        case kVDSetDigitizerRectSelect: sprintf(str,"kVDSetDigitizerRectSelect"); break; //                  = 0x0003,
        case kVDGetDigitizerRectSelect: sprintf(str,"kVDGetDigitizerRectSelect"); break; //                  = 0x0004,
        case kVDGetVBlankRectSelect: sprintf(str,"kVDGetVBlankRectSelect"); break; //                     = 0x0005,
        case kVDGetMaskPixMapSelect: sprintf(str,"kVDGetMaskPixMapSelect"); break; //                     = 0x0006,
        case kVDGetPlayThruDestinationSelect: sprintf(str,"kVDGetPlayThruDestinationSelect"); break; //            = 0x0008,
        case kVDUseThisCLUTSelect: sprintf(str,"kVDUseThisCLUTSelect"); break; //                       = 0x0009,
        case kVDSetInputGammaValueSelect: sprintf(str,"kVDSetInputGammaValueSelect"); break; //                = 0x000A,
        case kVDGetInputGammaValueSelect: sprintf(str,"kVDGetInputGammaValueSelect"); break; //                = 0x000B,
        case kVDSetBrightnessSelect: sprintf(str,"kVDSetBrightnessSelect"); break; //                     = 0x000C,
        case kVDGetBrightnessSelect: sprintf(str,"kVDGetBrightnessSelect"); break; //                     = 0x000D,
        case kVDSetContrastSelect: sprintf(str,"kVDSetContrastSelect"); break; //                       = 0x000E,
        case kVDSetHueSelect: sprintf(str,"kVDSetHueSelect"); break; //                            = 0x000F,
        case kVDSetSharpnessSelect: sprintf(str,"kVDSetSharpnessSelect"); break; //                      = 0x0010,
        case kVDSetSaturationSelect: sprintf(str,"kVDSetSaturationSelect"); break; //                     = 0x0011,
        case kVDGetContrastSelect: sprintf(str,"kVDGetContrastSelect"); break; //                       = 0x0012,
        case kVDGetHueSelect: sprintf(str,"kVDGetHueSelect"); break; //                            = 0x0013,
        case kVDGetSharpnessSelect: sprintf(str,"kVDGetSharpnessSelect"); break; //                      = 0x0014,
        case kVDGetSaturationSelect: sprintf(str,"kVDGetSaturationSelect"); break; //                     = 0x0015,
        case kVDGrabOneFrameSelect: sprintf(str,"kVDGrabOneFrameSelect"); break; //                      = 0x0016,
        case kVDGetMaxAuxBufferSelect: sprintf(str,"kVDGetMaxAuxBufferSelect"); break; //                   = 0x0017,
        case kVDGetDigitizerInfoSelect: sprintf(str,"kVDGetDigitizerInfoSelect"); break; //                  = 0x0019,
        case kVDGetCurrentFlagsSelect: sprintf(str,"kVDGetCurrentFlagsSelect"); break; //                   = 0x001A,
        case kVDSetKeyColorSelect: sprintf(str,"kVDSetKeyColorSelect"); break; //                       = 0x001B,
        case kVDGetKeyColorSelect: sprintf(str,"kVDGetKeyColorSelect"); break; //                       = 0x001C,
        case kVDAddKeyColorSelect: sprintf(str,"kVDAddKeyColorSelect"); break; //                       = 0x001D,
        case kVDGetNextKeyColorSelect: sprintf(str,"kVDGetNextKeyColorSelect"); break; //                   = 0x001E,
        case kVDSetKeyColorRangeSelect: sprintf(str,"kVDSetKeyColorRangeSelect"); break; //                  = 0x001F,
        case kVDGetKeyColorRangeSelect: sprintf(str,"kVDGetKeyColorRangeSelect"); break; //                  = 0x0020,
        case kVDSetDigitizerUserInterruptSelect: sprintf(str,"kVDSetDigitizerUserInterruptSelect"); break; //         = 0x0021,
        case kVDSetInputColorSpaceModeSelect: sprintf(str,"kVDSetInputColorSpaceModeSelect"); break; //            = 0x0022,
        case kVDGetInputColorSpaceModeSelect: sprintf(str,"kVDGetInputColorSpaceModeSelect"); break; //            = 0x0023,
        case kVDSetClipStateSelect: sprintf(str,"kVDSetClipStateSelect"); break; //                      = 0x0024,
        case kVDGetClipStateSelect: sprintf(str,"kVDGetClipStateSelect"); break; //                      = 0x0025,
        case kVDSetClipRgnSelect: sprintf(str,"kVDSetClipRgnSelect"); break; //                        = 0x0026,
        case kVDClearClipRgnSelect: sprintf(str,"kVDClearClipRgnSelect"); break; //                      = 0x0027,
        case kVDGetCLUTInUseSelect: sprintf(str,"kVDGetCLUTInUseSelect"); break; //                      = 0x0028,
        case kVDSetPLLFilterTypeSelect: sprintf(str,"kVDSetPLLFilterTypeSelect"); break; //                  = 0x0029,
        case kVDGetPLLFilterTypeSelect: sprintf(str,"kVDGetPLLFilterTypeSelect"); break; //                  = 0x002A,
        case kVDGetMaskandValueSelect: sprintf(str,"kVDGetMaskandValueSelect"); break; //                   = 0x002B,
        case kVDSetMasterBlendLevelSelect: sprintf(str,"kVDSetMasterBlendLevelSelect"); break; //               = 0x002C,
        case kVDSetPlayThruDestinationSelect: sprintf(str,"kVDSetPlayThruDestinationSelect"); break; //            = 0x002D,
        case kVDSetPlayThruOnOffSelect: sprintf(str,"kVDSetPlayThruOnOffSelect"); break; //                  = 0x002E,
        case kVDSetFieldPreferenceSelect: sprintf(str,"kVDSetFieldPreferenceSelect"); break; //                = 0x002F,
        case kVDGetFieldPreferenceSelect: sprintf(str,"kVDGetFieldPreferenceSelect"); break; //                = 0x0030,
        case kVDPreflightDestinationSelect: sprintf(str,"kVDPreflightDestinationSelect"); break; //              = 0x0032,
        case kVDPreflightGlobalRectSelect: sprintf(str,"kVDPreflightGlobalRectSelect"); break; //               = 0x0033,
        case kVDSetPlayThruGlobalRectSelect: sprintf(str,"kVDPreflightGlobalRectSelect"); break; //             = 0x0034,
        case kVDSetInputGammaRecordSelect: sprintf(str,"kVDSetInputGammaRecordSelect"); break; //               = 0x0035,
        case kVDGetInputGammaRecordSelect: sprintf(str,"kVDGetInputGammaRecordSelect"); break; //               = 0x0036,
        case kVDSetBlackLevelValueSelect: sprintf(str,"kVDSetBlackLevelValueSelect"); break; //                = 0x0037,
        case kVDGetBlackLevelValueSelect: sprintf(str,"kVDGetBlackLevelValueSelect"); break; //                = 0x0038,
        case kVDSetWhiteLevelValueSelect: sprintf(str,"kVDSetWhiteLevelValueSelect"); break; //                = 0x0039,
        case kVDGetWhiteLevelValueSelect: sprintf(str,"kVDGetWhiteLevelValueSelect"); break; //                = 0x003A,
        case kVDGetVideoDefaultsSelect: sprintf(str,"kVDGetVideoDefaultsSelect"); break; //                  = 0x003B,
        case kVDGetNumberOfInputsSelect: sprintf(str,"kVDGetNumberOfInputsSelect"); break; //                 = 0x003C,
        case kVDGetInputFormatSelect: sprintf(str,"kVDGetInputFormatSelect"); break; //                    = 0x003D,
        case kVDSetInputSelect: sprintf(str,"kVDSetInputSelect"); break; //                          = 0x003E,
        case kVDGetInputSelect: sprintf(str,"kVDGetInputSelect"); break; //                          = 0x003F,
        case kVDSetInputStandardSelect: sprintf(str,"kVDSetInputStandardSelect"); break; //                  = 0x0040,
        case kVDSetupBuffersSelect: sprintf(str,"kVDSetupBuffersSelect"); break; //                      = 0x0041,
        case kVDGrabOneFrameAsyncSelect: sprintf(str,"kVDGrabOneFrameAsyncSelect"); break; //                 = 0x0042,
        case kVDDoneSelect: sprintf(str,"kVDDoneSelect"); break; //                              = 0x0043,
        case kVDSetCompressionSelect: sprintf(str,"kVDSetCompressionSelect"); break; //                    = 0x0044,
        case kVDCompressOneFrameAsyncSelect: sprintf(str,"kVDCompressOneFrameAsyncSelect"); break; //             = 0x0045,
        case kVDCompressDoneSelect: sprintf(str,"kVDCompressDoneSelect"); break; //                      = 0x0046,
        case kVDReleaseCompressBufferSelect: sprintf(str,"kVDReleaseCompressBufferSelect"); break; //             = 0x0047,
        case kVDGetImageDescriptionSelect: sprintf(str,"kVDGetImageDescriptionSelect"); break; //               = 0x0048,
        case kVDResetCompressSequenceSelect: sprintf(str,"kVDResetCompressSequenceSelect"); break; //             = 0x0049,
        case kVDSetCompressionOnOffSelect: sprintf(str,"kVDSetCompressionOnOffSelect"); break; //               = 0x004A,
        case kVDGetCompressionTypesSelect: sprintf(str,"kVDGetCompressionTypesSelect"); break; //               = 0x004B,
        case kVDSetTimeBaseSelect: sprintf(str,"kVDSetTimeBaseSelect"); break; //                       = 0x004C,
        case kVDSetFrameRateSelect: sprintf(str,"kVDSetFrameRateSelect"); break; //                      = 0x004D,
        case kVDGetDataRateSelect: sprintf(str,"kVDGetDataRateSelect"); break; //                       = 0x004E,
        case kVDGetSoundInputDriverSelect: sprintf(str,"kVDGetSoundInputDriverSelect"); break; //               = 0x004F,
        case kVDGetDMADepthsSelect: sprintf(str,"kVDGetDMADepthsSelect"); break; //                      = 0x0050,
        case kVDGetPreferredTimeScaleSelect: sprintf(str,"kVDGetPreferredTimeScaleSelect"); break; //             = 0x0051,
        case kVDReleaseAsyncBuffersSelect: sprintf(str,"kVDReleaseAsyncBuffersSelect"); break; //               = 0x0052,
        case kVDSetDataRateSelect: sprintf(str,"kVDSetDataRateSelect"); break; //                       = 0x0054,
        case kVDGetTimeCodeSelect: sprintf(str,"kVDGetTimeCodeSelect"); break; //                       = 0x0055,
        case kVDUseSafeBuffersSelect: sprintf(str,"kVDUseSafeBuffersSelect"); break; //                    = 0x0056,
        case kVDGetSoundInputSourceSelect: sprintf(str,"kVDGetSoundInputSourceSelect"); break; //               = 0x0057,
        case kVDGetCompressionTimeSelect: sprintf(str,"kVDGetCompressionTimeSelect"); break; //                = 0x0058,
        case kVDSetPreferredPacketSizeSelect: sprintf(str,"kVDSetPreferredPacketSizeSelect"); break; //            = 0x0059,
        case kVDSetPreferredImageDimensionsSelect: sprintf(str,"kVDSetPreferredImageDimensionsSelect"); break; //       = 0x005A,
        case kVDGetPreferredImageDimensionsSelect: sprintf(str,"kVDGetPreferredImageDimensionsSelect"); break; //       = 0x005B,
        case kVDGetInputNameSelect: sprintf(str,"kVDGetInputNameSelect"); break; //                      = 0x005C,
        case kVDSetDestinationPortSelect: sprintf(str,"kVDSetDestinationPortSelect"); break; //                = 0x005D,

#if 1
        case kVDGetDeviceNameAndFlagsSelect: sprintf(str,"kVDGetDeviceNameAndFlagsSelect"); break;             // = 0x005E,
        case kVDCaptureStateChangingSelect: sprintf(str,"kVDCaptureStateChangingSelect"); break;               // = 0x005F,
        case kVDGetUniqueIDsSelect: sprintf(str,"kVDGetUniqueIDsSelect"); break;                               // = 0x0060,
        case kVDSelectUniqueIDsSelect: sprintf(str,"kVDSelectUniqueIDsSelect"); break;                         // = 0x0061,
        case kVDCopyPreferredAudioDeviceSelect: sprintf(str,"kVDCopyPreferredAudioDeviceSelect"); break;       // = 0x0063,
#endif
        
        case kSGPanelGetDitlSelect: sprintf(str,"kSGPanelGetDitlSelect"); break; //                      = 0x0200,
        case kSGPanelGetTitleSelect: sprintf(str,"kSGPanelGetTitleSelect"); break; //                     = 0x0201,
        case kSGPanelCanRunSelect: sprintf(str,"kSGPanelCanRunSelect"); break; //                       = 0x0202,
        case kSGPanelInstallSelect: sprintf(str,"kSGPanelInstallSelect"); break; //                      = 0x0203,
        case kSGPanelEventSelect: sprintf(str,"kSGPanelEventSelect"); break; //                        = 0x0204,
        case kSGPanelItemSelect: sprintf(str,"kSGPanelItemSelect"); break; //                         = 0x0205,
        case kSGPanelRemoveSelect: sprintf(str,"kSGPanelRemoveSelect"); break; //                       = 0x0206,
        case kSGPanelSetGrabberSelect: sprintf(str,"kSGPanelSetGrabberSelect"); break; //                   = 0x0207,
        case kSGPanelSetResFileSelect: sprintf(str,"kSGPanelSetResFileSelect"); break; //                   = 0x0208,
        case kSGPanelGetSettingsSelect: sprintf(str,"kSGPanelGetSettingsSelect"); break; //                  = 0x0209,
        case kSGPanelSetSettingsSelect: sprintf(str,"kSGPanelSetSettingsSelect"); break; //                  = 0x020A,
        case kSGPanelValidateInputSelect: sprintf(str,"kSGPanelValidateInputSelect"); break; //                = 0x020B,
        case kSGPanelSetEventFilterSelect: sprintf(str,"kSGPanelSetEventFilterSelect"); break; //               = 0x020C,
            
        default: sprintf(str,"unknown component function selector: %d",sel); return false; break;
    }
    return true;
}

void PrintVDSelector(short sel) {
    char name[300];
    ResolveVDSelector(sel,name);
    printf("%s\n",name);
}

