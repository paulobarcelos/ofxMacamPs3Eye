#include "ofxMacamPs3Eye.h"
#include <iostream>
#include <Cocoa/Cocoa.h>
#import "PS3EyeWindowAppDelegate.h"

ofxMacamPs3Eye::ofxMacamPs3Eye():
ps3eye([[PS3EyeWindowAppDelegate alloc] init]),
deviceID(-1),
inited(false),
desiredFPS(180),
bUseTex(true),
frameIsNew(false),
autoGainAndShutter(true),
isInited(false)
{
	ofAddListener(ofEvents().exit, this, &ofxMacamPs3Eye::exit);
}
ofxMacamPs3Eye::~ofxMacamPs3Eye(){
	close();
}

vector<ofxMacamPs3EyeDeviceInfo*> ofxMacamPs3Eye::getDeviceList(bool verbose){
	// We need to start the central to get this info
	[[MyCameraCentral sharedCameraCentral] startupWithNotificationsOnMainThread:YES recognizeLaterPlugins:YES];
	
	vector<ofxMacamPs3EyeDeviceInfo*> deviceList;
	
	if(verbose)ofLogVerbose("---------------------------");
	if(verbose)ofLogVerbose("ofxMacamPs3Eye:: Device List");
	for(int i = 0; i < [[MyCameraCentral sharedCameraCentral] numCameras]; i++){
		ofxMacamPs3EyeDeviceInfo * info = new ofxMacamPs3EyeDeviceInfo();
		info->id = [[MyCameraCentral sharedCameraCentral] idOfCameraWithIndex:i];
		[[MyCameraCentral sharedCameraCentral] getName:info->name forID:info->id maxLength:255];
		deviceList.push_back(info);		
		if(verbose)ofLogVerbose("["+ofToString(info->id)+"] - " + info->name);
	}
	if(verbose)ofLogVerbose("---------------------------");
	
	return deviceList;
}
void ofxMacamPs3Eye::setDeviceID(int _deviceID){
	vector<ofxMacamPs3EyeDeviceInfo*> deviceList = getDeviceList(true);
	bool idValid = false;
	for (int i = 0; i < deviceList.size(); i++) {
		if(_deviceID == deviceList[i]->id){
			idValid = true;
			break;
		}
	}
	if (!idValid) {
		deviceID = deviceList[0]->id;
		ofLogWarning("ofxMacamPs3Eye:: DeviceID ("+ofToString(_deviceID)+") is invalid. Setting to the first valid id ("+ofToString(deviceID)+"). Be aware that this id can already be in use.");
	}
	else {
		deviceID = _deviceID;
	}

	if(isInited) initGrabber(getWidth(), getHeight());
}
bool ofxMacamPs3Eye::initGrabber(int w, int h, bool defaultSettingsHack){
	close();
	if(deviceID == -1) setDeviceID(0);
	
	bool success = false;
	if([ofxMacamPs3EyeCast(ps3eye) connectTo:(unsigned long) deviceID]){
		[ofxMacamPs3EyeCast(ps3eye) useWidth:w useHeight:h useFps:desiredFPS];
		if([ofxMacamPs3EyeCast(ps3eye) startGrabbing]){
			if(bUseTex)	tex.allocate(getWidth(), getHeight(), GL_RGB, true);
			
			if(defaultSettingsHack){
				ofLogWarning("ofxMacamPs3Eye:: Using 'defaultSettingsHack'. For a faster initialization use initGrabber("+ofToString(w)+", "+ofToString(h)+", false) instead");
				// I had some problems with some default settings not being set
				// if the camera was in a wierd USB bus (eg. in a thunderbolt display)
				// So better to force them here.
				// The need for the sleep was empirical... setting it straight away was
				// causing very strange behaviour on the cameras
				ofSleepMillis(1500);
				setAutoGainAndShutter(true);
				setBrightness(0.5);
				setContrast(0.5);
				setGamma(0.5);
				setHue(0.5);
				setLed(true);
			}
			
			success = true;
		}
		
	}
	
	if (success) {
		isInited = true;
	}else {
		isInited = false;
	}
	frameIsNew = false;
	return success;
}
void ofxMacamPs3Eye::update(){
	// This logic should be improved...
	// It's not guaranteed the threads will be synced.
	// Would be better if there was some kind of double buffer mechanism on the delegate.
	// Or that update only schedule a pixel copy on the on the imageReady callback on the delegate.
	// Anyone?
	
	if([ofxMacamPs3EyeCast(ps3eye).driver imageBuffer]){
		if([ofxMacamPs3EyeCast(ps3eye) isFrameNew]){
			frameIsNew = true;
			pixels.setFromExternalPixels([ofxMacamPs3EyeCast(ps3eye).driver imageBuffer], getWidth(), getHeight(), 3);
			if (bUseTex) {
				tex.loadData(getPixels(), getWidth(), getHeight(), GL_RGB);
			}
		}
		else {
			frameIsNew = false;
		}
	}
}
bool ofxMacamPs3Eye::isFrameNew(){
	return frameIsNew;
}

unsigned char * ofxMacamPs3Eye::getPixels(){
	return pixels.getPixels();
}
ofPixels & ofxMacamPs3Eye::getPixelsRef(){
	return pixels;
}

void ofxMacamPs3Eye::close(){
	// I don't know for sure if the camera is just not closing properly,
	// or if the led can remain lit even after the camera was shutwon.
	// Anyway it bothers me, so here's a cheap trick to turn it of. :P
	setLed(false);
	

	[ofxMacamPs3EyeCast(ps3eye) shutdown]; /// <------------------- apparently this is not working :S
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
	if(isInited) initGrabber(getWidth(), getHeight());
}
int ofxMacamPs3Eye::getDesiredFrameRate(){
	return desiredFPS;
}
float ofxMacamPs3Eye::getRealFrameRate(){
	return [ofxMacamPs3EyeCast(ps3eye) realFps];
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

void ofxMacamPs3Eye::setBrightness(float v){
	
	[ofxMacamPs3EyeCast(ps3eye).driver setBrightness:ofMap(v, 0, 1, -0.5, 1.5)];
}
void ofxMacamPs3Eye::setContrast(float v){
	[ofxMacamPs3EyeCast(ps3eye).driver setContrast:ofMap(v, 0, 1, -0.5, 1.5)];
}
void ofxMacamPs3Eye::setGamma(float v){
	[ofxMacamPs3EyeCast(ps3eye).driver setGamma:ofMap(v, 0, 1, -0.5, 1.5)];
}
void ofxMacamPs3Eye::setHue(float v){
	[ofxMacamPs3EyeCast(ps3eye).driver setHue:ofMap(v, 0, 1, -0.5, 1.5)];
}
void ofxMacamPs3Eye::setGain(float v){
	if(!getAutoGainAndShutter()){
		[ofxMacamPs3EyeCast(ps3eye).driver setGain:v];
	}
	else{
		ofLogWarning("ofxMacamPs3Eye:: Can't set gain. Set setAutoGainAndShutter(false) first.");
	}
}
void ofxMacamPs3Eye::setShutter(float v){
	if(!getAutoGainAndShutter()){
		[ofxMacamPs3EyeCast(ps3eye).driver setShutter:v];
	}
	else{
		ofLogWarning("ofxMacamPs3Eye:: Can't set shutter. Set setAutoGainAndShutter(false) first.");
	}
}
void ofxMacamPs3Eye::setAutoGainAndShutter(bool v){
	autoGainAndShutter = v;
	[ofxMacamPs3EyeCast(ps3eye).driver setAutoGain:(BOOL)v];
}
void ofxMacamPs3Eye::setFlicker(int flickerType){
	[ofxMacamPs3EyeCast(ps3eye).driver setFlicker:(FlickerType)flickerType];
}
void ofxMacamPs3Eye::setLed(bool v){
	[ofxMacamPs3EyeCast(ps3eye).driver setLed:v];
}


float ofxMacamPs3Eye::getBrightness(){
	return ofMap([ofxMacamPs3EyeCast(ps3eye).driver brightness], -0.5, 1.5, 0, 1);
}
float ofxMacamPs3Eye::getContrast(){
	return ofMap([ofxMacamPs3EyeCast(ps3eye).driver contrast], -0.5, 1.5, 0, 1);
}
float ofxMacamPs3Eye::getGamma(){
	return ofMap([ofxMacamPs3EyeCast(ps3eye).driver gamma], -0.5, 1.5, 0, 1);
}
float ofxMacamPs3Eye::getHue(){
	return ofMap([ofxMacamPs3EyeCast(ps3eye).driver hue], -0.5, 1.5, 0, 1);
}	
float ofxMacamPs3Eye::getGain(){
	return [ofxMacamPs3EyeCast(ps3eye).driver gain];
}	
float ofxMacamPs3Eye::getShutter(){
	return [ofxMacamPs3EyeCast(ps3eye).driver shutter];
}
bool ofxMacamPs3Eye::getAutoGainAndShutter(){
	return autoGainAndShutter;
}
