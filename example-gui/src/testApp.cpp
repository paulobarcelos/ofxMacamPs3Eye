#include "testApp.h"

//--------------------------------------------------------------
void testApp::setup(){
	ofSetVerticalSync(true);
	ofSetWindowShape(900, 480);
	
	ps3eye.initGrabber(640, 480);
	
	gui.setup("PS3Eye");
	gui.setPosition(660,20);
	
	ofxToggle * autoGainAndShutter = new ofxToggle("Auto Gain & Shutter", false);
	autoGainAndShutter->addListener(this, &testApp::onAutoGainAndShutterChange);
	gui.add(autoGainAndShutter);
	
	ofxFloatSlider * gain = new ofxFloatSlider("Gain", 0.5, 0.0, 1.0);
	gain->addListener(this, &testApp::onGainChange);
	gui.add(gain);
	
	ofxFloatSlider * shutter = new ofxFloatSlider("Shutter", 0.5, 0.0, 1.0);
	shutter->addListener(this, &testApp::onShutterChange);
	gui.add(shutter);
	
	ofxFloatSlider * gamma = new ofxFloatSlider("Gamma", 0.5, 0.0, 1.0);
	gamma->addListener(this, &testApp::onGammaChange);
	gui.add(gamma);
	
	ofxFloatSlider * brightness = new ofxFloatSlider("Brightness", 0.5, 0.0, 1.0);
	brightness->addListener(this, &testApp::onBrightnessChange);
	gui.add(brightness);
	
	ofxFloatSlider * contrast = new ofxFloatSlider("Contrast", 0.5, 0.0, 1.0);
	contrast->addListener(this, &testApp::onContrastChange);
	gui.add(contrast);
	
	ofxFloatSlider * hue = new ofxFloatSlider("Hue", 0.5, 0.0, 1.0);
	hue->addListener(this, &testApp::onHueChange);
	gui.add(hue);
	
	ofxIntSlider * flicker = new ofxIntSlider("Flicker Type", 0, 0, 2);
	flicker->addListener(this, &testApp::onFlickerChange);
	gui.add(flicker);
	
	ofxIntSlider * wb = new ofxIntSlider("White Balance Mode", 4, 1, 4);
	wb->addListener(this, &testApp::onFlickerChange);
	gui.add(wb);
	
	ofxToggle * led = new ofxToggle("LED", true);
	led->addListener(this, &testApp::onLedChange);
	gui.add(led);
	
	// Load initial values
	onAutoGainAndShutterChange(gui.getToggle("Auto Gain & Shutter"));
	onGainChange(gui.getFloatSlider("Gain"));
	onShutterChange(gui.getFloatSlider("Shutter"));
	onGammaChange(gui.getFloatSlider("Gamma"));
	onBrightnessChange(gui.getFloatSlider("Brightness"));
	onContrastChange(gui.getFloatSlider("Contrast"));
	onHueChange(gui.getFloatSlider("Hue"));
	onLedChange(gui.getToggle("LED"));
	onFlickerChange(gui.getIntSlider("Flicker"));
	onWhiteBalanceChange(gui.getIntSlider("White Balance"));
	
	
}

//--------------------------------------------------------------
void testApp::update(){
	ps3eye.update();
}

//--------------------------------------------------------------
void testApp::draw(){
	ps3eye.draw(0, 0);
	ofDrawBitmapString("FPS "+ofToString(ps3eye.getRealFrameRate()), 20, 20);
	gui.draw();
}

//--------------------------------------------------------------
void testApp::onAutoGainAndShutterChange(bool & value){
	ps3eye.setAutoGainAndShutter(value);
}

//--------------------------------------------------------------
void testApp::onGainChange(float & value){
	// Only set if auto gain & shutter is off
	if(!gui.getToggle("Auto Gain & Shutter")){
		ps3eye.setGain(value);
	}
}

//--------------------------------------------------------------
void testApp::onShutterChange(float & value){
	// Only set if auto gain & shutter is off
	if(!gui.getToggle("Auto Gain & Shutter")){
		ps3eye.setShutter(value);
	}
}

//--------------------------------------------------------------
void testApp::onGammaChange(float & value){
	ps3eye.setGamma(value);
}

//--------------------------------------------------------------
void testApp::onBrightnessChange(float & value){
	ps3eye.setBrightness(value);
}

//--------------------------------------------------------------
void testApp::onContrastChange(float & value){
	ps3eye.setContrast(value);
}

//--------------------------------------------------------------
void testApp::onHueChange(float & value){
	ps3eye.setHue(value);
}	

//--------------------------------------------------------------
void testApp::onLedChange(bool & value){
	ps3eye.setLed(value);
}

//--------------------------------------------------------------
void testApp::onFlickerChange(int & value){
	ps3eye.setFlicker(value);
}

//--------------------------------------------------------------
void testApp::onWhiteBalanceChange(int & value){
	ps3eye.setWhiteBalance(value);
}