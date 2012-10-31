import com.greensock.TweenLite;
import com.greensock.easing.Linear;

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

private const tempMarksBG_Y:int = -955;
private const tempMarks_Y:int = -2269;
private const PIXELS_PER_DEGREE:uint = 60;
private const LARGE_PIXELS_PER_DEGREE:uint = 120;
private const OUTDOOR_TRANSITION_DURATION:uint = 4;
private const INDOOR_TRANSITION_DURATION:uint = 10;

private var indoorTweener1:TweenLite;
private var indoorTweener2:TweenLite;
private var rotator:Rotator;
private var TARGET_HOUSE_TEMP:uint = 18;
private var crossSpeed:Number = -10;
private var cross:Loader = new Loader();
private var timeCounter:uint = 0;
private var heatpumpRunning:Boolean = false;
private var countingUp:Boolean = true;
private var husLevel:uint = 0;
private var changeTimer:Timer;
private var changeInterval:uint = 5000;
private var afterBoilDownInterval:uint;
private var oldMouseY:Number;
private var currentTempColour:uint = 0x97D4F1;
private var currentOutdoorTemp:int = 0;
private var previousTempColour:uint = 0x97D4F1;
private var movingGrad:MovingGradient;
private var sl:TheSliderClass;
private var _simLevel:uint;

public const cA:uint = 0xF59739;
public const cB:uint = 0xFECC16;
public const cC:uint = 0x97D4F1;
public const cD:uint = 0x2D99CC;

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	sim.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y - 18*LARGE_PIXELS_PER_DEGREE;
	sim.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y - 18*PIXELS_PER_DEGREE;
	changeTimer = new Timer(5000,1);
	changeTimer.addEventListener(TimerEvent.TIMER, changeMovieOnTimer);
	
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

	sl = new TheSliderClass();
	sl.theText.text = "0";
	sliderContainer.addChild(sl);

	sliderContainer.addEventListener(MouseEvent.MOUSE_DOWN, sliderDown);
	sliderContainer.addEventListener(MouseEvent.MOUSE_UP, sliderUp);
	sliderContainer.addEventListener(MouseEvent.MOUSE_OVER, showHandCursor);
	sliderContainer.addEventListener(MouseEvent.MOUSE_OUT, hideHandCursor);
	
	movingGrad = new MovingGradient(600, 400);
	gradientContainer.addChild(movingGrad);
	gradientContainer.alpha = 0.5;
	
	// Should be called externally to control which simulation is being displayed
	setSimulationLevel(2);
}

public function setSimulationLevel(simLevel:uint):void {
	_simLevel = simLevel;
	if(simLevel == 1) {
		sim.hp.alpha = 0.1;
		spriteGroup.alpha = 0.1;
		startStopButton.visible = false;
	}
	else if(simLevel == 2) {
		sim.hp.alpha = 1;
		spriteGroup.alpha = 1;
		startStopButton.visible = true;
	}
}

private function showHandCursor(event:MouseEvent):void {
	Mouse.cursor = "hand";
}
private function hideHandCursor(event:MouseEvent):void {
	Mouse.cursor = "arrow";
}
private function sliderDown(event:MouseEvent):void {
	sliderContainer.startDrag(false,new Rectangle(0,1,0,257));
}

private function sliderDrag(event:MouseEvent):void {
	sliderContainer.y += event.localY - oldMouseY;
	oldMouseY = event.localY;
}

private function sliderUp(event:MouseEvent):void {
	sliderContainer.stopDrag();
	sliderContainer.removeEventListener(MouseEvent.MOUSE_MOVE, sliderDrag);
	sim.slider.temp1.alpha = sim.slider.temp2.alpha = sim.slider.temp3.alpha = sim.slider.temp4.alpha = 0;
	
	if(sliderContainer.y < 50) {
		currentOutdoorTemp = 15;
		TweenLite.to(sliderContainer, 0.2, {y: 0});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -1;
		sim.slider.temp1.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cA;
	}
	else if(sliderContainer.y >= 50 && sliderContainer.y < 130) {
		currentOutdoorTemp = 8;
		TweenLite.to(sliderContainer, 0.2, {y: 82});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -5;
		sim.slider.temp2.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cB;
	}
	else if(sliderContainer.y >= 130 && sliderContainer.y < 220) {
		currentOutdoorTemp = 0;
		TweenLite.to(sliderContainer, 0.2, {y: 167});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -10;
		sim.slider.temp3.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cC;
	}
	else if(sliderContainer.y >= 220) {
		currentOutdoorTemp = -5;
		TweenLite.to(sliderContainer, 0.2, {y: 250});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -15;
		sim.slider.temp4.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cD;
	}
	if(previousTempColour != currentTempColour) {
		movingGrad.transitionDuration = OUTDOOR_TRANSITION_DURATION;
		movingGrad.colourChange(previousTempColour, currentTempColour);
		if(!heatpumpRunning) {
			moveIndoorsToOutdoorTemp();
		}
	}
}

// When Start or Stop is clicked, set up the state to begin heating up or cooling down
private function clickStartStop(event:MouseEvent):void {
	if(!heatpumpRunning) {
		heatpumpRunning=true;
		this.addEventListener(Event.ENTER_FRAME, enterFrame);
		countingUp = true;
		videoPlayer.source="assets/vids/boiling_up_v002.flv";
		videoPlayer2.source = "assets/vids/boiling_loop_v002.flv"
		videoPlayer.visible = true;
		videoPlayer.play();
		startStopButton.label = "Stop";
		moveIndoorsToHeatPumpTemp();
		changeTimer.start();
	}
	else {
		countingUp = false;
		startStopButton.enabled = false;
		videoPlayer.source="assets/vids/boiling_down_v002.flv";
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
	heatpumpRunning = false;
	this.removeEventListener(Event.ENTER_FRAME, enterFrame);
	moveIndoorsToOutdoorTemp();
}

private function changeMovieOnTimer(event:TimerEvent):void {
	changeMovie();
}

private function enterFrame(event:Event):void {
	rotator.rotation += crossSpeed;
}

/*
private function progressHeatPumpOnTimer(event:TimerEvent):void {
	progressHeatPump();
}

// Update the animation to show the new temperature inside, and move the tag
private function progressHeatPump():void {
	if(timeCounter < TARGET_HOUSE_TEMP && countingUp) {
		timeCounter+=1;
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, 1, {y: tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, 1, {y: tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE, ease:Linear.easeNone});
	}
	else if(timeCounter > 0 && !countingUp) {
		timeCounter-=1;
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, 1, {y: tempMarks_Y + timeCounter*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, 1, {y: tempMarksBG_Y + timeCounter*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE, ease:Linear.easeNone});
	}
}
*/

// At present, switches from the boil up movie to the loop movie
private function changeMovie():void {
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
private function moveIndoorsToHeatPumpTemp():void {
	// Move at one degree per second, towards 18 degree temp
	var duration:Number = -(sim.TEMPERATURE.left_temp_mc.leftMarks.y - tempMarks_Y)/LARGE_PIXELS_PER_DEGREE;
	if(indoorTweener1 != null && indoorTweener2 != null) {
		indoorTweener1.kill();
		indoorTweener2.kill();
	}
	indoorTweener1 = TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, duration, {y: tempMarks_Y, ease:Linear.easeNone});
	indoorTweener2 = TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, duration, {y: tempMarksBG_Y, ease:Linear.easeNone});
}
private function moveIndoorsToOutdoorTemp():void {
	// Move at one degree per second, towards current outside temp
	var currentTemp:Number = 18 + (sim.TEMPERATURE.left_temp_mc.leftMarks.y - tempMarks_Y)/LARGE_PIXELS_PER_DEGREE;
	var duration:Number = Math.abs(currentTemp - currentOutdoorTemp);
	if(indoorTweener1 != null && indoorTweener2 != null) {
		indoorTweener1.kill();
		indoorTweener2.kill();
	}
	indoorTweener1 = TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarks, duration, {y: tempMarks_Y + currentOutdoorTemp*LARGE_PIXELS_PER_DEGREE - 18*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});
	indoorTweener2 = TweenLite.to(sim.TEMPERATURE.left_temp_mc.leftMarksBG, duration, {y: tempMarksBG_Y + currentOutdoorTemp*PIXELS_PER_DEGREE - 18*PIXELS_PER_DEGREE, ease:Linear.easeNone});
}