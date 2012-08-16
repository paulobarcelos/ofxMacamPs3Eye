#include "ofxMacamPs3Eye.h"
#include <iostream>
#include <Cocoa/Cocoa.h>
#import "PS3EyeWindowAppDelegate.h"

ofxMacamPs3Eye::ofxMacamPs3Eye():
ps3eye([[PS3EyeWindowAppDelegate alloc] init]),
deviceID(-1),
inited(false),
desiredFPS(30),
bUseTex(true)
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
	[ofxMacamPs3EyeCast(ps3eye) connectTo:(unsigned long) deviceID];
	[ofxMacamPs3EyeCast(ps3eye) useWidth:w useHeight:h useFps:desiredFPS];
	[ofxMacamPs3EyeCast(ps3eye) startGrabbing];
	if(bUseTex)	tex.allocate(getWidth(), getHeight(), GL_RGB, true);
	
	return true;
}
void ofxMacamPs3Eye::update(){
	if([ofxMacamPs3EyeCast(ps3eye).driver imageBuffer]){
		pixels.setFromExternalPixels([ofxMacamPs3EyeCast(ps3eye).driver imageBuffer], getWidth(), getHeight(), 3);
		if (bUseTex) {
			tex.loadData(getPixels(), getWidth(), getHeight(), GL_RGB);
		}
	}
};
bool ofxMacamPs3Eye::isFrameNew(){};

unsigned char * ofxMacamPs3Eye::getPixels(){
	return pixels.getPixels();
}
ofPixels & ofxMacamPs3Eye::getPixelsRef(){
	return pixels;
}

void ofxMacamPs3Eye::close(){
	[ofxMacamPs3EyeCast(ps3eye) shutdown];
}

float ofxMacamPs3Eye::getHeight(){
	return [ofxMacamPs3EyeCast(ps3eye).driver height];
}
float ofxMacamPs3Eye::getWidth(){
	return [ofxMacamPs3EyeCast(ps3eye).driver width];
}

void ofxMacamPs3Eye::draw(float x, float y, float w, float h){
	if(bUseTex)tex.draw(x,y,w,h);
}

void ofxMacamPs3Eye::setDesiredFrameRate(int framerate){
	desiredFPS = framerate;
}

void ofxMacamPs3Eye::setAnchorPercent(float xPct, float yPct){
	if(bUseTex)tex.setAnchorPercent(xPct, yPct);
}
void ofxMacamPs3Eye::setAnchorPoint(float x, float y){
	if(bUseTex)tex.setAnchorPercent(x, y);
}
void ofxMacamPs3Eye::resetAnchor(){
	if(bUseTex)tex.resetAnchor();
}

ofTexture & ofxMacamPs3Eye::getTextureReference(){
	return tex;
}
void ofxMacamPs3Eye::setUseTexture(bool bUseTex){
	this->bUseTex = bUseTex;
}

