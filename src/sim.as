import com.greensock.TweenLite;
import com.greensock.easing.Linear;

import fl.motion.AdjustColor;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.Loader;
import flash.display.MovieClip;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.filters.ColorMatrixFilter;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.URLRequest;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import mx.geom.RoundedRectangle;

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
private var changeInterval:uint = 5000;
private var afterBoilDownInterval:uint;
private var afterBoilUpInterval:uint;
private var oldMouseY:Number;
private var currentTempColour:uint = 0x97D4F1;
private var currentOutdoorTemp:int = 0;
private var previousTempColour:uint = 0x97D4F1;
private var movingGrad:MovingGradient;
private var sl:TheSliderClass;
private var _simLevel:uint;
private var color:AdjustColor = new AdjustColor();
private var filter:ColorMatrixFilter;
private var infoBubble:InfoBubble;
private var bubbleLocation:Point = new Point(0,0);

public const cA:uint = 0xF59739;
public const cB:uint = 0xFECC16;
public const cC:uint = 0x97D4F1;
public const cD:uint = 0x2D99CC;

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	sim.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y - 18*LARGE_PIXELS_PER_DEGREE;
	sim.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y - 18*PIXELS_PER_DEGREE;
	
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
	
	sl = new TheSliderClass();
	sl.theText.text = "0";
	sliderContainer.addChild(sl);
	
	movingGrad = new MovingGradient(600, 400);
	movingGrad.x = 50;
	movingGrad.y = -50;
	sim.bitmapBox.addChild(movingGrad);
	
	color.brightness = 0;
	color.contrast = 0;
	color.hue = 0;
	color.saturation = 0;
	
	setStartStopEvents();
	setHeatPumpOverlayEvents();
	
	// Should be called externally to control which simulation is being displayed
	setSimulationLevel(2);
}

private function mouseOverButton(event:MouseEvent):void {
	Mouse.cursor = "hand";
	color.brightness = -50;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStart.filters = [filter];
	startStopButton.buttonStop.filters = [filter];
}

private function mouseOutButton(event:MouseEvent):void {
	Mouse.cursor = "arrow";
	color.brightness = 5;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStart.filters = [filter];
	startStopButton.buttonStop.filters = [filter];
}

private function clickDownStart(event:MouseEvent):void {
	color.brightness = -75;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStart.filters = [filter];
}

private function clickDownStop(event:MouseEvent):void {
	color.brightness = -75;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStop.filters = [filter];
}

private function clickUpStop(event:MouseEvent):void {
	color.brightness = 0;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStart.filters = [filter];
	startStopButton.buttonStop.visible = false;
	startStopButton.buttonStart.visible = true;
}

private function clickUpStart(event:MouseEvent):void {
	color.brightness = 0;
	filter = new ColorMatrixFilter(color.CalculateFinalFlatArray());
	startStopButton.buttonStart.filters = [filter];
	startStopButton.buttonStop.visible = true;
	startStopButton.buttonStart.visible = false;
}
public function setStartStopEvents():void {
	startStopButton.buttonStart.addEventListener(MouseEvent.ROLL_OVER, mouseOverButton);
	startStopButton.buttonStop.addEventListener(MouseEvent.ROLL_OVER, mouseOverButton);
	startStopButton.buttonStart.addEventListener(MouseEvent.ROLL_OUT, mouseOutButton);
	startStopButton.buttonStop.addEventListener(MouseEvent.ROLL_OUT, mouseOutButton);
	startStopButton.buttonStart.addEventListener(MouseEvent.MOUSE_DOWN, clickDownStart);
	startStopButton.buttonStop.addEventListener(MouseEvent.MOUSE_DOWN, clickDownStop);
	startStopButton.buttonStart.addEventListener(MouseEvent.MOUSE_UP, clickUpStart);
	startStopButton.buttonStop.addEventListener(MouseEvent.MOUSE_UP, clickUpStop);
}

public function setHeatPumpOverlayEvents():void {
	infoBubble = new InfoBubble();
	infoBubble.visible = false;
	hpOverlay.addChild(infoBubble);
	hpOverlay.one.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.one.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.two.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.two.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.three.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.three.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.four.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.four.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.five.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.five.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.six.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.six.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.seven.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.seven.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
	hpOverlay.eight.addEventListener(MouseEvent.MOUSE_MOVE, showBubble);
	hpOverlay.eight.addEventListener(MouseEvent.MOUSE_OUT, hideBubble);
}

public function showBubble(event:MouseEvent):void {
	var name:String = (event.target as MovieClip).name;
	infoBubble.visible = true;
	switch(name) {
		case "one":
			infoBubble.setInfoText("Crank");
			break;
		case "two":
			infoBubble.setInfoText("P: " + getPressure("coolTank") + 'bar\n' + "T: " + (heatpumpRunning ? String(currentOutdoorTemp + 3) : String(currentOutdoorTemp)) + 'º');
			break;
		case "three":
			infoBubble.setInfoText("P: " + getPressure("coolTank") + 'bar\n' + "T: " + String(currentOutdoorTemp) + 'º');
			break;
		case "four":
			infoBubble.setInfoText("P: " + getPressure("coolTank") + 'bar\n' + "T: " + (heatpumpRunning ? String(currentOutdoorTemp - 3) : String(currentOutdoorTemp)) + 'º');
			break;
		case "five":
			infoBubble.setInfoText("Release Valve");
			break;
		case "six":
			infoBubble.setInfoText("P: " + getPressure("hotTank") + 'bar\n' + "T: " + (heatpumpRunning ? String(36-currentOutdoorTemp-3) : String(currentOutdoorTemp)) + 'º');
			break;
		case "seven":
			infoBubble.setInfoText("P: " + getPressure("hotTank") + 'bar\n' + "T: " + (heatpumpRunning ? String(36 - currentOutdoorTemp) : String(currentOutdoorTemp)) + 'º');
			break;
		case "eight":
			infoBubble.setInfoText("P: " + getPressure("hotTank") + 'bar\n' + "T: " + (heatpumpRunning ? String(36 - currentOutdoorTemp + 3) : String(currentOutdoorTemp)) + 'º');
			break;
	}
	this.addEventListener(MouseEvent.MOUSE_MOVE, bubbleMove);
}

public function bubbleMove(event:MouseEvent):void {
	bubbleLocation.x = event.stageX;
	bubbleLocation.y = event.stageY;
	bubbleLocation = hpOverlay.globalToLocal(bubbleLocation);
	infoBubble.x = bubbleLocation.x + 10;
	infoBubble.y = bubbleLocation.y + 10;
}

private function getPressure(tank:String):String {
	if(tank == "coolTank") {
		if(currentOutdoorTemp == -5)
			return "5.76";
		else if(currentOutdoorTemp == 0)
			return "6.97";
		else if(currentOutdoorTemp == 8)
			return "9.22";
		else if(currentOutdoorTemp == 15)
			return "11.56";
	}
	else if(tank == "hotTank") {
		if(currentOutdoorTemp == -5)
			return "23.78";
		else if(currentOutdoorTemp == 0)
			return "6.97";
		else if(currentOutdoorTemp == 8)
			return "9.22";
		else if(currentOutdoorTemp == 15)
			return "11.56";
	}
	return "";
}

public function hideBubble(event:MouseEvent):void {
	infoBubble.visible = false;
	this.removeEventListener(MouseEvent.MOUSE_MOVE, bubbleMove);
}

public function setSimulationLevel(simLevel:uint):void {
	_simLevel = simLevel;
	if(simLevel == 1) {
		sim.hp.alpha = 0.1;
		spriteGroup.alpha = 0.1;
		startStopButton.visible = false;
		spriteGroup.visible = false;
		arrowPlayer.source="assets/flash/ARROW_n1.swf";
		hpOverlay.visible = false;
	}
	else if(simLevel == 2) {
		sim.hp.alpha = 1;
		spriteGroup.visible = true;
		spriteGroup.alpha = 1;
		startStopButton.visible = true;
		arrowPlayer.source="assets/flash/ARROW_n2.swf";
		hpOverlay.visible = true;
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
	slide.temp1.alpha = slide.temp2.alpha = slide.temp3.alpha = slide.temp4.alpha = 0;
	
	if(sliderContainer.y < 50) {
		currentOutdoorTemp = 15;
		TweenLite.to(sliderContainer, 0.2, {y: 0});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -1;
		slide.temp1.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cA;
	}
	else if(sliderContainer.y >= 50 && sliderContainer.y < 130) {
		currentOutdoorTemp = 8;
		TweenLite.to(sliderContainer, 0.2, {y: 82});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -5;
		slide.temp2.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cB;
	}
	else if(sliderContainer.y >= 130 && sliderContainer.y < 220) {
		currentOutdoorTemp = 0;
		TweenLite.to(sliderContainer, 0.2, {y: 167});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -10;
		slide.temp3.alpha = 1;
		previousTempColour = currentTempColour;
		currentTempColour = cC;
	}
	else if(sliderContainer.y >= 220) {
		currentOutdoorTemp = -5;
		TweenLite.to(sliderContainer, 0.2, {y: 250});
		sl.theText.text = String(currentOutdoorTemp);
		crossSpeed = -15;
		slide.temp4.alpha = 1;
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
		arrowPlayer.source="assets/flash/ARROW_n3.swf";
		heatpumpRunning=true;
		this.addEventListener(Event.ENTER_FRAME, enterFrame);
		countingUp = true;
		videoPlayer.source="assets/vids/boiling_up_v002.flv";
		videoPlayer2.source = "assets/vids/boiling_loop_v002.flv"
		videoPlayer.visible = true;
		videoPlayer.play();
		moveIndoorsToHeatPumpTemp();
		afterBoilUpInterval = setInterval(afterBoilUp, 5000);
	}
	else {
		clearInterval(afterBoilUpInterval);
		countingUp = false;
		startStopButton.enabled = false;
		videoPlayer.source="assets/vids/boiling_down_v002.flv";
		videoPlayer.visible=true;
		videoPlayer.play();
		videoPlayer2.visible=false;
		videoPlayer2.stop();
		afterBoilDownInterval = setInterval(afterBoilDown, 2000);
	}
}

// At present, switches from the boil up movie to the loop movie
private function afterBoilUp():void {
	clearInterval(afterBoilUpInterval);
	videoPlayer2.visible=true;
	videoPlayer2.play();
	videoPlayer.stop();
	videoPlayer.visible=false;
}

// After allowing enough time for the boil down movie to play, reset the states ready to start over again
private function afterBoilDown():void {
	clearInterval(afterBoilDownInterval);
	arrowPlayer.source="assets/flash/ARROW_n2.swf";
	videoPlayer.stop();
	videoPlayer2.stop();
	videoPlayer.visible = false;
	videoPlayer2.visible = false;
	startStopButton.enabled = true;
	startStopButton.enabled = true;
	heatpumpRunning = false;
	this.removeEventListener(Event.ENTER_FRAME, enterFrame);
	moveIndoorsToOutdoorTemp();
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

