#include "ofxMacamPs3Eye.h"
#include <iostream>
#include <Cocoa/Cocoa.h>
#import "PS3EyeWindowAppDelegate.h"

ofxMacamPs3Eye::ofxMacamPs3Eye():
ps3eye([[PS3EyeWindowAppDelegate alloc] init]),
deviceID(-1),
inited(false),
desiredFPS(30)
{
}
ofxMacamPs3Eye::~ofxMacamPs3Eye(){
	close();
}

void ofxMacamPs3Eye::listDevices(){
	[ofxMacamPs3EyeCast(ps3eye).central listAllCameras];
}
void ofxMacamPs3Eye::setDeviceID(int _deviceID){
	deviceID = _deviceID;
}
bool ofxMacamPs3Eye::initGrabber(int w, int h){
	close();
	[ofxMacamPs3EyeCast(ps3eye) connectTo:(unsigned long) deviceID];
	[ofxMacamPs3EyeCast(ps3eye) useWidth:w useHeight:h useFps:desiredFPS];
	[ofxMacamPs3EyeCast(ps3eye) startGrabbing];
}
void ofxMacamPs3Eye::update(){};
bool ofxMacamPs3Eye::isFrameNew(){};

unsigned char * ofxMacamPs3Eye::getPixels(){};
ofPixels & ofxMacamPs3Eye::getPixelsRef(){};

void ofxMacamPs3Eye::close(){
	[ofxMacamPs3EyeCast(ps3eye) shutdown];
}

float ofxMacamPs3Eye::getHeight(){};
float ofxMacamPs3Eye::getWidth(){};

void ofxMacamPs3Eye::draw(float x, float y, float w, float h){};

void ofxMacamPs3Eye::setDesiredFrameRate(int framerate){
	
}

void ofxMacamPs3Eye::setAnchorPercent(float xPct, float yPct){};
void ofxMacamPs3Eye::setAnchorPoint(float x, float y){};
void ofxMacamPs3Eye::resetAnchor(){};

ofTexture & ofxMacamPs3Eye::getTextureReference(){};
void ofxMacamPs3Eye::setUseTexture(bool bUseTex){};

