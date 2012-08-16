#include "testApp.h"

//--------------------------------------------------------------
void testApp::setup(){
	ofSetVerticalSync(true);
	
	cam1.setDeviceID(2);
	cam1.setDesiredFrameRate(180);
	cam1.initGrabber(320, 240);
	
	cam2.setDeviceID(3);
	cam2.setDesiredFrameRate(180);
	cam2.initGrabber(320, 240);
	
	cam3.setDeviceID(4);
	cam3.setDesiredFrameRate(180);
	cam3.initGrabber(320, 240);	
}

//--------------------------------------------------------------
void testApp::update(){
	cam1.update();
	cam2.update();
	cam3.update();
}

//--------------------------------------------------------------
void testApp::draw(){
	cam1.draw(0, 0);
	cam2.draw(320, 0);
	cam3.draw(640, 0);
}

//--------------------------------------------------------------
void testApp::keyPressed(int key){

}

//--------------------------------------------------------------
void testApp::keyReleased(int key){

}

//--------------------------------------------------------------
void testApp::mouseMoved(int x, int y){

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