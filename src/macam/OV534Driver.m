//
//  OV534Driver.m
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "OV534Driver.h"
#import "ControllerInterface.h"


//
// Many thanks to Jim Paris at PS2 developer forums
//

//+/* 
//+ * register offset 
//+ */ 
//+#define GAIN        0x00 /* AGC - Gain control gain setting */ 
//+#define BLUE        0x01 /* AWB - Blue channel gain setting */ 
//+#define RED         0x02 /* AWB - Red   channel gain setting */ 
//+#define GREEN       0x03 /* AWB - Green channel gain setting */ 
//+#define COM1        0x04 /* Common control 1 */ 
//+#define BAVG        0x05 /* U/B Average Level */ 
//+#define GAVG        0x06 /* Y/Gb Average Level */ 
//+#define RAVG        0x07 /* V/R Average Level */ 
//+#define AECH        0x08 /* Exposure Value - AEC MSBs */ 
//+#define COM2        0x09 /* Common control 2 */ 
//+#define PID         0x0A /* Product ID Number MSB */ 
//+#define VER         0x0B /* Product ID Number LSB */ 
//+#define COM3        0x0C /* Common control 3 */ 
//+#define COM4        0x0D /* Common control 4 */ 
//+#define COM5        0x0E /* Common control 5 */ 
//+#define COM6        0x0F /* Common control 6 */ 
//+#define AEC         0x10 /* Exposure Value */ 
//+#define CLKRC       0x11 /* Internal clock */ 
//+#define COM7        0x12 /* Common control 7 */ 
//+#define COM8        0x13 /* Common control 8 */ 
//+#define COM9        0x14 /* Common control 9 */ 
//+#define COM10       0x15 /* Common control 10 */ 
//+#define HSTART      0x17 /* Horizontal sensor size */ 
//+#define HSIZE       0x18 /* Horizontal frame (HREF column) end high 8-bit */ 
//+#define VSTART      0x19 /* Vertical frame (row) start high 8-bit */ 
//+#define VSIZE       0x1A /* Vertical sensor size */ 
//+#define PSHFT       0x1B /* Data format - pixel delay select */ 
//+#define MIDH        0x1C /* Manufacturer ID byte - high */ 
//+#define MIDL        0x1D /* Manufacturer ID byte - low  */ 
//+#define LAEC        0x1F /* Fine AEC value */ 
//+#define COM11       0x20 /* Common control 11 */ 
//+#define BDBASE      0x22 /* Banding filter Minimum AEC value */ 
//+#define DBSTEP      0x23 /* Banding filter Maximum Setp */ 
//+#define AEW         0x24 /* AGC/AEC - Stable operating region (upper limit) */ 
//+#define AEB         0x25 /* AGC/AEC - Stable operating region (lower limit) */ 
//+#define VPT         0x26 /* AGC/AEC Fast mode operating region */ 
//+#define HOUTSIZE    0x29 /* Horizontal data output size MSBs */ 
//+#define EXHCH       0x2A /* Dummy pixel insert MSB */ 
//+#define EXHCL       0x2B /* Dummy pixel insert LSB */ 
//+#define VOUTSIZE    0x2C /* Vertical data output size MSBs */ 
//+#define ADVFL       0x2D /* LSB of insert dummy lines in Vertical direction */ 
//+#define ADVFH       0x2E /* MSG of insert dummy lines in Vertical direction */ 
//+#define YAVE        0x2F /* Y/G Channel Average value */ 
//+#define LUMHTH      0x30 /* Histogram AEC/AGC Luminance high level threshold */ 
//+#define LUMLTH      0x31 /* Histogram AEC/AGC Luminance low  level threshold */ 
//+#define HREF        0x32 /* Image start and size control */ 
//+#define DM_LNL      0x33 /* Dummy line low  8 bits */ 
//+#define DM_LNH      0x34 /* Dummy line high 8 bits */ 
//+#define ADOFF_B     0x35 /* AD offset compensation value for B  channel */ 
//+#define ADOFF_R     0x36 /* AD offset compensation value for R  channel */ 
//+#define ADOFF_GB    0x37 /* AD offset compensation value for Gb channel */ 
//+#define ADOFF_GR    0x38 /* AD offset compensation value for Gr channel */ 
//+#define OFF_B       0x39 /* Analog process B  channel offset value */
//+#define OFF_R       0x3A /* Analog process R  channel offset value */
//+#define OFF_GB      0x3B /* Analog process Gb channel offset value */
//+#define OFF_GR      0x3C /* Analog process Gr channel offset value */
//+#define COM12       0x3D /* Common control 12 */ 
//+#define COM13       0x3E /* Common control 13 */ 
//+#define COM14       0x3F /* Common control 14 */ 
//+#define COM15       0x40 /* Common control 15*/ 
//+#define COM16       0x41 /* Common control 16 */ 
//+#define TGT_B       0x42 /* BLC blue channel target value */ 
//+#define TGT_R       0x43 /* BLC red  channel target value */ 
//+#define TGT_GB      0x44 /* BLC Gb   channel target value */ 
//+#define TGT_GR      0x45 /* BLC Gr   channel target value */ 
//+#define LCC0        0x46 /* Lens correction control 0 */ 
//+#define LCC1        0x47 /* Lens correction option 1 - X coordinate */ 
//+#define LCC2        0x48 /* Lens correction option 2 - Y coordinate */ 
//+#define LCC3        0x49 /* Lens correction option 3 */ 
//+#define LCC4        0x4A /* Lens correction option 4 - radius of the circular */ 
//+#define LCC5        0x4B /* Lens correction option 5 */ 
//+#define LCC6        0x4C /* Lens correction option 6 */ 
//+#define FIXGAIN     0x4D /* Analog fix gain amplifer */ 
//+#define AREF0       0x4E /* Sensor reference control */ 
//+#define AREF1       0x4F /* Sensor reference current control */ 
//+#define AREF2       0x50 /* Analog reference control */ 
//+#define AREF3       0x51 /* ADC    reference control */ 
//+#define AREF4       0x52 /* ADC    reference control */ 
//+#define AREF5       0x53 /* ADC    reference control */ 
//+#define AREF6       0x54 /* Analog reference control */ 
//+#define AREF7       0x55 /* Analog reference control */ 
//+#define UFIX        0x60 /* U channel fixed value output */ 
//+#define VFIX        0x61 /* V channel fixed value output */ 
//+#define AW_BB_BLK   0x62 /* AWB option for advanced AWB */ 
//+#define AW_B_CTRL0  0x63 /* AWB control byte 0 */ 
//+#define DSP_CTRL1   0x64 /* DSP control byte 1 */ 
//+#define DSP_CTRL2   0x65 /* DSP control byte 2 */ 
//+#define DSP_CTRL3   0x66 /* DSP control byte 3 */ 
//+#define DSP_CTRL4   0x67 /* DSP control byte 4 */ 
//+#define AW_B_BIAS   0x68 /* AWB BLC level clip */ 
//+#define AW_BCTRL1   0x69 /* AWB control  1 */ 
//+#define AW_BCTRL2   0x6A /* AWB control  2 */ 
//+#define AW_BCTRL3   0x6B /* AWB control  3 */ 
//+#define AW_BCTRL4   0x6C /* AWB control  4 */ 
//+#define AW_BCTRL5   0x6D /* AWB control  5 */ 
//+#define AW_BCTRL6   0x6E /* AWB control  6 */ 
//+#define AW_BCTRL7   0x6F /* AWB control  7 */ 
//+#define AW_BCTRL8   0x70 /* AWB control  8 */ 
//+#define AW_BCTRL9   0x71 /* AWB control  9 */ 
//+#define AW_BCTRL10  0x72 /* AWB control 10 */ 
//+#define AW_BCTRL11  0x73 /* AWB control 11 */ 
//+#define AW_BCTRL12  0x74 /* AWB control 12 */ 
//+#define AW_BCTRL13  0x75 /* AWB control 13 */ 
//+#define AW_BCTRL14  0x76 /* AWB control 14 */ 
//+#define AW_BCTRL15  0x77 /* AWB control 15 */ 
//+#define AW_BCTRL16  0x78 /* AWB control 16 */ 
//+#define AW_BCTRL17  0x79 /* AWB control 17 */ 
//+#define AW_BCTRL18  0x7A /* AWB control 18 */ 
//+#define AW_BCTRL19  0x7B /* AWB control 19 */ 
//+#define AW_BCTRL20  0x7C /* AWB control 20 */ 
//+#define AW_BCTRL21  0x7D /* AWB control 21 */ 
//+#define GAM1        0x7E /* Gamma Curve  1st segment input end point */ 
//+#define GAM2        0x7F /* Gamma Curve  2nd segment input end point */ 
//+#define GAM3        0x80 /* Gamma Curve  3rd segment input end point */ 
//+#define GAM4        0x81 /* Gamma Curve  4th segment input end point */ 
//+#define GAM5        0x82 /* Gamma Curve  5th segment input end point */ 
//+#define GAM6        0x83 /* Gamma Curve  6th segment input end point */ 
//+#define GAM7        0x84 /* Gamma Curve  7th segment input end point */ 
//+#define GAM8        0x85 /* Gamma Curve  8th segment input end point */ 
//+#define GAM9        0x86 /* Gamma Curve  9th segment input end point */ 
//+#define GAM10       0x87 /* Gamma Curve 10th segment input end point */ 
//+#define GAM11       0x88 /* Gamma Curve 11th segment input end point */ 
//+#define GAM12       0x89 /* Gamma Curve 12th segment input end point */ 
//+#define GAM13       0x8A /* Gamma Curve 13th segment input end point */ 
//+#define GAM14       0x8B /* Gamma Curve 14th segment input end point */ 
//+#define GAM15       0x8C /* Gamma Curve 15th segment input end point */ 
//+#define SLOP        0x8D /* Gamma curve highest segment slope */ 
//+#define DNSTH       0x8E /* De-noise threshold */ 
//+#define EDGE0       0x8F /* Edge enhancement control 0 */ 
//+#define EDGE1       0x90 /* Edge enhancement control 1 */ 
//+#define DNSOFF      0x91 /* Auto De-noise threshold control */ 
//+#define EDGE2       0x92 /* Edge enhancement strength low  point control */ 
//+#define EDGE3       0x93 /* Edge enhancement strength high point control */ 
//+#define MTX1        0x94 /* Matrix coefficient 1 */ 
//+#define MTX2        0x95 /* Matrix coefficient 2 */ 
//+#define MTX3        0x96 /* Matrix coefficient 3 */ 
//+#define MTX4        0x97 /* Matrix coefficient 4 */ 
//+#define MTX5        0x98 /* Matrix coefficient 5 */ 
//+#define MTX6        0x99 /* Matrix coefficient 6 */ 
//+#define MTX_CTRL    0x9A /* Matrix control */ 
//+#define BRIGHT      0x9B /* Brightness control */ 
//+#define CNTRST      0x9C /* Contrast contrast */ 
//+#define CNTRST_CTRL 0x9D /* Contrast contrast center */ 
//+#define UVAD_J0     0x9E /* Auto UV adjust contrast 0 */ 
//+#define UVAD_J1     0x9F /* Auto UV adjust contrast 1 */ 
//+#define SCAL0       0xA0 /* Scaling control 0 */ 
//+#define SCAL1       0xA1 /* Scaling control 1 */ 
//+#define SCAL2       0xA2 /* Scaling control 2 */ 
//+#define FIFODLYM    0xA3 /* FIFO manual mode delay control */ 
//+#define FIFODLYA    0xA4 /* FIFO auto   mode delay control */ 
//+#define SDE         0xA6 /* Special digital effect control */ 
//+#define USAT        0xA7 /* U component saturation control */ 
//+#define VSAT        0xA8 /* V component saturation control */ 
//+#define HUE0        0xA9 /* Hue control 0 */ 
//+#define HUE1        0xAA /* Hue control 1 */ 
//+#define SIGN        0xAB /* Sign bit for Hue and contrast */ 
//+#define DSPAUTO     0xAC /* DSP auto function ON/OFF control */ 
//


//  SCCB/sensorinterface

#define OV534_REG_SCCB_ADDRESS   0xf1   // Store the address of the sensor
#define OV534_REG_SCCB_SUBADDR   0xf2
#define OV534_REG_SCCB_WRITE     0xf3
#define OV534_REG_SCCB_READ      0xf4
#define OV534_REG_SCCB_OPERATION 0xf5
#define OV534_REG_SCCB_STATUS    0xf6

#define OV534_SCCB_OP_WRITE_3    0x37
#define OV534_SCCB_OP_WRITE_2    0x33
#define OV534_SCCB_OP_READ_2     0xf9


@interface OV534Driver (Private)

- (void) initCamera;

@end


@implementation OV534Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
			
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithUnsignedShort:0x3002], @"idProduct",
			 [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor",
			 @"Hercules Blog Webcam", @"name", NULL], 
			
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithUnsignedShort:0x3003], @"idProduct", 
			 [NSNumber numberWithUnsignedShort:0x06f8], @"idVendor", 
			 @"Hercules Dualpix HD Webcam", @"name", NULL],
			
			NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    [LUT setDefaultOrientation:NormalOrientation];
    
    driverType = isochronousDriver;
    
    decodingSkipBytes = 0;
    compressionType = proprietaryCompression;
    
	return self;
}


- (void) startupCamera
{
    [self initCamera];
    
    [super startupCamera];
    
	[self setGain:1.0];
	[self setShutter:1.0];
    
	[self setHue:0.65];
	//  [self setWhiteBalanceMode:WhiteBalanceAutomatic];  // has no effect
}


//------------ RESOLUTION AND FPS ---------------
//
// Set a resolution and frame rate. 
//
- (void) setResolution:(CameraResolution)r fps:(short)fr 
{
    if (![self supportsResolution:r fps:fr]) 
        return;
    
    [stateLock lock];
    
    if (!isGrabbing) 
    {
        fps = fr;
		resolution = r;
		
        //
        // sensor register 0x11 is the clock divider, 
        // the six low bits are used, you always add one, 
        // unbless it is zero, which is when you get crazy 
        //
        // when sensor register 0x0d is set to 0x41, the total is 60
        //                                  to 0xc1, the total is 120
        //                                  to 0x81, the total is 150 **
        //
        // simpe set the total and the divider to get a number
        //
        // usually controller register 0xe5 is set to 0x04
        // except when ** (0x0d is set to 0x81) when it is set to 0x02
        //
		
		if (resolution == ResolutionVGA) 
		{
			NSLog( @"OV534Driver:setResolution ResolutionVGA fps:%d", fps);
			if (fps == 5) 
            {
                // 5 = 60 / 12
				[self setSensorRegister:0x11 toValue:0x0b];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
			else if (fps == 10) 
            {
                // 10 = 60 / 6
				[self setSensorRegister:0x11 toValue:0x05];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
			else if (fps == 15) 
            {
                // 15 = 60 / 4
				[self setSensorRegister:0x11 toValue:0x03];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
				//				[self setSensorRegister:0x14 toValue:0x41]; // instead of setting e5 to 04 in Theo's driver
			}
			else if (fps == 20) 
            {
                // 20 = 60 / 3
				[self setSensorRegister:0x11 toValue:0x02];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 25) 
            {
                // cannot use 60, cannot use 120
                // 25 = 150 / 6
				[self setSensorRegister:0x11 toValue:0x05];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
            }
            else if (fps == 30) 
            {
                // so many choices
                // 30 = 60 / 2
                // 30 = 120 / 4
                // 30 = 150 / 5
				[self setSensorRegister:0x11 toValue:0x04];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
			}
            else if (fps == 40 || fps == 0) 
            {
                // 40 = 120 / 3
				[self setSensorRegister:0x11 toValue:0x02];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 50) // measures 100 but image not moving
            {
                // cannot get this to work!
                // 50 = 150 / 3
				[self setSensorRegister:0x11 toValue:0x02];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
			}
            else if (fps == 60) // measures 120 but image not moving
            {
                // cannot get this to work
                // 60 = 120 / 2
				[self setSensorRegister:0x11 toValue:0x01];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
		}
        else if (resolution == ResolutionSIF) 
        {
			
			NSLog( @"OV534Driver:setResolution ResolutionSIF fps:%d", fps);
			//these were found by sniffing the windows ps3 eye app
			//maccam reports the fps is either higher or lower than 
			//what we are asking for - 
			
			//one thing we are not able to do is send the messages back and forth
			//the sniffer reports that when the ps3eye sends a 0x04 the software should send 0x04 back
			//for 125fps the eye sends 0x02 and we should be sending 0x02 back
			
			//also I don't understand this 	[self setSensorRegister:0x14 toValue:0x41];		
			//the code from here http://forums.ps2dev.org/viewtopic.php?p=75367#75367 - reports 	[self setSensorRegister:0x14 toValue:0x41];		
			//but the bytes I sniffed with snoopy pro - show 0x09 and 0x00 
			//hmm might be needed for 320 by 240 and the other one for 640 480????
			
            //
            // sensor register 0x11 is the clock divider, 
            // the six low bits are used, you always add one, 
            // unbless it is zero, which is when you get crazy 
            //
            // the speeds are three times as fast for SIF!
            //
            // when sensor register 0x0d is set to 0x41, the total is 180
            //                                  to 0xc1, the total is 360
            //                                  to 0x81, the total is 450 **
            //
            // simpe set the total and the divider to get a number
            //
            // usually controller register 0xe5 is set to 0x04
            // except when ** (0x0d is set to 0x81) when it is set to 0x02
            //
            
            if (fps == 5) 
            {
                // 5 = 180 / 36
				[self setSensorRegister:0x11 toValue:0x23];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
            }
            else if (fps == 10) 
            {
                // 10 = 180 / 18
				[self setSensorRegister:0x11 toValue:0x11];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
            }
			else if (fps == 15) 
            {
                // 15 = 180 / 12
				[self setSensorRegister:0x11 toValue:0x0b];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 20) 
            {
                // 20 = 180 / 9
				[self setSensorRegister:0x11 toValue:0x08];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
            }
            else if (fps == 25) 
            {
                // 25 = 450 / 18
				[self setSensorRegister:0x11 toValue:0x11];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
            }
            else if (fps == 30) 
            {
                // 30 = 180 / 6
				[self setSensorRegister:0x11 toValue:0x05];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 40) 
            {
                // 40 = 360 / 9
				[self setSensorRegister:0x11 toValue:0x08];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 45) 
            {
                // 45 = 180 / 4
				[self setSensorRegister:0x11 toValue:0x03];
				[self setSensorRegister:0x0d toValue:0x41];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
            else if (fps == 50) 
            {
                // 50 = 450 / 9
				[self setSensorRegister:0x11 toValue:0x08];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
			}
            else if (fps == 60) 
            {
                // 60 = 180 / 3
                // 60 = 360 / 6
				[self setSensorRegister:0x11 toValue:0x05];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
			else if (fps == 75) 
            {
                // 75 = 450 / 6
				[self setSensorRegister:0x11 toValue:0x05];
				[self setSensorRegister:0x0d toValue:0x81];
				[self verifySetRegister:0xe5 toValue:0x02];
			}
			else if (fps == 90) 
            {
                // 90 = 180 / 2
                // 90 = 360 / 4
				[self setSensorRegister:0x11 toValue:0x03];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}		
			else if (fps == 120 || fps == 0) 
            {
                // 120 = 360 / 3
				[self setSensorRegister:0x11 toValue:0x02];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}		
			else if (fps == 180) 
            {
                // 180 = 360 / 2
				[self setSensorRegister:0x11 toValue:0x01];
				[self setSensorRegister:0x0d toValue:0xc1];
				[self verifySetRegister:0xe5 toValue:0x04];
			}
		}
    }
    
    [stateLock unlock];
}


- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            switch (rate) 
		{
			case 0:
			case 5:
			case 10:
			case 15:
			case 20:
			case 25:
			case 30:
			case 40:
			case 50:
			case 60:
				return YES;
			default:
				return NO;
		}
            break;
            
        case ResolutionSIF:
            switch (rate) 
		{
			case 0:
			case 5:
			case 10:
			case 15:
			case 20:
			case 25:
			case 30:
			case 40:
			case 45:
			case 50:
			case 60:
			case 75:
			case 90:
			case 120:
			case 180:
				return YES;
			default:
				return NO;
		}
            break;
            
        default: 
            return NO;
    }
}


- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 30;
    
	return ResolutionVGA;
}


//------------ LED ---------------
- (BOOL) canSetLed
{
    return YES;
}

- (void) setLed:(BOOL) v
{
    [self setRegister:0x21 toValue:0x80 withMask:0x80];
    [self setRegister:0x23 toValue:(v ? 0x80 : 0x00) withMask:0x80];
    
    if (!v)  
        [self setRegister:0x21 toValue:0x00 withMask:0x80];
    
    [super setLed:v];
}
//-------

//------------ UVC ---------------
- (BOOL) isUVC{
	return NO;  // HXR: This is not a UVC camera, any particular reason it was returning YES before?
}
//-------

//------------ FLICKER ---------------
- (BOOL) canSetFlicker{
	return YES;
}

- (void) setFlicker:(FlickerType)fType{
	if( fType == disableFlicker){
		[self setSensorRegister:0x2b toValue:0x00]; //flicker off???
	}else if ( fType == enableFlicker50Hz){
		[self setSensorRegister:0x2b toValue:0x9e]; //flicker 50hz - http://www.invisible.ca/~jmcneill/outgoing/7720Rev2.set
	}else if ( fType == enableFlicker60Hz){
		[self setSensorRegister:0x2b toValue:0x00]; //flicker 60hz - http://www.invisible.ca/~jmcneill/outgoing/7720Rev2.set
	}
	
    [super setFlicker:fType];
}
//-------


//------------ HUE ---------------
// NOTE this is fake hue - we are just changing the blue gain :)
- (BOOL) canSetHue 
{ 
    return [self whiteBalanceMode] != WhiteBalanceAutomatic;
}

- (void) setHue:(float)v {
	
	float val = v * 255.0;
	if( val > 255) val = 255;
	if(val < 0) val = 0;
	unsigned char uval = (int)val;
	
	[self setSensorRegister:0x01 toValue:uval]; //hue - I think - http://www.invisible.ca/~jmcneill/outgoing/7720Rev2.set
	
    [super setHue:v];
}

//------------ GAIN ---------------
- (BOOL) canSetGain { return YES; }

- (void) setGain:(float)v {
	
	//according to http://www.invisible.ca/~jmcneill/outgoing/7720Rev2.set		
	//seven steps for gain
	
	//	HKR,%7720ComboGain%\0000, CamRegisters,1,00,00,ff
	//	HKR,%7720ComboGain%\0001, CamRegisters,1,00,04,ff
	//	HKR,%7720ComboGain%\0002, CamRegisters,1,00,08,ff	  
	//	HKR,%7720ComboGain%\0003, CamRegisters,1,00,0a,ff	  
	//	HKR,%7720ComboGain%\0004, CamRegisters,1,00,0f,ff	  
	//	HKR,%7720ComboGain%\0005, CamRegisters,1,00,14,ff	  
	//	HKR,%7720ComboGain%\0006, CamRegisters,1,00,18,ff	  
	//	HKR,%7720ComboGain%\0007, CamRegisters,1,00,1f,ff	
	
	//	31
	//	24
	//	20
	//	15
	//	10
	//	8
	//	4
	//	0
	
	//unsigned char gainVal[8] = {0, 4, 8, 10, 15, 20, 24, 31};
	unsigned char gainVal[8] = {0, 4, 8, 10, 15, 20, 24, 31};
	
	float val = v * 7.99;
	if( val >= 8) val = 7;
	if(val < 0) val = 0;
	unsigned char uval = gainVal[ (int)val ];
	
	[self setSensorRegister:0x00 toValue:uval];
    [super setGain:v];
}
//----

//------------ SHUTTER ---------------
//not sure if this is really the shutter - or another type of gain (see the registers at the top of this doc)
- (BOOL) canSetShutter { return YES; }

- (void) setShutter:(float)v {
	
	float val = v * 255.0;
	if( val > 255) val = 255;
	if(val < 0) val = 0;
	unsigned char uval = (int)val;
	
	[self setSensorRegister:0x10 toValue:uval]; //shutter speed - http://www.invisible.ca/~jmcneill/outgoing/7720Rev2.set
    [super setShutter:v];
}

//------------ AUTO GAIN ---------------
// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return YES;
}

- (void) setAutoGain:(BOOL) v
{
	if (v)
    {
		[self setSensorRegister:0x13 toValue:0x07 withMask:0x07]; // from 0x05 enables it
        [self setSensorRegister:0x64 toValue:0x03 withMask:0x03];
	}
    else 
    {
		[self setSensorRegister:0x13 toValue:0x00 withMask:0x07]; //0x00 disables auto gain
        [self setSensorRegister:0x64 toValue:0x00 withMask:0x03];
	}
    
    [super setAutoGain:v];    
}
//---------------



//
// WhiteBalance
//
- (BOOL) canSetWhiteBalanceModeTo: (WhiteBalanceMode) newMode 
{
    if (newMode == WhiteBalanceAutomatic) 
        return YES;
    
    return [super canSetWhiteBalanceModeTo:newMode];
}

- (void) setWhiteBalanceMode: (WhiteBalanceMode) newMode 
{
    if (newMode == WhiteBalanceAutomatic) 
    {
        [self setSensorRegister:0x63 toValue:0xe0];
    }
    else 
    {
        [self setSensorRegister:0x63 toValue:0xAA];
    }
    
    [super setWhiteBalanceMode:newMode];
}


//
// Set up some unusual defaults
//
- (void) setIsocFrameFunctions
{
    grabContext.chunkBufferLength = 2 * [self width] * [self height];	
	if ([self width] == 320) // Actually grabs 640 pixels wide, right half is blank though
        grabContext.chunkBufferLength = 4 * [self width] * [self height];	// theo changed from  2 * [self width] * [self height];
	
    grabContext.numberOfChunkBuffers = 3;  // Must be at least 2; 3 is better at high frame-rates
    grabContext.numberOfTransfers = 4;  // Must be at least 3 for the PS3 Eye! 4 is better at high frame-rates
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    videoBulkReadsPending = 0;
    
	[self setLed:YES];		
    [self setRegister:0xe0 toValue:0x00];
    
	if ([self width] == 320) 
    {
		[self setSensorRegister:0x29 toValue:0x50]; //theo changed from 0xa0 to 0x50 - see http://forums.ps2dev.org/viewtopic.php?p=74541#74541
		[self setSensorRegister:0x2c toValue:0x78]; //theo changed from 0xf0 to 0x78
		[self setSensorRegister:0x65 toValue:0x2f]; //theo changed from 0x20 to 0x2f - see http://forums.ps2dev.org/viewtopic.php?p=74541#74541
	}
    else
    {
		[self setSensorRegister:0x29 toValue:0xa0]; 
		[self setSensorRegister:0x2c toValue:0xf0];
		[self setSensorRegister:0x65 toValue:0x20];
	}	
	
    return YES;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self setRegister:0xe0 toValue:0x09];
	[self setLed:NO];
}


int clip(int x)
{
	if (x < 0) x = 0;
	if (x > 255) x = 255;
	return x;
}


void yuv_to_rgb(UInt8 y, UInt8 u, UInt8 v, UInt8 * r, UInt8 * g, UInt8 * b)
{
	int c = y - 16;
	int d = u - 128;
	int e = v - 128;
    
	*r = clip((298 * c           + 409 * e + 128) >> 8);
	*g = clip((298 * c - 100 * d - 208 * e + 128) >> 8);
	*b = clip((298 * c + 516 * d           + 128) >> 8);
}

//
// Return YES if everything is OK
//
- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    UInt8 * ptr = buffer->buffer;
    
    int R = 0;
    int G = 1;
    int B = 2;
    
    int row, column;
    
    if (buffer->numBytes < (grabContext.chunkBufferLength - 4)) 
        return NO;  // Skip this chunk
    
    for (row = 0; row < rawHeight; row++) 
    {
		
        UInt8 * out = nextImageBuffer + row * nextImageBufferRowBytes;
        
        for (column = 0; column < rawWidth; column += 2) 
        {
            int y1 = *ptr++;
            int u  = *ptr++;
            int y2 = *ptr++;
            int v  = *ptr++;
            
            yuv_to_rgb(y1, u, v, out + R, out + G, out + B);
            out += nextImageBufferBPP;
            
            yuv_to_rgb(y2, u, v, out + R, out + G, out + B);
            out += nextImageBufferBPP;
        }
        
        if (rawWidth == 320) 
            ptr += rawWidth * 2;
    }	
    
    [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}


- (int) getRegister:(UInt16)reg
{
    UInt8 buffer[8];
    
    BOOL ok = [self usbReadCmdWithBRequest:0x01 wValue:0x0000 wIndex:reg buf:buffer len:1];
    
    return (ok) ? buffer[0] : -1;
}


- (int) setRegister:(UInt16)reg toValue:(UInt16)val
{
    UInt8 buffer[8];
    
    buffer[0] = val;
    
    BOOL ok = [self usbWriteCmdWithBRequest:0x01 wValue:0x0000 wIndex:reg buf:buffer len:1];
    
    return (ok) ? val : -1;
}


- (int) verifySetRegister:(UInt16)reg toValue:(UInt8)val
{
    int verify;
    
    if ([self setRegister:reg toValue:val] < 0) 
    {
        printf("OV534Driver:verifySetRegister:setRegister failed\n");
        return -1;
    }
    
    verify = [self getRegister:reg];
    
    if (val != verify) 
    {
        printf("OV534Driver:verifySetRegister:getRegister returns something unexpected! (0x%04x != 0x%04x)\n", val, verify);
    }
    
    return verify;
}


- (void) initSCCB
{
    [self verifySetRegister:0xe7 toValue:0x3a];
    
	//    [self setRegister:OV534_REG_SCCB_ADDRESS toValue:0x60];
	//    [self setRegister:OV534_REG_SCCB_ADDRESS toValue:0x60];
	//    [self setRegister:OV534_REG_SCCB_ADDRESS toValue:0x60];
    [self setRegister:OV534_REG_SCCB_ADDRESS toValue:0x42];
}

//
// Is SCCB OK? Return YES if OK
//
- (BOOL) sccbStatusOK
{
#define SCCB_RETRY 5
    
    int try_ = 0;
    UInt8 ret;
    
    for (try_ = 0; try_ < SCCB_RETRY; try_++) 
    {
        ret = [self getRegister:OV534_REG_SCCB_STATUS];
        
        if (ret == 0x00) 
            return YES;
        
        if (ret == 0x04) 
            return NO;
        
        if (ret != 0x03) 
            printf("OV534Driver:sccbStatus is 0x%02x, attempt %d (of %d)\n", ret, try_ + 1, SCCB_RETRY);
    }
    
    return NO;
}


- (int) getSensorRegister:(UInt8)reg
{
    if ([self setRegister:OV534_REG_SCCB_SUBADDR toValue:reg] < 0) 
        return -1;
    
    if ([self setRegister:OV534_REG_SCCB_OPERATION toValue:OV534_SCCB_OP_WRITE_2] < 0) 
        return -1;
    
    if (![self sccbStatusOK]) 
    {
        printf("OV534Driver:getSensorRegister:SCCB not OK (1)\n");
        return -1;
    }
    
    if ([self setRegister:OV534_REG_SCCB_OPERATION toValue:OV534_SCCB_OP_READ_2] < 0) 
        return -1;
    
    if (![self sccbStatusOK]) 
    {
        printf("OV534Driver:getSensorRegister:SCCB not OK (2)\n");
        return -1;
    }
    
    return [self getRegister:OV534_REG_SCCB_READ];
}


- (int) setSensorRegister:(UInt8)reg toValue:(UInt8)val
{
    if ([self setRegister:OV534_REG_SCCB_SUBADDR toValue:reg] < 0) 
        return -1;
    
    if ([self setRegister:OV534_REG_SCCB_WRITE toValue:val] < 0) 
        return -1;
    
    if ([self setRegister:OV534_REG_SCCB_OPERATION toValue:OV534_SCCB_OP_WRITE_3] < 0) 
        return -1;
    
    return ([self sccbStatusOK]) ? val : -1;
}


- (void) initCamera
{
    [self verifySetRegister:0xe7 toValue:0x3a];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x60];
    [self setRegister:0xf1 toValue:0x42];
    
    [self verifySetRegister:0xc2 toValue:0x0c];
    [self verifySetRegister:0x88 toValue:0xf8];
    [self verifySetRegister:0xc3 toValue:0x69];
    [self verifySetRegister:0x89 toValue:0xff];
    [self verifySetRegister:0x76 toValue:0x03];
    [self verifySetRegister:0x92 toValue:0x01];
    [self verifySetRegister:0x93 toValue:0x18];
    [self verifySetRegister:0x94 toValue:0x10];
    [self verifySetRegister:0x95 toValue:0x10];
    [self verifySetRegister:0xe2 toValue:0x00];
    [self verifySetRegister:0xe7 toValue:0x3e];
    
    [self setRegister:0x1c toValue:0x0a];
    [self setRegister:0x1d toValue:0x22];
    [self setRegister:0x1d toValue:0x06];
    [self verifySetRegister:0x96 toValue:0x00];
    
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x0a];
    [self setRegister:0x97 toValue:0x3f];
    [self setRegister:0x97 toValue:0x4a];
    [self setRegister:0x97 toValue:0x20];
    [self setRegister:0x97 toValue:0x15];
    [self setRegister:0x97 toValue:0x0b];
    
    [self verifySetRegister:0x8e toValue:0x40];
    [self verifySetRegister:0x1f toValue:0x81];
    [self verifySetRegister:0x34 toValue:0x05];
    [self verifySetRegister:0xe3 toValue:0x04];
    [self verifySetRegister:0x88 toValue:0x00];
    [self verifySetRegister:0x89 toValue:0x00];
    [self verifySetRegister:0x76 toValue:0x00];
    [self verifySetRegister:0xe7 toValue:0x2e];
    [self verifySetRegister:0x31 toValue:0xf9];
    [self verifySetRegister:0x25 toValue:0x42];
    [self verifySetRegister:0x21 toValue:0xf0];
    
    [self setRegister:0x1c toValue:0x00];
    [self setRegister:0x1d toValue:0x40];
    [self setRegister:0x1d toValue:0x02];
    [self setRegister:0x1d toValue:0x00];
    [self setRegister:0x1d toValue:0x02];
    [self setRegister:0x1d toValue:0x57];
    [self setRegister:0x1d toValue:0xff];
    
    [self verifySetRegister:0x8d toValue:0x1c];
    [self verifySetRegister:0x8e toValue:0x80];
    [self verifySetRegister:0xe5 toValue:0x04];
    
    [self setSensorRegister:0x12 toValue:0x80];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x11 toValue:0x01];
    
    [self setSensorRegister:0x3d toValue:0x03];
    [self setSensorRegister:0x17 toValue:0x26];
    [self setSensorRegister:0x18 toValue:0xa0];
    [self setSensorRegister:0x19 toValue:0x07];
    [self setSensorRegister:0x1a toValue:0xf0];
    [self setSensorRegister:0x32 toValue:0x00];
    [self setSensorRegister:0x29 toValue:0xa0];
    [self setSensorRegister:0x2c toValue:0xf0];
    [self setSensorRegister:0x65 toValue:0x20];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x42 toValue:0x7f];
    [self setSensorRegister:0x63 toValue:0xAA]; //THIS DISABLES AUTO WHITE BALANCE
    [self setSensorRegister:0x64 toValue:0xff];
    [self setSensorRegister:0x66 toValue:0x00];
    [self setSensorRegister:0x13 toValue:0xf0];
    [self setSensorRegister:0x0d toValue:0x41];
    [self setSensorRegister:0x0f toValue:0xc5];
    [self setSensorRegister:0x14 toValue:0x11];
    
    [self setSensorRegister:0x22 toValue:0x7f];
    [self setSensorRegister:0x23 toValue:0x03];
    [self setSensorRegister:0x24 toValue:0x40];
    [self setSensorRegister:0x25 toValue:0x30];
    [self setSensorRegister:0x26 toValue:0xa1];
    [self setSensorRegister:0x2a toValue:0x00];
    [self setSensorRegister:0x2b toValue:0x00];
    [self setSensorRegister:0x6b toValue:0xaa];
    [self setSensorRegister:0x13 toValue:0xff];
    
    [self setSensorRegister:0x90 toValue:0x05];
    [self setSensorRegister:0x91 toValue:0x01];
    [self setSensorRegister:0x92 toValue:0x03];
    [self setSensorRegister:0x93 toValue:0x00];
    [self setSensorRegister:0x94 toValue:0x60];
    [self setSensorRegister:0x95 toValue:0x3c];
    [self setSensorRegister:0x96 toValue:0x24];
    [self setSensorRegister:0x97 toValue:0x1e];
    [self setSensorRegister:0x98 toValue:0x62];
    [self setSensorRegister:0x99 toValue:0x80];
    [self setSensorRegister:0x9a toValue:0x1e];
    [self setSensorRegister:0x9b toValue:0x08];
    [self setSensorRegister:0x9c toValue:0x20];
    [self setSensorRegister:0x9e toValue:0x81];
    
    [self setSensorRegister:0xa6 toValue:0x04];
    [self setSensorRegister:0x7e toValue:0x0c];
    [self setSensorRegister:0x7f toValue:0x16];
    
    [self setSensorRegister:0x80 toValue:0x2a];
    [self setSensorRegister:0x81 toValue:0x4e];
    [self setSensorRegister:0x82 toValue:0x61];
    [self setSensorRegister:0x83 toValue:0x6f];
    [self setSensorRegister:0x84 toValue:0x7b];
    [self setSensorRegister:0x85 toValue:0x86];
    [self setSensorRegister:0x86 toValue:0x8e];
    [self setSensorRegister:0x87 toValue:0x97];
    [self setSensorRegister:0x88 toValue:0xa4];
    [self setSensorRegister:0x89 toValue:0xaf];
    [self setSensorRegister:0x8a toValue:0xc5];
    [self setSensorRegister:0x8b toValue:0xd7];
    [self setSensorRegister:0x8c toValue:0xe8];
    [self setSensorRegister:0x8d toValue:0x20];
    
    [self setSensorRegister:0x0c toValue:0x90];
    
    [self verifySetRegister:0xc0 toValue:0x50];
    [self verifySetRegister:0xc1 toValue:0x3c];
    [self verifySetRegister:0xc2 toValue:0x0c];
    
    [self setSensorRegister:0x2b toValue:0x00];
    [self setSensorRegister:0x22 toValue:0x7f];
    [self setSensorRegister:0x23 toValue:0x03];
    [self setSensorRegister:0x11 toValue:0x01];
    [self setSensorRegister:0x0c toValue:0xd0];
    [self setSensorRegister:0x64 toValue:0xff];
    [self setSensorRegister:0x0d toValue:0x41];
    
    [self setSensorRegister:0x14 toValue:0x41];
    [self setSensorRegister:0x0e toValue:0xcd];
    [self setSensorRegister:0xac toValue:0xbf];
    [self setSensorRegister:0x8e toValue:0x00];
    [self setSensorRegister:0x0c toValue:0xd0];
    
    [self setRegister:0xe0 toValue:0x09];
	//  [self setRegister:0xe0 toValue:0x00];
}

@end


@implementation OV538Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
			
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithUnsignedShort:0x2000], @"idProduct", 
			 [NSNumber numberWithUnsignedShort:0x1415], @"idVendor", 
			 @"Sony HD Eye for PS3 (SLEH 00201)", @"name", NULL],
			
			NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    driverType = bulkDriver;
    
	return self;
}

@end
