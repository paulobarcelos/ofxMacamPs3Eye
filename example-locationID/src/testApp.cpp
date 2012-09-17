#include "testApp.h"

/**
 
 PS3Eye location ID's on relation to USB ports (for tested computers):

 ----------------------------------------------------------
 MacMini Mid 2011
 
 A - 4195549184
 B - 4195483648
 C - 4245815296
 D - 4245880832
 
 [A  B  C  D]  Thunderbolt   HDMI   FW   Ethernet   Power
 /--------------------------------------------------------\
 |                                                         |
 |                                                         |
 |                                                         |
 |                             __                          |
 |                            /_/                          |
 |                        __  |  __                        |
 |                       /  \___/  \                       |
 |                      |          /                       |
 |                      |         |                        |
 |                      |          \                       |
 |                       \         /                       |
 |                        \__---__/                        |
 |                                                         |
 |                                                         |
 |                                                         |
 \_________________________________________________________/

**/

unsigned long LOCATION_ID = 4195549184; // Using port A (MacMini Mid 2011) for this example

//--------------------------------------------------------------
void testApp::setup(){
    ofSetVerticalSync(true);
    ofSetWindowShape(320, 240);
    ofBackground(0, 0, 0);
	

    pseye = NULL; 
    
    vector<ofxMacamPs3EyeDeviceInfo*> deviceList = ofxMacamPs3Eye::getDeviceList();
    
	for (int i = 0; i < deviceList.size(); i++) {
        if(deviceList[i]->locationID == LOCATION_ID){
            pseye = new ofxMacamPs3Eye();
            pseye->setDeviceID(deviceList[i]->id);
            pseye->setDesiredFrameRate(180);
            pseye->initGrabber(320, 240);
        }
	}
}

//--------------------------------------------------------------
void testApp::update(){
    if(pseye) pseye->update();
}

//--------------------------------------------------------------
void testApp::draw(){
    if(pseye) pseye->draw(0, 0);
    else ofDrawBitmapString("No PS3Eye found at "+ofToString(LOCATION_ID), 20,20);
}

//--------------------------------------------------------------
void testApp::keyPressed(int key){

}

//--------------------------------------------------------------
void testApp::keyReleased(int key){

}

//--------------------------------------------------------------
void testApp::mouseMoved(int x, int y ){

}

//--------------------------------------------------------------
void testApp::mouseDragged(int x, int y, int button){

}

//--------------------------------------------------------------
void testApp::mousePressed(int x, int y, int button){

}

//--------------------------------------------------------------
void testApp::mouseReleased(int x, int y, int button){

}

//--------------------------------------------------------------
void testApp::windowResized(int w, int h){

}

//--------------------------------------------------------------
void testApp::gotMessage(ofMessage msg){

}

//--------------------------------------------------------------
void testApp::dragEvent(ofDragInfo dragInfo){ 

}