#include "PS3EyeWrapper.h"

#include <iostream>
#include <Cocoa/Cocoa.h>
#import "PS3EyeWindowAppDelegate.h"

PS3EyeWindowAppDelegate* ps3eye;

void ps3eyeInit() {
	ps3eye = [[PS3EyeWindowAppDelegate alloc] init];
	[ps3eye connect];
}

bool ps3eyeIsFrameNew() {
	return [ps3eye isFrameNew];
}