import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.Loader;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.URLRequest;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import com.greensock.TweenLite;
import com.greensock.easing.Linear;

private var rotator:Rotator;
private const tempMarksBG_Y:int = -955;
private const tempMarks_Y:int = -2269;
private const PIXELS_PER_DEGREE:uint = 60;
private const LARGE_PIXELS_PER_DEGREE:uint = 120;
private var TARGET_HOUSE_TEMP:uint = 18;
private var crossSpeed:Number = 0;
private var cross:Loader = new Loader();
private var timeCounter:uint = 0;
private var running:Boolean = false;
private var countingUp:Boolean = true;
private var husLevel:uint = 0;
private var changeTimer:Timer;
private var progressTimer:Timer;
private var changeInterval:uint = 5000;
private var afterBoilDownInterval:uint;
private var oldMouseY:Number;

private var sl:TheSliderClass;

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	sim.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y - 18*LARGE_PIXELS_PER_DEGREE;
	sim.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y - 18*PIXELS_PER_DEGREE;
	changeTimer = new Timer(5000,1);
	changeTimer.addEventListener(TimerEvent.TIMER, changeMovieOnTimer);
	progressTimer = new Timer(1000,0);
	progressTimer.addEventListener(TimerEvent.TIMER, progressHeatPumpOnTimer);
	
	var ventLoader:Loader = new Loader();
	ventLoader.load(new URLRequest("assets/pics/vent.png"));

	cross = new Loader();
	cross.load(new URLRequest("assets/pics/crossX.png"));
	
	var crossLoader2:Loader = new Loader();
	crossLoader2.load(new URLRequest("assets/pics/crossBG.png"));
	crossOverlay.addChild(crossLoader2);
	
	crossOverlay.addChild(cross);
	ventOverlay.addChild(ventLoader);
	rotator = new Rotator(cross, new Point(49,49));
	this.addEventListener(Event.ENTER_FRAME, enterFrame);

	sl = new TheSliderClass();
	sl.theText.text = "0";
	sliderContainer.addChild(sl);

	sliderContainer.addEventListener(MouseEvent.MOUSE_DOWN, sliderDown);
	sliderContainer.addEventListener(MouseEvent.MOUSE_UP, sliderUp);
}

private function sliderDown(event:MouseEvent):void {
	sliderContainer.startDrag(false,new Rectangle(0,1,0,257));
}

private function sliderDrag(event:MouseEvent):void {
	sliderContainer.y += event.localY - oldMouseY;
	oldMouseY = event.localY;
}

private function setTempAlpha(al:Number):void {
	sim.slider.temp1.alpha = sim.slider.temp2.alpha = sim.slider.temp3.alpha = sim.slider.temp4.alpha = 0;
	
	switch (al) {
		case 1:
			sim.slider.temp1.alpha = 1;
			break;
		case 2:
			sim.slider.temp2.alpha = 1;
			break;
		case 3:
			sim.slider.temp3.alpha = 1;
			break;
		case 4:
			sim.slider.temp4.alpha = 1;
			break;
	}
}

private function sliderUp(event:MouseEvent):void {
	sliderContainer.stopDrag();
	sliderContainer.removeEventListener(MouseEvent.MOUSE_MOVE, sliderDrag);

	if(sliderContainer.y < 50) {
		TweenLite.to(sliderContainer, 0.2, {y: 0});
		sl.theText.text = "15";
		crossSpeed = 5;
		setTempAlpha(1);
	}
	else if(sliderContainer.y >= 50 && sliderContainer.y < 130) {
		TweenLite.to(sliderContainer, 0.2, {y: 82});
		sl.theText.text = "8";
		crossSpeed = -5;
		setTempAlpha(2);
	}
	else if(sliderContainer.y >= 130 && sliderContainer.y < 220) {
		TweenLite.to(sliderContainer, 0.2, {y: 167});
		sl.theText.text = "0";
		crossSpeed = -10;
		setTempAlpha(3);
	}
	else if(sliderContainer.y >= 220) {
		TweenLite.to(sliderContainer, 0.2, {y: 250});
		sl.theText.text = "-5";
		crossSpeed = -15;
		setTempAlpha(4);
	}
}

// When Start or Stop is clicked, set up the state to begin heating up or cooling down
private function clickStartStop(event:MouseEvent):void {
	if(!running) {
		running=true;
		countingUp = true;
		videoPlayer.source="assets/vids/boiling_up_v001.mov";
		videoPlayer2.source = "assets/vids/boiling_loop_v001.mov"
		videoPlayer.visible = true;
		videoPlayer.play();
		startStopButton.label = "Stop";
		progressTimer.reset();
		progressTimer.start();
		changeTimer.start();
	}
	else {
		countingUp = false;
		startStopButton.enabled = false;
		videoPlayer.source="assets/vids/boiling_down_v001.mov";
		videoPlayer.visible=true;
		videoPlayer.play();
		videoPlayer2.stop();
		videoPlayer2.visible=false;
		afterBoilDownInterval = setInterval(afterBoilDown, 2000);
	}
}

// After allowing enough time for the boil down movie to play, reset the states ready to start over again
private function afterBoilDown():void {
	videoPlayer.stop();
	videoPlayer.visible = false;
	clearInterval(afterBoilDownInterval);
	startStopButton.enabled = true;
	startStopButton.label = "Start";
	startStopButton.enabled = true;
	running = false;
}

protected function changeMovieOnTimer(event:TimerEvent):void {
	changeMovie();
}

protected function progressHeatPumpOnTimer(event:TimerEvent):void {
	progressHeatPump();
}

private function enterFrame(event:Event):void {
	rotator.rotation += crossSpeed;
}

// Update the animation to show the new temperature inside, and move the tag
protected function progressHeatPump():void {
	if(timeCounter < TARGET_HOUSE_TEMP && countingUp) {
		timeCounter+=1;
//		sim.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE;
//		sim.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE;
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, 1, {y: tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, 1, {y: tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE, ease:Linear.easeNone});
	}
	else if(timeCounter > 0 && !countingUp) {
		timeCounter-=1;
//		sim.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE;
//		sim.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE;
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, 1, {y: tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, 1, {y: tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE, ease:Linear.easeNone});
	}
}

// At present, switches from the boil up movie to the loop movie
protected function changeMovie():void {
	changeTimer.reset();
	if(videoPlayer.visible) {
		videoPlayer2.visible=true;
		videoPlayer2.play();
		videoPlayer.stop();
		videoPlayer.visible=false;
	}
	else {
		videoPlayer.visible=true;
		videoPlayer.play();
		videoPlayer2.stop();
		videoPlayer2.visible=false;
	}
}