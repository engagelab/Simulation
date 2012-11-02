package
{
	// Part code taken from Zach Archer
	// http://blog.zacharcher.com/2007/10/13/understanding-colormatrixfilter/

	import com.greensock.*;
	import com.greensock.easing.*;
	import com.greensock.plugins.*;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.GradientType;
	import flash.display.Loader;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.net.URLRequest;
	import flash.utils.getTimer;
	
	import mx.core.INavigatorContent;
	
	// Creates a filled rectangle of certain colour type and allows gradual tweening to other colours 
	public class MovingGradient extends Sprite
	{
		private var changeSpeed:Number = 3;
		private var bmp:Bitmap;
		private var myLoader:Loader
		private var _width:int;
		private var _height:int;
		private var _transitionDuration:uint;
		
		public const cA:uint = 0xF59739;
		public const cB:uint = 0xFECC16;
		public const cC:uint = 0x97D4F1;
		public const cD:uint = 0x2D99CC;
		
		public function MovingGradient(w:Number, h:Number)
		{
			_width = w;
			_height = h;
			TweenPlugin.activate([ColorTransformPlugin]);

			var shp:Shape = new Shape();
			with( shp.graphics ) {
				beginFill(cC);
				drawRect( 0, 0, w, h );
				endFill();
			}

			// Draw the Shape inside some BitmapData.
			var bData:BitmapData = new BitmapData( w, h, false, 0x000000 );
			bData.draw( shp );
			
			// Create a Bitmap to display the BitmapData, and add it to the stage.
	//		bmp = new Bitmap( bData );
	//		addChild( bmp );
			
	//		var myMask:energywavemask = new energywavemask();
	//		addChild(myMask);
	//		bmp.mask = myMask;
			
			// this.scrollRect = new Rectangle(0,0, 600, 400);
			
			myLoader = new Loader();
			myLoader.load(new URLRequest("assets/pics/Blur.png"));
			myLoader.alpha = 0.5;
			addChild(myLoader);
		}
		
		// Public setter for transition duration
		public function set transitionDuration(td:uint):void {
			_transitionDuration = td;
		}
		
		// Choose which transition is appropriate
		public function colourChange( from:uint, to:uint) :void {
			if(from == cA) {
				if(to == cB)
					tweenAway(cB);
				else if(to == cC)
					tweenAway(cB, cC);
				else if(to == cD)
					tweenAway(cB, cC, cD);
			}
			else if(from == cB) {
				if(to == cA)
					tweenAway(cA);
				else if(to == cC)
					tweenAway(cC);
				else if(to == cD)
					tweenAway(cC, cD);
			}
			else if(from == cC) {
				if(to == cA)
					tweenAway(cB, cA);
				else if(to == cB)
					tweenAway(cB);
				else if(to == cD)
					tweenAway(cD);
			}
			else {
				if(to == cA)
					tweenAway(cC, cB, cA);
				else if(to == cB)
					tweenAway(cC, cB);
				else if(to == cC)
					tweenAway(cC);
			}
		}

		private function tweenAway(c1:uint, c2:uint=0, c3:uint=0):void {
			if(c1 != 0) {
				// Split the incoming color uint's into RGB values, ranging from 0..255
				var o1:Object = {
					r: (c1 & 0xff0000) >> 16,
					g: (c1 & 0x00ff00) >> 8,
					b: c1 & 0x0000ff
				};
				// Tween the colour transform of the bitmap
				TweenMax.to(
					myLoader,
					changeSpeed,
					{	colorTransform:
						{
							redMultiplier: 0,
							greenMultiplier: 0,
							blueMultiplier: 0,
							alphaMultiplier: 0.5,
							redOffset: o1.r,
							greenOffset: o1.g,
							blueOffset: o1.b,
							alphaOffset: 0
						},
						ease:Quad.easeOut,
						onComplete: function tweenAgain():void { tweenAway(c2, c3); }
					}
				);
			}
		}
	}
}