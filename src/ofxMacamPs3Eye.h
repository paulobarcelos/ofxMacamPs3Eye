#pragma once

#include "ofMain.h"

#define ofxMacamPs3EyeCast(x) ((PS3EyeWindowAppDelegate*)x)

struct ofxMacamPs3EyeDeviceInfo{
	int id;
    unsigned long locationID;
	char name[255];
};

class ofxMacamPs3Eye : public ofBaseVideoGrabber, public ofBaseVideoDraws {
public:
	ofxMacamPs3Eye();
	~ofxMacamPs3Eye();
	
	// Updated to match virtual method signature
	vector<ofVideoDevice> listDevices();
	static vector<ofxMacamPs3EyeDeviceInfo*> getDeviceList(bool verbose = false);
	bool initGrabber(int w, int h){ return initGrabber(w, h, true); };
	bool initGrabber(int w, int h, bool defaultSettingsHack); // Read on the implementation what this hack is about...
	void update();
	bool isFrameNew();
	
	void setDeviceID(int _deviceID);
	void setDesiredFrameRate(int framerate);
	int getDesiredFrameRate();
	
    bool setPixelFormat(ofPixelFormat pixelFormat);
    ofPixelFormat getPixelFormat();
    void videoSettings();
    void setVerbose(bool bTalkToMe);
	
	float getRealFrameRate();
	
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
	
	// Juicy controls!
	void setAutoGainAndShutter(bool v);
	
	/* normalized */
	void setBrightness(float v);
	void setContrast(float v);
	void setGamma(float v);
	void setHue(float v);		
	void setGain(float v);	// <-- will only work if setAutoGainAndShutter(false)
	void setShutter(float v); // <-- will only work if setAutoGainAndShutter(false)
	
	void setLed(bool v);
	void setFlicker(int v); // 0 - no flicker, 1 - 50hz, 2 - 60hz
	void setWhiteBalance(int v);// 1 - linear, 2 - indoor, 3 - outdoor, 4 - auto
	
	float getBrightness();
	float getContrast();
	float getGamma();
	float getHue();		
	float getGain();	
	float getShutter();	
	bool getAutoGainAndShutter();
	bool getLed();
	int getFlicker();
	int getWhiteBalance();

protected:
	int deviceID;
	int desiredFPS;
	bool inited;
	bool frameIsNew;
	
	bool isInited;
	
	bool autoGainAndShutter;
	
	bool bUseTex;
	ofTexture tex;
		
	void* ps3eye;
	ofPixels pixels;
	
	void exit(ofEventArgs & args){close();};
		
};