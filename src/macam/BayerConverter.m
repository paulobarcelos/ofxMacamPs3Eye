/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of>
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id: BayerConverter.m,v 1.16 2008/01/16 19:49:37 hxr Exp $
 */
#import "BayerConverter.h"


@interface BayerConverter (Private)
- (void) demosaicFrom:(unsigned char*)src type:(short)type srcRowBytes:(long)srcRowBytes;
               //Type: 1=STV680-style, 2=STV600-style
- (void) postprocessGRBGTo:(unsigned char*)dst dstRowBytes:(long)dstRowBytes dstBPP:(short)dstBPP flip:(BOOL)flip;
- (void) calcColorStatistics;
- (void) updateGainsToColorStats;
- (void) recalcTransferLookup;
- (void) rotateImage180;

@end

@implementation BayerConverter

- (id) init {
    self=[super init];
    brightness=0.0f;
    contrast=1.0f;
    gamma=1.0f;
    saturation=65536;
    sharpness=0.0f;
    rgbBuffer=NULL;
    sourceWidth=0;
    sourceHeight=0;
    destinationWidth=0;
    destinationHeight=0;
    sourceFormat=1;
    updateGains=NO;
    produceColorStats=NO;
    redGain=1.0f;
    greenGain=1.0f;
    blueGain=1.0f;
    [self recalcTransferLookup];
    return self;
}

- (void) dealloc {
    if (rgbBuffer) FREE(rgbBuffer,"BayerConverter dealloc rgbBuffer"); rgbBuffer=NULL;
    [super dealloc];
}

- (unsigned long) sourceWidth { return sourceWidth; }

- (unsigned long) sourceHeight { return sourceHeight; }

- (void) setSourceWidth:(long)width height:(long)height {
    BOOL sizeChanged=((sourceWidth*sourceHeight)!=(width*height));
    if ((sizeChanged)&&(rgbBuffer)) {
        FREE (rgbBuffer,"BayerDecoder setSourceWidth:height: rgbBuffer");
        rgbBuffer=NULL;
    }
    if (!rgbBuffer) {
        MALLOC(rgbBuffer,unsigned char*,width*height*3,"BayerDecoder setSourceWidth:height: rgbBuffer");
    }
    sourceWidth=width;
    sourceHeight=height;
}

- (short) sourceFormat {
    return sourceFormat;
}

- (void) setSourceFormat:(short)fmt {
    if ((fmt<1)||(fmt>MAX_BAYER_TYPE)) return;
    sourceFormat=fmt;
}

- (unsigned long) destinationWidth { return destinationWidth; }

- (unsigned long) destinationHeight { return destinationHeight; }

- (void) setDestinationWidth:(long)width height:(long)height {
    destinationWidth=width;
    destinationHeight=height;
}

- (float) brightness { return brightness; }

- (void) setBrightness:(float)newBrightness {
    brightness=CLAMP(newBrightness,-1.0f,1.0f);
    [self recalcTransferLookup];
}

- (float) contrast { return contrast; }

- (void) setContrast:(float)newContrast {
    contrast=CLAMP(newContrast,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) gamma { return gamma; }
- (void) setGamma:(float)newGamma {
    gamma=CLAMP(newGamma,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) saturation { return ((float)saturation)/65536.0f; }
- (void) setSaturation:(float)newSaturation {
    saturation=65536.0f*CLAMP(newSaturation,0.0f,2.0f);
}

- (float) sharpness { return sharpness; }

- (void) setSharpness:(float)newSharpness {
    sharpness=CLAMP(newSharpness,0.0f,1.0f);
}

- (void) setGainsDynamic:(BOOL)dynamic {
    updateGains=dynamic;
    averageSumsValid=NO;
}

- (void) setGainsRed:(float)r green:(float)g blue:(float)b {
    redGain=r;
    greenGain=g;
    blueGain=b;
    [self recalcTransferLookup];
}

- (void) setMakeImageStats:(BOOL)on {
    //lastMeanStats should return a negative value to indicate an invalid average
    if ((!produceColorStats)||(!on)) {
        meanRed=meanGreen=meanBlue=-1.0f;
    }
    produceColorStats=on;

}

- (float) lastMeanBrightness {
    return ((float)(meanRed+meanGreen+meanBlue))/768.0f;
}

- (BOOL) copyFromSrc:(unsigned char*)src toDest:(unsigned char*)dst srcRowBytes:(long)srcRB dstRowBytes:(long)dstRB dstBPP:(short)dstBPP {
    int width =MIN(sourceWidth ,destinationWidth );
    int height=MIN(sourceHeight,destinationHeight);
    int srcRowSkip=sourceWidth-width;
    int dstRowSkip=dstRB-width*dstBPP;
    int x,y;
    for (y=0;y<height;y++) {
        for (x=0;x<height;x++) {
            if (dstBPP==4) *(dst++)=255;
            *(dst++)=*src;
            *(dst++)=*src;
            *(dst++)=*(src++);
        }
        src+=srcRowSkip;
        dst+=dstRowSkip;
    }
    return YES;
}



//Do the whole decoding
- (BOOL) convertFromSrc:(unsigned char*)src toDest:(unsigned char*)dst
            srcRowBytes:(long)srcRB dstRowBytes:(long)dstRB dstBPP:(short)dstBPP flip:(BOOL)flip rotate180:(BOOL)rotate180 {
    if (!rgbBuffer) return NO;
    [self demosaicFrom:src type:sourceFormat srcRowBytes:srcRB];
	if (rotate180) [self rotateImage180];
    if (updateGains||produceColorStats) [self calcColorStatistics];
    if (updateGains) [self updateGainsToColorStats];
    [self postprocessGRBGTo:dst dstRowBytes:dstRB dstBPP:dstBPP flip:flip];
    return YES;
}

//Internals
- (void) demosaicFrom:(unsigned char*)src type:(short)type srcRowBytes:(long)srcRowBytes {
    /* We expect the Bayer matrix to be in the following format:

    G1 R1 G2 R2
    B1 G3 B2 G4
    G5 R3 G6 R4
    B3 G7 B4 G8

    -> A GRBG-type Bayer Matrix
	
	and the BGGR type matrix is as follows
	
	B1 G1 B2 G2
	G3 R1 G4 R2
	B3 G5 B4 G6
	G7 R3 G8 R4

    RGGB is just rotated...
    
    
    Format 7 - RAW data?
    - each RGB = pixel, thus Grayscale...
    */
    short g1,g2,g3,g4,g5,g6,g7,g8;
    short r1,r2,r3,r4;
    short b1,b2,b3,b4;
	
    unsigned char *green1Run,*green2Run,*green3Run,*green4Run;
    unsigned char *red1Run,*red2Run,*blue1Run,*blue2Run;
    unsigned char *dst1Run,*dst2Run;
    long x,y;
    long dstSkip=sourceWidth*3;
	BOOL GRBGtype = YES;  //  As opposed to BGGR
	
    //source type specific variables 
    long componentStep,srcSkip;
    
    if (type == 7) 
    {
        dst1Run=rgbBuffer;
        
        for (x = 0; x < sourceWidth; x++) 
            for (y = 0; y < sourceHeight; y++) 
            {
                int val = *src / 2;
                
                *(dst1Run++) = val;
                *(dst1Run++) = val;
                *(dst1Run++) = val;
                
                src++;
            }
        
        return;
    }
    
    switch (type) {
        case 1:	//Components planar in half row, order swapped (STV680-style)
            componentStep=1;
            green1Run =src+sourceWidth/2;
            red1Run   =src;
            blue1Run  =src+srcRowBytes+sourceWidth/2;
            green2Run =src+srcRowBytes;
            break;
        case 2:	//Interleaved data (STV600-style) // GRBG
        case 6: // works like 2 then switch R and B at the end // GBRG
            componentStep=2;
            green1Run =src;
            red1Run   =src+1;
            blue1Run  =src+srcRowBytes;
            green2Run =src+srcRowBytes+1;
            break;
        case 3:	//Row 1: xGxG, Row 2: RBRB (QuickCam Pro subsampled-style)
            componentStep=2;
            red1Run   =src+srcRowBytes+1;
            green1Run =src+1;
            green2Run =src+1;
            blue1Run  =src+srcRowBytes;
            break;
        case 4:	// OV7630 style // BGGR
        case 5: // works like 4 then switch R and B at the end // RGGB
			GRBGtype = NO;
            componentStep=2;
            blue1Run  =src;
            green1Run =src+1;
            green2Run =src+srcRowBytes;
            red1Run   =src+srcRowBytes+1;
            break;
        default: //Assume type 2
#ifdef VERBOSE
            NSLog(@"BayerConverter: Unknown bayer data type: %i",type);
#endif VERBOSE
            componentStep=2;
            green1Run =src;
            red1Run   =src+1;
            blue1Run  =src+srcRowBytes;
            green2Run =src+srcRowBytes+1;
            break;
    }
	
    //init data run pointers
    srcSkip =2*srcRowBytes-(((sourceWidth-2)/2)*componentStep);
	// componentStep is added here to compensate for the initial subtraction in the big loop below
	// the loop over the non-border rows starts with the runs pointing to the left half
	// one could probably eliminate both adding it here and subtracting it later
    green3Run =green1Run+2*srcRowBytes+componentStep;
    red2Run   =red1Run+2*srcRowBytes+componentStep;
    blue2Run  =blue1Run+2*srcRowBytes+componentStep;
    green4Run =green2Run+2*srcRowBytes+componentStep;
    dst1Run=rgbBuffer;
    dst2Run=rgbBuffer+2*dstSkip;
	
	//First row, first column
    *(dst1Run++)=*red1Run;
	*(dst1Run++)=(GRBGtype)?*green1Run:(*green1Run+*green2Run)/2;
    *(dst1Run++)=*blue1Run;
	//First row, non-border columns
    for (x=(sourceWidth-2)/2;x>0;x--) {
        *(dst1Run++)=*red1Run;
        *(dst1Run++)=(GRBGtype)?(*green1Run+*(green1Run+componentStep)+*green2Run)/3:*green1Run;
        *(dst1Run++)=(*blue1Run+*(blue1Run+componentStep))/2;
        if (GRBGtype) green1Run+=componentStep;
        green2Run+=componentStep;
        blue1Run+=componentStep;
        *(dst1Run++)=(*red1Run+*(red1Run+componentStep))/2;
        *(dst1Run++)=(GRBGtype)?*green1Run:(*green1Run+*(green1Run+componentStep)+*green2Run)/3;
        *(dst1Run++)=*blue1Run;
        red1Run+=componentStep;
        if (!GRBGtype) green1Run+=componentStep;
    }
	//First row, last column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run)/2:*green1Run;
    *(dst1Run++)=*blue1Run;
	//Reset the src data run pointers we changed in the first row - dst1RUn is ok now
    green1Run =green3Run-2*srcRowBytes;
    red1Run   =red2Run-2*srcRowBytes;
    blue1Run  =blue2Run-2*srcRowBytes;
    green2Run =green4Run-2*srcRowBytes;
    
    
	//All non-border rows
    for (y=(sourceHeight-2)/2;y>0;y--) {
		//init right half of colors to left values - will be shifted inside the loop
        r2=*(red1Run-componentStep);	
        r4=*(red2Run-componentStep);
        g2=*(green1Run-componentStep);
        g4=*(green2Run-componentStep);
        g6=*(green3Run-componentStep);
        g8=*(green4Run-componentStep);
        b2=*(blue1Run-componentStep);
        b4=*(blue2Run-componentStep);
		
		//First pixel column in row
        *(dst1Run++)=(GRBGtype)?(r2+r4)/2:r2;
        *(dst1Run++)=(GRBGtype)?(g2+g4+g6)/3:g2;
        *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
        *(dst2Run++)=(GRBGtype)?r4:(r2+r4)/2;
        *(dst2Run++)=(GRBGtype)?g6:(g4+g6+g8)/3;
        *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
		
		//All non-border columns in row
        for (x=(sourceWidth-2)/2;x>0;x--) {
            //shift right half of colors to left half
            r1=r2;
            r3=r4;
            g1=g2;
            g3=g4;
            g5=g6;
            g7=g8;
            b1=b2;
            b3=b4;
            //read new ones
            r2=*red1Run; red1Run+=componentStep;
            g2=*green1Run; green1Run+=componentStep;
            g4=*green2Run; green2Run+=componentStep;
            b2=*blue1Run; blue1Run+=componentStep;
            r4=*red2Run; red2Run+=componentStep;
            g6=*green3Run; green3Run+=componentStep;
            g8=*green4Run; green4Run+=componentStep;
            b4=*blue2Run; blue2Run+=componentStep;
			
            //Interpolate Pixel (2,2): location of g3 (r1).
            *(dst1Run++)=(GRBGtype)?(r1+r3)/2:r1;
            *(dst1Run++)=(GRBGtype)?g3:(g1+g3+g4+g5)/4;
            *(dst1Run++)=(GRBGtype)?(b1+b2)/2:(b1+b2+b3+b4)/4;
            //Interpolate Pixel (3,2): location of b2 (g4).
            *(dst1Run++)=(GRBGtype)?(r1+r2+r3+r4)/4:(r1+r2)/2;
            *(dst1Run++)=(GRBGtype)?(g2+g3+g4+g6)/4:g4;
            *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
            //Interpolate Pixel (2,3): location of r3 (g5).
            *(dst2Run++)=(GRBGtype)?r3:(r1+r3)/2;
            *(dst2Run++)=(GRBGtype)?(g3+g5+g6+g7)/4:g5;
            *(dst2Run++)=(GRBGtype)?(b1+b2+b3+b4)/4:(b3+b4)/2;
            //Interpolate Pixel (3,3): location of g6 (b4).
            *(dst2Run++)=(GRBGtype)?(r3+r4)/2:(r1+r2+r3+r4)/4;
            *(dst2Run++)=(GRBGtype)?g6:(g4+g5+g6+g8)/4;
            *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
        }
		
		//last pixel column in row
        *(dst1Run++)=(GRBGtype)?(r2+r4)/2:r2;
        *(dst1Run++)=(GRBGtype)?g4:(g2+g4+g6)/3;
        *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
        *(dst2Run++)=(GRBGtype)?r4:(r2+r4)/2;
        *(dst2Run++)=(GRBGtype)?(g4+g6+g8)/3:g6;
        *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
		
		//go to start of next two lines
        dst1Run+=dstSkip;
        dst2Run+=dstSkip;
        red1Run+=srcSkip;
        red2Run+=srcSkip;
        green1Run+=srcSkip;
        green2Run+=srcSkip;
        green3Run+=srcSkip;
        green4Run+=srcSkip;
        blue1Run+=srcSkip;
        blue2Run+=srcSkip;
    }
    // corrections
    red1Run   += srcRowBytes - srcSkip;
    red2Run   += srcRowBytes - srcSkip;
    green1Run += srcRowBytes - srcSkip;
    green2Run += srcRowBytes - srcSkip;
    green3Run += srcRowBytes - srcSkip;
    green4Run += srcRowBytes - srcSkip;
    blue1Run  += srcRowBytes - srcSkip;
    blue2Run  += srcRowBytes - srcSkip;
	//Last row, first column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run)/2:*green1Run;
    *(dst1Run++)=*blue1Run;
	//Last row, non-border columns
    for (x=(sourceWidth-2)/2;x>0;x--) {
        *(dst1Run++)=*red1Run;
        *(dst1Run++)=(GRBGtype)?*green2Run:(*green1Run+*green2Run+*(green2Run+componentStep))/3;
        *(dst1Run++)=(*blue1Run+*(blue1Run+componentStep))/2;
        green1Run+=componentStep;
        blue1Run+=componentStep;
        *(dst1Run++)=(*red1Run+*(red1Run+componentStep))/2;
        *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run+*(green2Run+componentStep))/3:*(green2Run+componentStep);
        *(dst1Run++)=*blue1Run;
        red1Run+=componentStep;
        green2Run+=componentStep;
    }
	//Last row, last column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?*green2Run:(*green1Run+*green2Run)/2;
    *(dst1Run++)=*blue1Run;
    
    if (type == 5 || type == 6) // RGGB or GBRG
    {
        for (y = 0; y < sourceHeight; y++) 
            for (x = 0; x < sourceWidth; x++) 
            {
                unsigned char temp = rgbBuffer[3 * (x + y * sourceWidth) + 0]; // R
                rgbBuffer[3 * (x + y * sourceWidth) + 0] = rgbBuffer[3 * (x + y * sourceWidth) + 2];
                rgbBuffer[3 * (x + y * sourceWidth) + 2] = temp;
            }
    }
}

#define _SL (long)
#define _B1 0xff000000
#define _B2 0x00ff0000
#define _B3 0x0000ff00
#define _B4 0x000000ff

//The following macro applies saturation, brightness, contrast and gamma to a rgb triple
#define COLORPROCESS(r,g,b) {\
    r=(((r-g)*saturation)/65536)+g;\
        b=(((b-g)*saturation)/65536)+g;\
            r=redTransferLookup[CLAMP(r,0,255)];\
                g=greenTransferLookup[CLAMP(g,0,255)];\
                    b=blueTransferLookup[CLAMP(b,0,255)];\
}

#define NOCOLORPROCESS(r,g,b) {\
            r=CLAMP(r,0,255);\
                g=CLAMP(g,0,255);\
                    b=CLAMP(b,0,255);\
}

- (void) postprocessGRBGTo:(unsigned char*)dst dstRowBytes:(long)dstRB dstBPP:(short)dstBPP flip:(BOOL)flip{
/* Does someone have a good idea how to do some speed optimizations in here? */
    unsigned char* src1Run=rgbBuffer;
    unsigned char* src2Run=rgbBuffer+3*sourceWidth;
    unsigned char* src3Run=rgbBuffer+6*sourceWidth;
    unsigned char* src4Run=rgbBuffer+9*sourceWidth;
    long sharpen=(long)(sharpness*65536.0f);		//fixed-point 17:15 factor for sharpening - 0.5 produces standard sharpen
    long x,y;
    long r1,g1,b1,r2,g2,b2,r3,g3,b3,r4,g4,b4;
    unsigned long r1c1,r1c2,r1c3,r2c1,r2c2,r2c3,r3c1,r3c2,r3c3,r4c1,r4c2,r4c3; //Row, column

    long width=MIN(sourceWidth-2,destinationWidth);	//Find out the real (inner) blit size
    long height=MIN(sourceHeight-2,destinationHeight);

    BOOL leftBorder=(destinationWidth>width);		//Find which borders we need to blit (without sharpening)
    BOOL rightBorder=(destinationWidth>(width+1));	//Note that when rightBorder is YES, we can also expect leftBorder
    BOOL topBorder=(destinationHeight>height);
    BOOL bottomBorder=(destinationHeight>(height+1));	//Note that when bottomBorder is YES, we can also expect topBorder

    unsigned char* dst1Run=dst+((leftBorder)?3:0)+((topBorder)?dstRB:0);
    unsigned char* dst2Run=dst1Run+dstRB;

    long srcSkip=6*sourceWidth-3*width;			//Skip two lines of source minus the bytes we add internally
    long dstSkip=2*dstRB-width*dstBPP;			//Skip two lines of destination minus the bytes we add internally

    short writeMode=dstBPP;				//To distinguish the way the pixels are written
    if (flip) {
        writeMode+=256;
        dstSkip+=2*dstBPP*width;
        dst1Run=dst+((rightBorder)?3:0)+((topBorder)?dstRB:0)+width*dstBPP;
        dst2Run=dst1Run+dstRB;
    }
    
//The following two nested loops do the postprocessing for all non-border pixels. Borders follow afterwards
    for (y=height/2;y>0;y--) {
        for (x=width/2;x>0;x--) {
//Step 1: Read matix data from memory to rxcx variables and update source pointers for next iteration
            r1c1=CFSwapInt32HostToBig(*((unsigned long*)(src1Run)));
            r1c2=CFSwapInt32HostToBig(*((unsigned long*)(src1Run+4)));
            r1c3=CFSwapInt32HostToBig(*((unsigned long*)(src1Run+8)));
            r2c1=CFSwapInt32HostToBig(*((unsigned long*)(src2Run)));
            r2c2=CFSwapInt32HostToBig(*((unsigned long*)(src2Run+4)));
            r2c3=CFSwapInt32HostToBig(*((unsigned long*)(src2Run+8)));
            r3c1=CFSwapInt32HostToBig(*((unsigned long*)(src3Run)));
            r3c2=CFSwapInt32HostToBig(*((unsigned long*)(src3Run+4)));
            r3c3=CFSwapInt32HostToBig(*((unsigned long*)(src3Run+8)));
            r4c1=CFSwapInt32HostToBig(*((unsigned long*)(src4Run)));
            r4c2=CFSwapInt32HostToBig(*((unsigned long*)(src4Run+4)));
            r4c3=CFSwapInt32HostToBig(*((unsigned long*)(src4Run+8)));
            src1Run+=6;
            src2Run+=6;
            src3Run+=6;
            src4Run+=6;
/* Step 2: Sharpen. There are many known algorithms that do this task. My first approach was to apply a 3x3 sharpen filter matrix to each component. This does an average sharpening job but introduces some artefacts (some pixels are sharpened too much, some not enough). The secnd approach was to use a different sharpening matrix for each component - based on their interpolation type. Also a bad idea. This is the third approach (it's so simple and obvious that it must habe been invented by someone else before - sorry, I'm too lazy right now to look up the name). The plot is as follows: 

The primary assumption is that resolution in luminance is more important in human reception than chrominance and that in natural images, there is less chrominance structure than luminance. This is especially important for edges: Humans detect edges primarily by luminance. In natural images, borders of differently colored areas are in most cases also accompanied by a change of luminance.

We have produced a linear interpolation in the step before. This is ok for the low frequencies but the high ones are missing. Because of  the linear interpolation, each component (R,G or B) plane may have "peaks" at the points where there was a same-colored sample in the Bayer matrix (of course, there are only peaks where the samples form no linear plane). We assume the pixel components at those peaks to be already correct (because they come directly from the Bayer matrix - not really correct but simpler...) - the other ones have to pe corrected (by adding their high frequency part). There is no way to find out about the high frequencies when we look at the component planes individually - we are below the Nyquist Rate and following the Samling Theorem, there is no way to get that information back (even if we allow introducing aliasing artefacts). But this is the point where our assumption comes into play: Low chrominance means that the components are similar. The idea is to "steal the peak" from another component plane. For every pixel location, there is one color component that has a peak (beacuse of the Bayer matrix samples every location in a certain color). "Stealing the peak" means to calculate the nonlinearity of one plane at a given point and apply this value to another plane at the same point. How the nonlinearity is calculated depends on the interpolation type that was originally used in the linear interpolation step for the pixel component we want to enhance (we take the same shape).

 Of course, this algorithm will also introduce artefacts (there's no way to avoid it if we want to have higher frequencies than those by produced by an "ordinary" interpolation - introducing high frequencies is pure guessing here). But the algorithm introduces almost no artefacts on unicolored areas, soft gradients, and luminance edges. The artefacts introduced are typically on edges with high chrominance change in comparison to luminance. This is something that rarely happens in natural images. I was surprised about the good results. It does everything better than the one before: "Real" high frequencies, less aliasing, less other artefacts, and the main reason: It's faster (some optimizations could still be made, but it should be fast enough for using one camera on every OSX-class machines - G3/233 and up). Another reason to do so: The driver knows about the Bayer matrix and is supposed to give back the best the camera can give. Ordinary sharpening with filter matrices can be done later in a image-processing application of your choice...

Don't take me wrong - this is not the best postprocessing that could be done. But in a live video environment, we don't have much choice...
 
*/
            //Pixel (1,1) red: Pipe, steal from green
            r1=_SL(r2c1&_B4)
                +(((_SL((r2c2&_B1)>>23)-_SL((r1c2&_B1)>>24)-_SL((r3c2&_B1)>>24))*sharpen)/65536);
            //Pixel (1,1) green: Dot
            g1=_SL((r2c2&_B1)>>24);
            //Pixel (1,1) blue: Minus, steal from green
            b1=_SL((r2c2&_B2)>>16)
                +(((_SL((r2c2&_B1)>>23)-_SL((r2c1&_B2)>>16)-_SL(r2c2&_B4))*sharpen)/65536);
            //Pixel (2,1) red: X, steal from blue
            r2=_SL((r2c2&_B3)>>8)
                +(((_SL((r2c3&_B1)>>22)-_SL((r1c2&_B2)>>16)-_SL(r1c3&_B4)-_SL((r3c2&_B2)>>16)-_SL(r3c3&_B4))*sharpen)/131072);
            //Pixel (2,1) green: Plus, steal from blue
            g2=_SL(r2c2&_B4)
                +(((_SL((r2c3&_B1)>>22)-_SL((r1c3&_B1)>>24)-_SL((r2c2&_B2)>>16)-_SL(r2c3&_B4)-_SL((r3c3&_B1)>>24))*sharpen)/131072);
            //Pixel (2,1) blue: Dot
            b2=_SL((r2c3&_B1)>>24);
            //Pixel (1,2) red: Dot
            r3=_SL(r3c1&_B4);
            //Pixel (1,2) green: Plus, steal from red
            g3=_SL((r3c2&_B1)>>24)
                +(((_SL((r3c1&_B4)<<2)-_SL(r2c1&_B4)-_SL((r3c1&_B1)>>24)-_SL((r3c2&_B3)>>8)-_SL(r4c1&_B4))*sharpen)/131072);
            //Pixel (1,2) blue: X, steal from red
            b3=_SL((r3c2&_B2)>>16)
                +(((_SL((r3c1&_B4)<<2)-_SL((r2c1&_B1)>>24)-_SL((r2c2&_B3)>>8)-_SL((r4c1&_B1)>>24)-_SL((r4c2&_B3)>>8))*sharpen)/131072);
            //Pixel (2,2) red: Minus, steal from green
            r4=_SL((r3c2&_B3)>>8)
                +(((_SL((r3c2&_B4)<<1)-_SL((r3c2&_B1)>>24)-_SL((r3c3&_B3)>>8))*sharpen)/65536);
            //Pixel (2,2) green: Dot
            g4=_SL(r3c2&_B4);
            //Pixel (2,2) blue: Pipe, steal from green
            b4=_SL((r3c3&_B1)>>24)
                +(((_SL((r3c2&_B4)<<1)-_SL(r2c2&_B4)-_SL(r4c2&_B4))*sharpen)/65536);

            //Step 3: Apply color adjustments
            if (needsTransferLookup) {
                COLORPROCESS(r1,g1,b1);
                COLORPROCESS(r2,g2,b2);
                COLORPROCESS(r3,g3,b3);
                COLORPROCESS(r4,g4,b4);
            } else {
                NOCOLORPROCESS(r1,g1,b1);
                NOCOLORPROCESS(r2,g2,b2);
                NOCOLORPROCESS(r3,g3,b3);
                NOCOLORPROCESS(r4,g4,b4);
            }                
            //Step 4: Assemble values and write to destination, update destination pointers
            switch (writeMode) {
                case 3:
                    *((unsigned long* )(dst1Run  ))=CFSwapInt32BigToHost((r1<<24)+(g1<<16)+(b1<<8)+r2);
                    *((unsigned short*)(dst1Run+4))=CFSwapInt16BigToHost(                  (g2<<8)+b2);
                    *((unsigned long* )(dst2Run  ))=CFSwapInt32BigToHost((r3<<24)+(g3<<16)+(b3<<8)+r4);
                    *((unsigned short*)(dst2Run+4))=CFSwapInt16BigToHost(                  (g4<<8)+b4);
                    dst1Run+=6;
                    dst2Run+=6;
                    break;
                case 4:
                    *((unsigned long*)(dst1Run  ))=CFSwapInt32BigToHost(0xff000000+(r1<<16)+(g1<<8)+(b1));
                    *((unsigned long*)(dst1Run+4))=CFSwapInt32BigToHost(0xff000000+(r2<<16)+(g2<<8)+(b2));
                    *((unsigned long*)(dst2Run  ))=CFSwapInt32BigToHost(0xff000000+(r3<<16)+(g3<<8)+(b3));
                    *((unsigned long*)(dst2Run+4))=CFSwapInt32BigToHost(0xff000000+(r4<<16)+(g4<<8)+(b4));
                    dst1Run+=8;
                    dst2Run+=8;
                    break;
                case 259:
                    dst1Run-=6;
                    dst2Run-=6;
                    *((unsigned long* )(dst1Run  ))=CFSwapInt32BigToHost((r2<<24)+(g2<<16)+(b2<<8)+r1);
                    *((unsigned short*)(dst1Run+4))=CFSwapInt16BigToHost(                  (g1<<8)+b1);
                    *((unsigned long* )(dst2Run  ))=CFSwapInt32BigToHost((r4<<24)+(g4<<16)+(b4<<8)+r3);
                    *((unsigned short*)(dst2Run+4))=CFSwapInt16BigToHost(                  (g3<<8)+b3);
                    break;
                case 260:
                    dst1Run-=8;
                    dst2Run-=8;
                    *((unsigned long*)(dst1Run  ))=CFSwapInt32BigToHost(0xff000000+(r2<<16)+(g2<<8)+(b2));
                    *((unsigned long*)(dst1Run+4))=CFSwapInt32BigToHost(0xff000000+(r1<<16)+(g1<<8)+(b1));
                    *((unsigned long*)(dst2Run  ))=CFSwapInt32BigToHost(0xff000000+(r4<<16)+(g4<<8)+(b4));
                    *((unsigned long*)(dst2Run+4))=CFSwapInt32BigToHost(0xff000000+(r3<<16)+(g3<<8)+(b3));
                    break;
            }
        }
        src1Run+=srcSkip;
        src2Run+=srcSkip;
        src3Run+=srcSkip;
        src4Run+=srcSkip;
        dst1Run+=dstSkip;
        dst2Run+=dstSkip;
    }

    //All inner pixels are done now. If we need to use borders as well, do it now. Some sensors give us additional borders to interpolate, others do not...
    if (topBorder) {
        int topBorderWidth=width+((leftBorder)?1:0);
        src1Run=rgbBuffer;
        dst1Run=dst;
        if (flip) dst1Run+=topBorderWidth*dstBPP;
        for (x=topBorderWidth;x>0;x--) {
            r1=*(src1Run++);
            g1=*(src1Run++);
            b1=*(src1Run++);
            COLORPROCESS(r1,g1,b1);
            switch (writeMode) {
                case 3:
                    *(dst1Run++)=r1;
                    *(dst1Run++)=g1;
                    *(dst1Run++)=b1;
                    break;
                case 4:
                    *(dst1Run++)=0xff;
                    *(dst1Run++)=r1;
                    *(dst1Run++)=g1;
                    *(dst1Run++)=b1;
                case 259:
                    *(--dst1Run)=b1;
                    *(--dst1Run)=g1;
                    *(--dst1Run)=r1;
                    break;
                case 260:
                    *(--dst1Run)=b1;
                    *(--dst1Run)=g1;
                    *(--dst1Run)=r1;
                    *(--dst1Run)=0xff;
                    break;
            }
        }
    }
    if (leftBorder) {
        src1Run=rgbBuffer+((topBorder)?0:(sourceWidth*3));
        dst1Run=dst;
        if (flip) dst1Run+=(sourceWidth-1)*dstBPP;	//Flip? -> Move left to right border
        for (y=height+((topBorder)?1:0);y>0;y--) {
            r1=src1Run[0];
            g1=src1Run[1];
            b1=src1Run[2];
            COLORPROCESS(r1,g1,b1);
            if (dstBPP==4) {
                dst1Run[0]=0xff;
                dst1Run[1]=r1;
                dst1Run[2]=g1;
                dst1Run[3]=b1;
            } else {
                dst1Run[0]=r1;
                dst1Run[1]=g1;
                dst1Run[2]=b1;
            }
            src1Run+=sourceWidth*3;
            dst1Run+=dstRB;
        }
    }
    if (bottomBorder) {
        int bottomBorderWidth=width+((leftBorder)?1:0)+((rightBorder)?1:0);
        src1Run=rgbBuffer+(sourceHeight-1)*(sourceWidth*3);	//Last line in rgbBuffer
        dst1Run=dst+(sourceHeight-1)*dstRB;			//Last line in dest buffer
        if (flip) dst1Run+=bottomBorderWidth*dstBPP;
        for (x=bottomBorderWidth;x>0;x--) {
            r1=*(src1Run++);
            g1=*(src1Run++);
            b1=*(src1Run++);
            COLORPROCESS(r1,g1,b1);
            switch (writeMode) {
                case 3:
                    *(dst1Run++)=r1;
                    *(dst1Run++)=g1;
                    *(dst1Run++)=b1;
                    break;
                case 4:
                    *(dst1Run++)=0xff;
                    *(dst1Run++)=r1;
                    *(dst1Run++)=g1;
                    *(dst1Run++)=b1;
                case 259:
                    *(--dst1Run)=b1;
                    *(--dst1Run)=g1;
                    *(--dst1Run)=r1;
                    break;
                case 260:
                    *(--dst1Run)=b1;
                    *(--dst1Run)=g1;
                    *(--dst1Run)=r1;
                    *(--dst1Run)=0xff;
                    break;
            }
        }
    }
    if (rightBorder) {
        src1Run=rgbBuffer+(sourceWidth-1)*3;			//Last column in rgbBuffer
        dst1Run=dst+(sourceWidth-1)*dstBPP;			//Last column in dset buffer
        if (flip) dst1Run-=(sourceWidth-1)*dstBPP;		//Flip? -> move right to left border
        for (y=height+((topBorder)?1:0)+((bottomBorder)?1:0);y>0;y--) {
            r1=src1Run[0];
            g1=src1Run[1];
            b1=src1Run[2];
            COLORPROCESS(r1,g1,b1);
            if (dstBPP==4) {
                dst1Run[0]=0xff;
                dst1Run[1]=r1;
                dst1Run[2]=g1;
                dst1Run[3]=b1;
            } else {
                dst1Run[0]=r1;
                dst1Run[1]=g1;
                dst1Run[2]=b1;
            }
            src1Run+=sourceWidth*3;
            dst1Run+=dstRB;
        }
    }
}	

/*
 
 This method will only be called when the rgb (temporary) buffer is filled. 
 
 */

- (void) rotateImage180 {
	long x, y, z;
	long width = sourceWidth;
	long height = sourceHeight;
	unsigned char temp[3];
	unsigned char * buffer = rgbBuffer;
	
	if (buffer == NULL) 
		return;
	
	for (y = 0; y < (height+1)/2; y++) 
		for (x = 0; x < width; x++) 
			for (z = 0; z < 3; z++) 
			{
				temp[z] = rgbBuffer[3 * (y * width + x) + z];
				rgbBuffer[3 * (y * width + x) + z] = rgbBuffer[3 * ((height - y) * width - x - 1) + z];
				rgbBuffer[3 * ((height - y) * width - x - 1) + z] = temp[z];
			}
}


- (void) flipImageHorizontal {
	long x, y, z;
	long width = sourceWidth;
	long height = sourceHeight;
	unsigned char temp[3];
	unsigned char * buffer = rgbBuffer;
	
	if (buffer == NULL) 
		return;
	
	for (y = 0; y < height; y++) 
		for (x = 0; x < (width)/2; x++) 
			for (z = 0; z < 3; z++) 
			{
				temp[z] = rgbBuffer[3 * (y * width + x) + z];
				rgbBuffer[3 * (y * width + x) + z] = rgbBuffer[3 * (y * width + (width - x - 1)) + z];
				rgbBuffer[3 * (y * width + (width - x - 1)) + z] = temp[z];
			}
}

/*

 This method will only be called when the rgb (temporary) buffer is filled. We take the average color of the temp image by adding some sample pixels from the temp image. Its color value is equal to the raw image. It's unsharp, but that doesn't matter... If the existing averages were valid, we update the averages (they are an exponentional average sum), if not, we set them. Then, we calculate compensation gains for the average color (which should sum up to three).

*/

#define STATISTICS_SAMPLE_STEP 5	//take every fifth pixel - it won't be a regular grid and it's faster...
- (void) calcColorStatistics {
    unsigned char* run;
    unsigned char* max=rgbBuffer+3*sourceWidth*sourceHeight;
    unsigned long redSum=0;
    unsigned long greenSum=0;
    unsigned long blueSum=0;
    for (run=rgbBuffer;run<max;run+=3*STATISTICS_SAMPLE_STEP) {
        redSum+=*run;
        greenSum+=run[1];
        blueSum+=run[2];
    }
    meanRed=((float)(redSum))/((float)(sourceWidth*sourceHeight)/(float)STATISTICS_SAMPLE_STEP);
    meanGreen=((float)(greenSum))/((float)(sourceWidth*sourceHeight)/(float)STATISTICS_SAMPLE_STEP);
    meanBlue=((float)(blueSum))/((float)(sourceWidth*sourceHeight)/(float)STATISTICS_SAMPLE_STEP);
    meanRed=MAX(1.0f,meanRed);
    meanGreen=MAX(1.0f,meanGreen);
    meanBlue=MAX(1.0f,meanBlue);
}

#define AVG_SUM_EXP 0.95 //The averaging factor (0..1( - higher value means slower reaction to color changes 
- (void) updateGainsToColorStats {
    float averageSumFactor=(1.0f/(1.0f-AVG_SUM_EXP));
    float scaleFactor;

    scaleFactor=3.0f/(meanRed+meanGreen+meanBlue);//Scale (r,g,b) to sum up to the same as the unit color (1,1,1). 

//Update/set to averages
    if (averageSumsValid) {
        averageRedSum=averageRedSum*AVG_SUM_EXP+meanRed*scaleFactor;
        averageGreenSum=averageGreenSum*AVG_SUM_EXP+meanGreen*scaleFactor;
        averageBlueSum=averageBlueSum*AVG_SUM_EXP+meanBlue*scaleFactor;
    } else {
        averageRedSum=meanRed*scaleFactor*averageSumFactor;
        averageGreenSum=meanGreen*scaleFactor*averageSumFactor;
        averageBlueSum=meanBlue*scaleFactor*averageSumFactor;
        averageSumsValid=YES;
    }

/* Average sums are now ok - they represent averageFactor times the mean color scaled to be about equally bright to (1,1,1) ("almost" because the individual  components are unweighted). Now calculate the gains. Note that this method is not good yet - it produces quite high gains for extreme colors - mathematically, this is correct - it makes the average gray. But it doesn't look too good... Maybe a nonlinear reduction would be fine... Maybe only brighter colors should be taken into account... Maybe I should read a bit about color correction... This solution is an ad hoc hack. */

    redGain=1.0f/(averageRedSum/averageSumFactor);
    greenGain=1.0f/(averageGreenSum/averageSumFactor);
    blueGain=1.0f/(averageBlueSum/averageSumFactor);
//    NSLog(@"auto gains: %f %f %f",redGain,greenGain,blueGain);
    [self recalcTransferLookup];
}

- (void) recalcTransferLookup {
    float f,r,g,b;
    short i;
    float sat=((float)saturation)/65536.0f;
    for (i=0;i<256;i++) {
        f=((float)i)/255;
        f=pow(f,gamma);					//Bend to gamma
        f+=brightness;					//Offset brightness
        f=((f-0.5f)*contrast)+0.5f;			//Scale around 0.5
        f*=255.0f;					//Scale to [0..255]
        r=f*(sat*redGain+(1.0f-sat));			//Scale to red gain (itself scaled by saturation)
        g=f*(sat*greenGain+(1.0f-sat));			//Scale to green gain (itself scaled by saturation)
        b=f*(sat*blueGain+(1.0f-sat));			//Scale to blue gain (itself scaled by saturation)
        redTransferLookup[i]=CLAMP(r,0.0f,255.0f);	//Clamp and set
        greenTransferLookup[i]=CLAMP(g,0.0f,255.0f);	//Clamp and set
        blueTransferLookup[i]=CLAMP(b,0.0f,255.0f);;	//Clamp and set
    }
    needsTransferLookup=(gamma!=1.0f)||(brightness!=0.0f)||(contrast!=1.0f)
        ||(saturation!=65536)||(redGain!=1.0f)||(greenGain!=1.0f)||(blueGain!=1.0f);
}

@end


@interface CyYeGMgConverter (Private)

- (void) demosaicFrom:(unsigned char*)src type:(short)type srcRowBytes:(long)srcRowBytes;

@end


@implementation CyYeGMgConverter


- (void) setSourceFormat: (short) fmt
{
    if ((fmt < 1) || (fmt > 8)) 
        return;
    sourceFormat = fmt;
}


//Internals
- (void) demosaicFrom: (unsigned char *) src type: (short) type srcRowBytes: (long) srcRowBytes 
{
/*
    Format 8 - CMYG??
    
    Cy  Ye  Cy  Ye  Cy  Ye ...
    G   Mg  G   Mg  G   Mg ...
    Cy  Ye  Cy  Ye  Cy  Ye ...
    Mg  G   Mg  G   Mg  G  ...
    Cy  Ye  Cy  Ye  Cy  Ye ...
    G   Mg  G   Mg  G   Mg ...
    Cy  Ye  Cy  Ye  Cy  Ye ...
    Mg  G   Mg  G   Mg  G  ...
    .
    .
    .
    
*/
    /*
    short g1,g2,g3,g4,g5,g6,g7,g8;
    short r1,r2,r3,r4;
    short b1,b2,b3,b4;
	
    unsigned char *green1Run,*green2Run,*green3Run,*green4Run;
    unsigned char *red1Run,*red2Run,*blue1Run,*blue2Run;
    unsigned char *dst1Run,*dst2Run;
    long dstSkip=sourceWidth*3;
	BOOL GRBGtype = YES;  //  As opposed to BGGR
	BOOL CyYeGrMgtype = NO;
	
    // every other pixel is the same type of component
    long componentStep = 2;
    // 
    long srcSkip = 2 * srcRowBytes - (sourceWidth / 2) * componentStep;
*/
    int Cy, Ye, Gr, Mg, R, G, B;
    int x, y, alternate;
    
    if (type <= MAX_BAYER_TYPE) 
        [super demosaicFrom:src type:type srcRowBytes:srcRowBytes];
    
//    printf("Processing CyYeGMg pattern now!\n");
    
    for (y = 0; y < sourceHeight; y += 2) 
        for (x = 0; x < sourceWidth; x+= 2) 
        {
            alternate = (y % 4 == 0) ? 0 : 1;
            
            Cy = src[(y + 0) * srcRowBytes + (x + 0)];
            Ye = src[(y + 0) * srcRowBytes + (x + 1)];
            Gr = src[(y + 1) * srcRowBytes + (x + 0 + alternate)];
            Mg = src[(y + 1) * srcRowBytes + (x + 1 - alternate)];
            
            R = Mg + Ye - Cy;
            G = Ye + Cy - Mg;
            B = Cy + Mg - Ye;
            
            // G should be close to Gr
            
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 0] = CLAMP(R,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 1] = CLAMP(G,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 2] = CLAMP(B,0,255);
            
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 0] = CLAMP(R,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 1] = CLAMP(G,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 2] = CLAMP(B,0,255);
            
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0)) + 0] = CLAMP(R,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0 + alternate)) + 1] = CLAMP(Gr,0,255); // G should be close to Gr
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0)) + 2] = CLAMP(B,0,255);
            
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1)) + 0] = CLAMP(R,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1 - alternate)) + 1] = CLAMP(G,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1)) + 2] = CLAMP(B,0,255);

#if 1
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 0] = CLAMP(0,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 1] = CLAMP(Cy,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 0)) + 2] = CLAMP(Cy,0,255);
            
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 0] = CLAMP(Ye,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 1] = CLAMP(Ye,0,255);
            rgbBuffer[3 * (((y + 0) * sourceWidth) + (x + 1)) + 2] = CLAMP(0,0,255);
            
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0 + alternate)) + 0] = CLAMP(0,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0 + alternate)) + 1] = CLAMP(Gr,0,255); // G should be close to Gr
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 0 + alternate)) + 2] = CLAMP(0,0,255);
            
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1 - alternate)) + 0] = CLAMP(Mg,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1 - alternate)) + 1] = CLAMP(0,0,255);
            rgbBuffer[3 * (((y + 1) * sourceWidth) + (x + 1 - alternate)) + 2] = CLAMP(Mg,0,255);
#endif
        }
        
    
/*
    // corners
    
    // TL
    // TR
    // BL
    // BR
    
    // top & bottom
    
    for (x = 1; x < sourceWidth - 1; x++) 
    {
        // TOP
        // BOTTOM
    }
    
    // sides
    
    for (y = 1; y < sourceHeight - 1; y++) 
    {
        // LEFT
        // RIGHT
    }
    
    // middle
    
    for (x = 1; x < sourceWidth - 1; x++) 
    {
        for (y = 1; y < sourceHeight - 1; y++) 
        {
            // MIDDLE
            
            src[y * srcRowBytes + x];
        }
    }
*/
         
         
#if 0    
    switch (type) 
    {
        case 1:	//Components planar in half row, order swapped (STV680-style)
            componentStep=1;
            green1Run =src+sourceWidth/2;
            red1Run   =src;
            blue1Run  =src+srcRowBytes+sourceWidth/2;
            green2Run =src+srcRowBytes;
            break;
        case 2:	//Interleaved data (STV600-style) // GRBG
        case 6: // works like 4 then switch R and B at the end // GBRG
            componentStep=2;
            green1Run =src;
            red1Run   =src+1;
            blue1Run  =src+srcRowBytes;
            green2Run =src+srcRowBytes+1;
            break;
        case 3:	//Row 1: xGxG, Row 2: RBRB (QuickCam Pro subsampled-style)
            componentStep=2;
            red1Run   =src+srcRowBytes+1;
            green1Run =src+1;
            green2Run =src+1;
            blue1Run  =src+srcRowBytes;
            break;
        case 8: // Cy Ye Gr Mg weirdness
            CyYeGrMgtype = YES;
        case 4:	// OV7630 style // BGGR
        case 5: // works like 4 then switch R and B at the end // RGGB
			GRBGtype = NO;
            componentStep=2;
            blue1Run  =src;
            green1Run =src+1;
            green2Run =src+srcRowBytes;
            red1Run   =src+srcRowBytes+1;
            break;
        default: //Assume type 2
#ifdef VERBOSE
            NSLog(@"BayerConverter: Unknown bayer data type: %i",type);
#endif VERBOSE
            componentStep=2;
            green1Run =src;
            red1Run   =src+1;
            blue1Run  =src+srcRowBytes;
            green2Run =src+srcRowBytes+1;
            break;
    }
	
    //init data run pointers
    srcSkip =2*srcRowBytes-(((sourceWidth-2)/2)*componentStep);
	// componentStep is added here to compensate for the initial subtraction in the big loop below
	// the loop over the non-border rows starts with the runs pointing to the left half
	// one could probably eliminate both adding it here and subtracting it later
    green3Run =green1Run+2*srcRowBytes+componentStep;
    red2Run   =red1Run+2*srcRowBytes+componentStep;
    blue2Run  =blue1Run+2*srcRowBytes+componentStep;
    green4Run =green2Run+2*srcRowBytes+componentStep;
    dst1Run=rgbBuffer;
    dst2Run=rgbBuffer+2*dstSkip;
	
	//First row, first column
    *(dst1Run++)=*red1Run;
	*(dst1Run++)=(GRBGtype)?*green1Run:(*green1Run+*green2Run)/2;
    *(dst1Run++)=*blue1Run;
	//First row, non-border columns
    for (x=(sourceWidth-2)/2;x>0;x--) {
        *(dst1Run++)=*red1Run;
        *(dst1Run++)=(GRBGtype)?(*green1Run+*(green1Run+componentStep)+*green2Run)/3:*green1Run;
        *(dst1Run++)=(*blue1Run+*(blue1Run+componentStep))/2;
        if (GRBGtype) green1Run+=componentStep;
        green2Run+=componentStep;
        blue1Run+=componentStep;
        *(dst1Run++)=(*red1Run+*(red1Run+componentStep))/2;
        *(dst1Run++)=(GRBGtype)?*green1Run:(*green1Run+*(green1Run+componentStep)+*green2Run)/3;
        *(dst1Run++)=*blue1Run;
        red1Run+=componentStep;
        if (!GRBGtype) green1Run+=componentStep;
    }
	//First row, last column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run)/2:*green1Run;
    *(dst1Run++)=*blue1Run;
	//Reset the src data run pointers we changed in the first row - dst1RUn is ok now
    green1Run =green3Run-2*srcRowBytes;
    red1Run   =red2Run-2*srcRowBytes;
    blue1Run  =blue2Run-2*srcRowBytes;
    green2Run =green4Run-2*srcRowBytes;
    
    
	//All non-border rows
    for (y=(sourceHeight-2)/2;y>0;y--) {
		//init right half of colors to left values - will be shifted inside the loop
        r2=*(red1Run-componentStep);	
        r4=*(red2Run-componentStep);
        g2=*(green1Run-componentStep);
        g4=*(green2Run-componentStep);
        g6=*(green3Run-componentStep);
        g8=*(green4Run-componentStep);
        b2=*(blue1Run-componentStep);
        b4=*(blue2Run-componentStep);
		
		//First pixel column in row
        *(dst1Run++)=(GRBGtype)?(r2+r4)/2:r2;
        *(dst1Run++)=(GRBGtype)?(g2+g4+g6)/3:g2;
        *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
        *(dst2Run++)=(GRBGtype)?r4:(r2+r4)/2;
        *(dst2Run++)=(GRBGtype)?g6:(g4+g6+g8)/3;
        *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
		
		//All non-border columns in row
        for (x=(sourceWidth-2)/2;x>0;x--) {
            //shift right half of colors to left half
            r1=r2;
            r3=r4;
            g1=g2;
            g3=g4;
            g5=g6;
            g7=g8;
            b1=b2;
            b3=b4;
            //read new ones
            r2=*red1Run; red1Run+=componentStep;
            g2=*green1Run; green1Run+=componentStep;
            g4=*green2Run; green2Run+=componentStep;
            b2=*blue1Run; blue1Run+=componentStep;
            r4=*red2Run; red2Run+=componentStep;
            g6=*green3Run; green3Run+=componentStep;
            g8=*green4Run; green4Run+=componentStep;
            b4=*blue2Run; blue2Run+=componentStep;
			
            //Interpolate Pixel (2,2): location of g3 (r1).
            *(dst1Run++)=(GRBGtype)?(r1+r3)/2:r1;
            *(dst1Run++)=(GRBGtype)?g3:(g1+g3+g4+g5)/4;
            *(dst1Run++)=(GRBGtype)?(b1+b2)/2:(b1+b2+b3+b4)/4;
            //Interpolate Pixel (3,2): location of b2 (g4).
            *(dst1Run++)=(GRBGtype)?(r1+r2+r3+r4)/4:(r1+r2)/2;
            *(dst1Run++)=(GRBGtype)?(g2+g3+g4+g6)/4:g4;
            *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
            //Interpolate Pixel (2,3): location of r3 (g5).
            *(dst2Run++)=(GRBGtype)?r3:(r1+r3)/2;
            *(dst2Run++)=(GRBGtype)?(g3+g5+g6+g7)/4:g5;
            *(dst2Run++)=(GRBGtype)?(b1+b2+b3+b4)/4:(b3+b4)/2;
            //Interpolate Pixel (3,3): location of g6 (b4).
            *(dst2Run++)=(GRBGtype)?(r3+r4)/2:(r1+r2+r3+r4)/4;
            *(dst2Run++)=(GRBGtype)?g6:(g4+g5+g6+g8)/4;
            *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
        }
		
		//last pixel column in row
        *(dst1Run++)=(GRBGtype)?(r2+r4)/2:r2;
        *(dst1Run++)=(GRBGtype)?g4:(g2+g4+g6)/3;
        *(dst1Run++)=(GRBGtype)?b2:(b2+b4)/2;
        *(dst2Run++)=(GRBGtype)?r4:(r2+r4)/2;
        *(dst2Run++)=(GRBGtype)?(g4+g6+g8)/3:g6;
        *(dst2Run++)=(GRBGtype)?(b2+b4)/2:b4;
		
		//go to start of next two lines
        dst1Run+=dstSkip;
        dst2Run+=dstSkip;
        red1Run+=srcSkip;
        red2Run+=srcSkip;
        green1Run+=srcSkip;
        green2Run+=srcSkip;
        green3Run+=srcSkip;
        green4Run+=srcSkip;
        blue1Run+=srcSkip;
        blue2Run+=srcSkip;
    }
    // corrections
    red1Run   += srcRowBytes - srcSkip;
    red2Run   += srcRowBytes - srcSkip;
    green1Run += srcRowBytes - srcSkip;
    green2Run += srcRowBytes - srcSkip;
    green3Run += srcRowBytes - srcSkip;
    green4Run += srcRowBytes - srcSkip;
    blue1Run  += srcRowBytes - srcSkip;
    blue2Run  += srcRowBytes - srcSkip;
	//Last row, first column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run)/2:*green1Run;
    *(dst1Run++)=*blue1Run;
	//Last row, non-border columns
    for (x=(sourceWidth-2)/2;x>0;x--) {
        *(dst1Run++)=*red1Run;
        *(dst1Run++)=(GRBGtype)?*green2Run:(*green1Run+*green2Run+*(green2Run+componentStep))/3;
        *(dst1Run++)=(*blue1Run+*(blue1Run+componentStep))/2;
        green1Run+=componentStep;
        blue1Run+=componentStep;
        *(dst1Run++)=(*red1Run+*(red1Run+componentStep))/2;
        *(dst1Run++)=(GRBGtype)?(*green1Run+*green2Run+*(green2Run+componentStep))/3:*(green2Run+componentStep);
        *(dst1Run++)=*blue1Run;
        red1Run+=componentStep;
        green2Run+=componentStep;
    }
	//Last row, last column
    *(dst1Run++)=*red1Run;
    *(dst1Run++)=(GRBGtype)?*green2Run:(*green1Run+*green2Run)/2;
    *(dst1Run++)=*blue1Run;
    
    if (type == 5 || type == 6) // RGGB or GBRG
    {
        for (y = 0; y < sourceHeight; y++) 
            for (x = 0; x < sourceWidth; x++) 
            {
                unsigned char temp = rgbBuffer[3 * (x + y * sourceWidth) + 0]; // R
                rgbBuffer[3 * (x + y * sourceWidth) + 0] = rgbBuffer[3 * (x + y * sourceWidth) + 2];
                rgbBuffer[3 * (x + y * sourceWidth) + 2] = temp;
            }
    }
#endif
}


- (void) processTriplet: (UInt8 *) triplet
{
    int g =    triplet[1];
    int r = (((triplet[0] - g) * saturation) / 65536) + g;
    int b = (((triplet[2] - g) * saturation) / 65536) + g;
    
    triplet[0] = redTransferLookup[CLAMP(r,0,255)];
    triplet[1] = greenTransferLookup[CLAMP(g,0,255)];
    triplet[2] = blueTransferLookup[CLAMP(b,0,255)];
}


- (void) processImage: (UInt8 *) buffer numRows: (long) numRows rowBytes: (long) rowBytes bpp: (short) bpp
{
    UInt8 * ptr;
    long  w, h;
    
    if (needsTransferLookup) 
        for (h = 0; h < numRows; h++) 
        {
            ptr = buffer + h * rowBytes;
            
            if (bpp == 4) 
                ptr++;
            
            for (w = 0; w < rowBytes; w += bpp, ptr += bpp) 
                [self processTriplet:ptr];
        }
}


- (void) postprocessGRBGTo: (unsigned char*) dst dstRowBytes: (long) dstRB dstBPP: (short) dstBPP flip: (BOOL) flip
{
    // copy rgbBuffer to dst
    
    unsigned char * src = rgbBuffer;
    unsigned char * dst_saved = dst;
    
    int width  = MIN(sourceWidth, destinationWidth);
    int height = MIN(sourceHeight, destinationHeight);
    int srcBPP = 3;
    int srcRB = sourceWidth * srcBPP;
    int srcRowSkip = srcRB - width * srcBPP;
    int dstRowSkip = dstRB - width * dstBPP;
    int x,y;
    
    for (y = 0; y < height; y++) 
    {
        for (x = 0; x < height; x++) 
        {
            if (dstBPP == 4) *(dst++) = 255;
            *(dst++) = *(src++);
            *(dst++) = *(src++);
            *(dst++) = *(src++);
        }
        
        src += srcRowSkip;
        dst += dstRowSkip;
    }
    
    [self processImage:dst_saved numRows:height rowBytes:dstRB bpp:dstBPP];
}

@end
