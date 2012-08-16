#import "PS3EyeWindowAppDelegate.h"

@implementation PS3EyeWindowAppDelegate

@synthesize window, central, driver;

-(id)init {
	self = [super init];
	if(self) {
		central = [MyCameraCentral sharedCameraCentral];
		//[central setDelegate:self];
		[central startupWithNotificationsOnMainThread:YES recognizeLaterPlugins:YES];
		
		driver=NULL;
	}
	return self;
}

- (void)connectTo:(unsigned long)cid {
	CameraError err;
	err=[central useCameraWithID:cid to:&driver acceptDummy:NO];
	if (err) 
	{
		driver=NULL;
		switch (err) 
		{
			case CameraErrorBusy:NSLog(@"Status: Camera used by another app"); break;
			case CameraErrorNoPower:NSLog(@"Status: Not enough USB bus power"); break;
			case CameraErrorNoCam:NSLog(@"Status: Camera not found (this shouldn't happen)"); break;
			case CameraErrorNoMem:NSLog(@"Status: Out of memory"); break;
			case CameraErrorUSBProblem:NSLog(@"Status: USB communication problem"); break;
			case CameraErrorInternal:NSLog(@"Status: Internal error (this shouldn't happen)"); break;
			case CameraErrorUnimplemented:NSLog(@"Status: Unsupported"); break;
			default:NSLog(@"Status: Unknown error (this shouldn't happen)"); break;
		}
	}
	if (driver!=NULL) 
	{
		if ([driver hasSpecificName]){
			NSLog(@"Status: Connected to %@", [driver getSpecificName]);
		}
		else{
			NSLog(@"Status: Connected to %@", [central nameForID:cid]);
		}
		[driver setDelegate:self];
		[driver retain];			//We keep our own reference

	}
}

- (void)useWidth:(int)w useHeight:(int)h useFps:(int)f{
	if ((w - 320) > 160) {
		w = 640;
	}
	if ((w - 320) < 160) {
		w = 320;
	}
	if ((h - 240) > 120) {
		h = 480;
	}
	if ((h - 240) < 120) {
		h = 240;
	}
	
	if(w == 320) cameraResolution = ResolutionSIF;
	else if(w == 640) cameraResolution = ResolutionVGA;
	cameraWidth = w;
	cameraHeight = h;
	cameraFPS = f;
	
	// Insert code here to initialize your application 
	image=[[NSImage alloc] init];
	[image setCacheDepthMatchesImageDepth:YES];			//We have to set this to work with thousands of colors
	imageRep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL	//Set up just to avoid a NIL imageRep
													 pixelsWide:cameraWidth
													 pixelsHigh:cameraHeight
												  bitsPerSample:8	
												samplesPerPixel:3
													   hasAlpha:NO
													   isPlanar:NO
												 colorSpaceName:NSDeviceRGBColorSpace
													bytesPerRow:0
												   bitsPerPixel:0];
	assert (imageRep);
	memset([imageRep bitmapData],0,[imageRep bytesPerRow]*[imageRep pixelsHigh]);
	[image addRepresentation:imageRep]; 
	
	
	imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(0, cameraHeight, cameraWidth, cameraHeight)] autorelease];
	imageView.image = image;
	
	[window setContentView:imageView];	 
	[window makeKeyAndOrderFront:self];
	[window setFrame:NSMakeRect(0, 768, 1024, 768) display:YES];
	
	[driver setResolution:cameraResolution fps:cameraFPS];
}

- (void) startGrabbing { 
	 cameraGrabbing=[driver startGrabbing];
	 if (cameraGrabbing){
	 NSLog(@"PS3EyeWindowAppDelegate camera is grabbing");
	 //		[self setImageOfToolbarItem:PlayToolbarItemIdentifier to:@"PauseToolbarItem"];
	 //		 NSLog(@"Status: Playing")];
	 //		 [fpsPopup setEnabled:NO];
	 //		 [sizePopup setEnabled:NO];
	 //		 [compressionSlider setEnabled:NO];
	 //		 [reduceBandwidthCheckbox setEnabled:NO];
	 [driver setImageBuffer:[imageRep bitmapData] bpp:3 rowBytes:[driver width]*3];
	 }
	 else{
	 NSLog(@"PS3EyeWindowAppDelegate camera not grabbing");
	 }
}

- (void)shutdown{
	[driver shutdown];
}

- (BOOL)isFrameNew
{
	if (frameNew) {
		frameNew = false;
		return true;
	}
	return false;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
	[self connect];
}

- (void) cameraDetected:(unsigned long) cid
{
	/*NSLog(@"CID %lu", cid);
	CameraError err;
	if (!driver) 
	{
		err=[central useCameraWithID:cid to:&driver acceptDummy:NO];
		if (err) 
		{
			driver=NULL;
			switch (err) 
			{
				case CameraErrorBusy:NSLog(@"Status: Camera used by another app"); break;
				case CameraErrorNoPower:NSLog(@"Status: Not enough USB bus power"); break;
				case CameraErrorNoCam:NSLog(@"Status: Camera not found (this shouldn't happen)"); break;
				case CameraErrorNoMem:NSLog(@"Status: Out of memory"); break;
				case CameraErrorUSBProblem:NSLog(@"Status: USB communication problem"); break;
				case CameraErrorInternal:NSLog(@"Status: Internal error (this shouldn't happen)"); break;
				case CameraErrorUnimplemented:NSLog(@"Status: Unsupported"); break;
				default:NSLog(@"Status: Unknown error (this shouldn't happen)"); break;
			}
		}
		if (driver!=NULL) 
		{
			if ([driver hasSpecificName])
			{
				NSLog(@"Status: Connected to %@", [driver getSpecificName]);
			}else 
			{
				NSLog(@"Status: Connected to %@", [central nameForID:cid]);
			}
			[driver setDelegate:self];
			[driver retain];			//We keep our own reference
			NSLog(@"PS3EyeWindowAppDelegate: setting cameraWidth: %d cameraHeight: %d cameraFPS: %d", cameraWidth, cameraHeight, cameraFPS);
			[driver setResolution:cameraResolution fps:cameraFPS];
			cameraGrabbing=NO;
			if ([driver supportsCameraFeature:CameraFeatureInspectorClassName]) 
			{
				NSString* inspectorName=[driver valueOfCameraFeature:CameraFeatureInspectorClassName];
				if (inspectorName)
				{
					if (![@"MyCameraInspector" isEqualToString:inspectorName]) 
					{
//						Class c=NSClassFromString(inspectorName);
//						 inspector=[(MyCameraInspector*)[c alloc] initWithCamera:driver];
//						 if (inspector) 
//						 {
//						 NSDrawerState state;
//						 [inspectorDrawer setContentView:[inspector contentView]];
//						 state=[settingsDrawer state];
//						 if ((state==NSDrawerOpeningState)||(state==NSDrawerOpenState)) 
//						 {
//						 [inspectorDrawer openOnEdge:NSMinXEdge];
//						 }
//						 }
					}
				}
			}
		}
	}*/
}

- (void) imageReady:(id)cam 
{
	frameNew = true;
	if (cam!=driver) return;	//probably an old one
	[imageView display];
	[driver setImageBuffer:[driver imageBuffer] bpp:[driver imageBufferBPP] rowBytes:[driver imageBufferRowBytes]];
}

- (void) updateStatus:(NSString *)status fpsDisplay:(float)fpsDisplay fpsReceived:(float)fpsReceived
{
	NSString * append;
	NSString * newStatus;
	
	if (fpsReceived == 0.0) 
	{
	  append = [NSString stringWithFormat:LStr(@" (%3.1f fps)"), fpsDisplay];	
	}else 
	{
		append = [NSString stringWithFormat:LStr(@" (%3.1f fps, receiving %3.1f fps)"), fpsDisplay, fpsReceived];
	}
	
	if (status == NULL)
	{
		newStatus = [[NSString stringWithString:LStr(@"Status: Playing")] stringByAppendingString:append];
	}else 
	{
		newStatus = [status stringByAppendingString:append];
	}
	
	NSLog(@"updateStatus %@", newStatus);
	//[statusText setStringValue:newStatus];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	NSLog(@"PS3EyeWindowAppDelegate applicationWillTerminate");
	[central shutdown];
	[imageView setImage:NULL];
	[image release];
}
- (void) dealloc 
{
	
	[super dealloc];
}
@end
