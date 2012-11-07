package
{
	import flash.display.Sprite;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	import mx.geom.RoundedRectangle;
	
	public class InfoBubble extends Sprite
	{
		private var tfield:TextField = new TextField();
		[Embed(source="assets/ITCFranklinGothicStd-Demi.otf", fontName = "miracleFont", mimeType = "application/x-font", fontWeight="normal", fontStyle="normal", advancedAntiAliasing="true", embedAsCFF="false")]
		private var miracleFont : Class;
	
		public function InfoBubble()
		{
			super();
			
			var tformat:TextFormat = new TextFormat("miracleFont", 12, 0xFFFFFF, true, null, null, null, null);
			tfield.defaultTextFormat = tformat;
			tfield.selectable = false;
			this.addChild(tfield);
		}
		
		public function setInfoText(theText:String):void {
			tfield.htmlText = theText;
			tfield.x = 3;
			graphics.clear();
			graphics.beginFill(0x00FF00,0.75);
			graphics.drawRoundRect(0,0,tfield.textWidth+8,tfield.textHeight+6,5,5);
			graphics.endFill();
		}
	}
}