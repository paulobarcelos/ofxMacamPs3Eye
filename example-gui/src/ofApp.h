#pragma once

#include "ofMain.h"
#include "ofxGui.h"
#include "ofxMacamPs3Eye.h"

class ofApp : public ofBaseApp{

	public:
    void setup();
	void update();
	void draw();
	
	void onAutoGainAndShutterChange(bool & value);
	void onGainChange(float & value);
	void onShutterChange(float & value);
	void onGammaChange(float & value);
	void onBrightnessChange(float & value);
	void onContrastChange(float & value);
	void onHueChange(float & value);
	void onLedChange(bool & value);
	void onFlickerChange(int & value);
	void onWhiteBalanceChange(int & value);
	
	ofxPanel gui;
	ofxMacamPs3Eye ps3eye;
		
};
