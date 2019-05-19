/*
 * Written by JL95, Flash Crows, for PeroPeroSeduction animation .swf to .gif conversion
 * All rights reserved ©2019
 */
package ppsairuc {
	
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
    import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	
	import com.adobe.images.PNGEncoder;
	
	public class AiruC extends MovieClip {
		
		private var loader:Loader = new Loader();
		private var cardSwf:MovieClip = null;
		// Following vector contains only child clip with more than one frame
		private var cardSwfChildren:Vector.<MovieClip> = new Vector.<MovieClip>();
		
		public var cardPos:MovieClip;
		
		public var cardFilename:TextField;
		
		public var loadStatusText:TextField;
		public var frameCountText:TextField;
		public var frameGeneratingText:TextField;
		public var debugText:TextField;
		
		public var loadCardButton:MovieClip;
		public var parseCardButton:MovieClip;
		public var generateButton:MovieClip;
		public var outputLocationButton:MovieClip;
		
		private var cardFrameCount:uint = 0;
		
		private var renderFrameIndex:uint = 0;
		private var pngSource:BitmapData = null;
		private var fileStream:FileStream = new FileStream();
		
		private var outputDirectory:File = File.desktopDirectory;

		public function AiruC() {
			loadStatusText.text = "None";
			frameCountText.text = "None";
			frameGeneratingText.text = "None";
			
			// Default to initial
			outputLocationButton.gotoAndStop(0);
			outputDirectory = getOutputDirectory();
			
			outputLocationButton.addEventListener(MouseEvent.CLICK, onOutputDirectoryClicked);
			outputLocationButton.buttonMode = true;
			outputLocationButton.useHandCursor = true;
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private function isRendering():Boolean {
			return renderFrameIndex > 0;
		}
		
		private function onEnterFrame(e:Event) {
			
			if (isRendering()) {
				
				renderFrameToFile(cardSwf, renderFrameIndex);
			
				cardSwfChildren.forEach(stepChildGenerate);
				
				if (renderFrameIndex == cardFrameCount) {
					
					cardSwfChildren.forEach(cleanupChildGenerate);
					renderFrameIndex = 0;
					
					frameGeneratingText.text = "Done";
				}
				else {
					++renderFrameIndex;
					frameGeneratingText.text = renderFrameIndex.toString();
				}
				
				return;
			}
			
			var canLoadCard:Boolean = cardFilename.getRawText().length > 0;
			
			if (loadCardButton.buttonMode != canLoadCard) {
				
				if (canLoadCard) {
					loadCardButton.addEventListener(MouseEvent.CLICK, onLoadCardClicked);
				}
				else {
					loadCardButton.removeEventListener(MouseEvent.CLICK, onLoadCardClicked);
				}
				
				loadCardButton.buttonMode = canLoadCard;
				loadCardButton.useHandCursor = canLoadCard;
			}
		}
		
		private function addLoadCallbacks():void {
			loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadSecurityError);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadIOError);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
		}
		
		private function removeLoadCallbacks():void {
			loader.contentLoaderInfo.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadSecurityError);
			loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoadIOError);
			loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadComplete);
		}
		
		private function onLoadCardClicked(e:MouseEvent) {
			
			if (isRendering()) {
				return;
			}
			
			if (cardSwf != null) {
				removeChild(cardSwf);
				
				try {
					loader.unloadAndStop();
				} catch (e:Error) {
					trace("Some unload error occurred");
				}
			}
			
			disallowParse();
			
			var absoluteFilepath:String = outputDirectory.url + "\\" + cardFilename.text + ".swf";
			var newRequest:URLRequest = new URLRequest(absoluteFilepath);
			
			addLoadCallbacks();
			loader.load(newRequest);
			
			loadStatusText.text = "Loading";
			frameCountText.text = "None";
			frameGeneratingText.text = "None";
			
			debugText.text = "";
			debugText.selectable = false;
		}
		
		private function onLoadSecurityError(e:SecurityErrorEvent):void {
			
			loadStatusText.text = "Error";
			
			debugText.text = e.toString();
			debugText.selectable = true;
			
			removeLoadCallbacks();
		}
		
		private function onLoadIOError(e:IOErrorEvent):void {
			
			loadStatusText.text = "Error";
			
			debugText.text = e.toString();
			debugText.selectable = true;
			
			removeLoadCallbacks();
		}
		
		private function onLoadComplete(e:Event):void {
			
			cardSwf = MovieClip(LoaderInfo(e.currentTarget).content);
			cardSwf.x = cardPos.x - cardPos.width * 0.5;
			cardSwf.y = cardPos.y - cardPos.height * 0.5;
			addChild(cardSwf);
			
			loadStatusText.text = "Loaded";
			
			removeLoadCallbacks();
			
			allowParse();
		}
		
		private function allowParse():void {

			parseCardButton.addEventListener(MouseEvent.CLICK, onParseCardClicked);
			
			parseCardButton.buttonMode = true;
			parseCardButton.useHandCursor = true;
		}
		
		private function disallowParse():void {
			
			parseCardButton.removeEventListener(MouseEvent.CLICK, onParseCardClicked);
			
			parseCardButton.buttonMode = false;
			parseCardButton.useHandCursor = false;
			
			cardFrameCount = 0;
			cardSwfChildren.length = 0;
		}
		
		private function performParse():uint {
			
			var currentFrameCount:uint = 0;
			var openList:Vector.<MovieClip> = new Vector.<MovieClip>();
			
			if (cardSwf != null) {
				
				openList.push(cardSwf);
			}
			
			while (openList.length > 0) {
				
				var clip:MovieClip = openList.pop();
				var clipFrameCount:uint = clip.totalFrames;
				
				if (currentFrameCount < clipFrameCount) {
					currentFrameCount = clipFrameCount;
				}
				
				for (var i:int = clip.numChildren - 1; i >= 0; --i) {
					
					var child:DisplayObject = clip.getChildAt(int(i));
					
					if (child is MovieClip) {
						var childClip:MovieClip = MovieClip(child);
						
						openList.push(childClip);
						cardSwfChildren.push(childClip);
					}
				}
			}
			
			return currentFrameCount;
		}
		
		private function onParseCardClicked(e:MouseEvent) {
			
			if (isRendering()) {
				return;
			}
			
			var currentFrameCount:uint = performParse();
			
			if (currentFrameCount != cardFrameCount) {
				if (cardFrameCount == 0) {
					
					if (currentFrameCount > 0) {
						allowGenerate();
					}
				}
				else {
					
					disallowGenerate();
				}
				
				cardFrameCount = currentFrameCount;
				frameCountText.text = cardFrameCount.toString();
			}
		}
		
		private function allowGenerate():void {

			generateButton.addEventListener(MouseEvent.CLICK, onGenerateClicked);
			
			generateButton.buttonMode = true;
			generateButton.useHandCursor = true;
		}
		
		private function disallowGenerate():void {
			
			generateButton.removeEventListener(MouseEvent.CLICK, onGenerateClicked);
			
			generateButton.buttonMode = false;
			generateButton.useHandCursor = false;
		}
		
		private function onGenerateClicked(e:MouseEvent) {
			
			if (isRendering()) {
				return;
			}
			
			// This is not ideal, but the individual card swf has really weird bounds we cannot use
			pngSource = new BitmapData (cardPos.width, cardPos.height);
			
			cardSwfChildren.forEach(setupChildGenerate);
			
			renderFrameIndex = 1;
			frameGeneratingText.text = renderFrameIndex.toString();
		}
		
		private function setupChildGenerate(clip:MovieClip, index:int, vector:Vector.<MovieClip>):void {
			
			clip.gotoAndStop(0);
		}
		
		private function stepChildGenerate(clip:MovieClip, index:int, vector:Vector.<MovieClip>):void {
			
			if (clip.currentFrame == clip.totalFrames) {
				clip.gotoAndStop(0);
			}
			else {
				clip.nextFrame();
			}
		}
		
		private function cleanupChildGenerate(clip:MovieClip, index:int, vector:Vector.<MovieClip>):void {
			
			if (clip.currentFrame != clip.totalFrames) {
				trace("Potential frame desynchronication - needs more frames till maximum common multiple!!");
			}
			
			clip.gotoAndPlay(0);
		}
		
		private function renderFrameToFile(clip:MovieClip, frameIndex:uint):void {
			
			pngSource.draw(clip);
			
			var ba:ByteArray = PNGEncoder.encode(pngSource);
			var file:File = getOutputDirectory().resolvePath(cardFilename.text+"_"+"output\\"+frameIndex.toString()+".png");
			
			fileStream.open(file, FileMode.WRITE);
			fileStream.writeBytes(ba);
			fileStream.close();
		}
		
		private function getOutputDirectory():File {
			
			switch (outputLocationButton.currentFrame) {
				case 1:
				return File.desktopDirectory;
				
				case 2:
				return File.documentsDirectory;
				
				case 3:
				return File.userDirectory;
				
				case 4:
				return File.applicationDirectory;
				
				case 5:
				return File.applicationStorageDirectory;
				
				default:
				return File.desktopDirectory;
			}
		}
		
		private function onOutputDirectoryClicked(e:MouseEvent) {
			
			if (isRendering()) {
				return;
			}
			
			if (outputLocationButton.currentFrame == outputLocationButton.totalFrames) {
				outputLocationButton.gotoAndStop(0);
			}
			else {
				outputLocationButton.nextFrame();
			}
			
			outputDirectory = getOutputDirectory();
		}

	}
	
}
