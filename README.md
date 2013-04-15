#ofxMacamPs3Eye
Fully featured and easy to use OpenFrameworks addon for using the PS3Eye camera **on a Mac**. The addon uses a stripped down version of Macam, specially tweaked for the PS3Eye and so let's you use multiple cameras, access high FPS, provides an API to control gain, shutter, brightness, contrast, etc and even let's you blink the LED! The addon implements the ofBaseVideoGrabber, so it will work out of the box exactly how is expected of the default ofVideoGrabber.

##Usage
Include the addon as you would do with any other (using OF's new project generator or by dragging and dropping the folder to Xcode) and use the ofxMacamPs3Eye object as you would do with the ofVideoGrabber. Then there are a few more goodies you can use.

#### The basics    
_in testApp.h:_

    #include "ofxMacamPs3Eye.h"    
    
    class testApp : public ofBaseApp{
	public:
		(...)
		ofxMacamPs3Eye ps3eye;
	};
	
_in testApp.cpp:_
   
    void testApp::setup(){
    	ps3eye.initGrabber(320, 240);
    }
    void testApp::update(){
    	ps3eye.update();
    }
    void testApp::draw(){
    	ps3eye.draw(0,0);
    }

####Controls
Some juicy controls to use…
    
    // Turn on/off auto gain and shutter
    ps3eye.setAutoGainAndShutter(false);    
    
    // All of these accept normalized (0..1) parameter's
    ps3eye.setGain(0.5);    /* only if auto gain and shutter is off */
	ps3eye.setShutter(1.0); /* only if auto gain and shutter is off */
	   
	ps3eye.setBrightness(0.6);
	ps3eye.setContrast(1.0);
	ps3eye.setHue(0.0);
	ps3eye.setGamma(0.5);
	
	// Different modes
	ps3eye.setFlicker(0); /* 0 - no flicker, 1 - 50hz, 2 - 60hz */
	ps3eye.setWhiteBalance(4); /* 1 - linear, 2 - indoor, 3 - outdoor, 4 - auto */
	
	// Turn the LED on/off
	ps3eye.setLed(false);
		
####Listing and using multiple cameras
While ````ps3eye.listDevices();```` works exactly like ofVideoGrabber (just print the camera list in the console), the static call to ````ofxMacamPs3Eye::getDeviceList()```` will provide you a vector with information of all devices for dynamic initialization.
    
    vector<ofxMacamPs3Eye*> cameras;
    vector<ofxMacamPs3EyeDeviceInfo*> deviceList = ofxMacamPs3Eye::getDeviceList();
	
	for (int i = 0; i < deviceList.size(); i++) {
		ofxMacamPs3Eye * camera = new ofxMacamPs3Eye();
		camera->setDeviceID(deviceList[i]->id);
		camera->setDesiredFrameRate(180);
		camera->initGrabber(320, 240);
		cameras.push_back(camera);
	}

####And more
You can also control the frame-rate and resolution, but for those it's maybe better if you poke with the source code yourself as there are still some sharper corners (and some broken stuff) and the implementation might change slightly in the future.
	

##Known issues
- Calling ````close()```` it's not really closing the camera properly, it won't jam it or anything in case you want to use the camera with another application later, but if you try to ````initGrabber()```` more than once during runtime (for example to change resolution), it will complain the camera is busy.

##Credits
The big credits of this addon should go for everyone who collaborated in the [Macam](http://http://webcam-osx.sourceforge.net/) project for this camera to actually work on a mac. But the idea of using the source of Macam itself (and not the quicktime component) in a addon is by Jason Van Cleave, who made [PS3EyeWindow](https://github.com/jvcleave/PS3EyeWindow). Credits also to Kyle McDonald and [his fork of the PS3EyeWindow](https://github.com/kylemcdonald/PS3EyeWindow) where I saw the idea of using a delegate to interface with the driver and camera central. I've basically just copied and pasted most of that code, gave it a lot of love to allow multiple cameras to work and shaped it as a proper ofxAddon.	

##Change log
- v2.1.0 - Removed osx 10.6 SDK dependencies
 