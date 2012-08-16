#pragma once

#include "ofMain.h"

#define ofxMacamPs3EyeCast(x) ((PS3EyeWindowAppDelegate*)x)

class ofxMacamPs3Eye : public ofBaseVideoGrabber, public ofBaseVideoDraws {
public:
	ofxMacamPs3Eye();
	~ofxMacamPs3Eye();
	
	void listDevices();		
	bool initGrabber(int w, int h);
	void update();
	bool isFrameNew();
	
	void setDeviceID(int _deviceID);
	void setDesiredFrameRate(int framerate);
	
	unsigned char * getPixels();
	ofPixels & getPixelsRef();
	
	void close();	
	
	float getHeight();
	float getWidth();
	
	void draw(float x, float y, float w, float h);
	void draw(float x, float y){
		draw(x, y, getWidth(), getHeight());
	}
	void draw(const ofPoint & point) {
		draw(point.x, point.y);
	}
	void draw(const ofRectangle & rect) {
		draw(rect.x, rect.y, rect.width, rect.height);
	}
	void draw(const ofPoint & point, float w, float h) {
		draw(point.x, point.y, w, h);
	}
	
	void setAnchorPercent(float xPct, float yPct);
	void setAnchorPoint(float x, float y);
	void resetAnchor();
	
	ofTexture & getTextureReference();
	void setUseTexture(bool bUseTex);

protected:
	int deviceID;
	int desiredFPS;
	bool inited;
	
	bool bUseTex;
	ofTexture tex;
	
	void* ps3eye;
	ofPixels pixels;
		
};