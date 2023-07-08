// Feather ignore all
///@desc A Snip is a struct. It contains a lot of properties. Snips will override an objects image_index, sprite_index, and image_speed
///@param {Asset.GMSprite}  sprite       The sprite to use for the snip
///@param {real}            speed        The speed that the snip will play at (same scale as image_speed)
///@param {real}            [startFrame] Optional argument to create an snip from a subsection of a sprite (default 0)
///@param {real}            [endFrame]   Optional argument to create an snip from a subsection of a sprite (default sprite_get_number(sprite)-1)
///@param {Enum.AE_EndType} [endType]    How to behave when the Snip finishes	
///@param {Struct.AESnip}   [successor]  A Snip to play after this snip finished playing forwards (use -1 or undefined for no successor)
function AESnip(_sprite, _speed, _start, _end, _endType=AE_EndType.replay, _successor=undefined) constructor
{
	/// @ignore The sprite used for the snip
	sprite = _sprite;
	/// @ignore The speed that the snip should be played at
	speed  = _speed;
	/// @ignore The default direction to play the Snip (1 for forward, -1 for backwards)
	direction = 1;
	/// @ignore A list of transitions that lead to this snip
	incTransitions = array_create(0);
	/// @ignore A list of transitions that come from this snip
	outTransitions = array_create(0);
	/// @ignore How the Snip should act when it finishes playing and there's not a Snip to play next
	endType = _endType; //The end_type will be overridden with snip_play_next(), or if the Snip has a successor/precursor
	
	// The successor will be overridden by the snip_play_next() function
	/// @ignore Successors will also be ignored if the Snip is played as a transition. The Snip to play every time this Snip ends playing forward
	successor = _successor;
	/// @ignore Whether or not to use Transitions when playing this Snip's successor
	successorTransition = (_successor != undefined);
	
	/// @ignore A script to execute when the snip finishes playing
	completeScript = function() {};
	/// @ignore The argument to use in the script completion
	completeScriptArgs = [];
	/// @ignore
	completeScript = undefined;
	/// @ignore Set the start frame of the snip to 0 if no value is given or set it to the given start value
	frameStart = _start ?? 0;
	/// @ignore Set the end value to sprite_get_number(_sprite) - 1 if no value is given or set it to the given end value
	frameEnd = _end ?? sprite_get_number(_sprite) - 1;
	/// @ignore Get the total number of frames in the snip by subtracting the start from the end and adding 1
	frameCount = (frameEnd - frameStart) + 1;
	
	// Throw an error if the start and end don't match right
	if (frameCount <= 0) {
	throw("Error creating snip for"+sprite_get_name(_sprite)+": End must be greater than start. \nStart"+string(frameStart)+"End: "+string(frameEnd));
	}
	
	/// @ignore Array to hold per-frame items like speed and actions
	frameSpeed = array_create(frameCount, 1);
	/// @ignore Callbacks
	frameCallback  = array_create(frameCount, undefined);
	var _arr=[];
	/// @ignore
	frameCallbackArgs = array_create(frameCount, _arr);
	/// @ignore
	frameCallback[0] = function() {}
	
	/// @ignore A list to hold all the loops in the snip
	loops = array_create(0);
	/// @ignore A value to handle the Sprite speed and speed types
	speedScale = 1;
	if (_sprite != undefined) {
		// Feather disable once GM1044
		var _type = (sprite_get_speed_type(_sprite) == spritespeed_framespergameframe);
		speedScale = (_type) ? sprite_get_speed(_sprite) : sprite_get_speed(_sprite) / game_get_speed(gamespeed_fps);
	}
	
	#region Methods
	/// @desc Change the start and end frame of the Snip
	/// @param {real} startFrame
	/// @param {real} endFrame
	static setFrameSE = function(_start, _end) 
	{
		// Set the start frame of the snip to 0 if no value is given or set it to the given start value
		frameStart = _start ?? 0;
		// Set the end value to sprite_get_number(_sprite) - 1 if no value is given or set it to the given end value
		frameEnd   = _end ?? sprite_get_number(_sprite) - 1;
		//Get the total number of frames in the snip by subtracting the start from the end and adding 1
		frameCount = (frameEnd - frameStart) + 1;
	}

	///@desc When a Snip finishes playing forwards, if it has a successor it will automatically play it with or without transition
	///@param {Struct.AESnip} successor The snip to play after the given snip is finished playing (use undefined or -1 to remove the successor)
	///@param {bool} [useTransition]    Optional whether or not to use a transition (default = true)
	static setSuccessor = function(_successor, _transition=true)
	{
		successor = _successor;
		successorTransition = _transition;
		return self;
	}
	
	///@param {bool} transition Whether or not to look for a transition between the snip and its successor
	static setSuccessorTransition = function(_transition)
	{
		successorTransition = _transition;
		return self;
	}
	
	///@desc Returns the successor to the given snip (undefined if none)
	static getSuccessor = function()
	{
		return (successor );
	}
	
	///@desc Sets the given frame from the given Snip to the given speed
	///@param {real} frame The frame number to set to the given speed (not image_index)
	///@param {real} speed The speed to set the given frame relative to the Snip speed (same scale as image_speed)
	static setFrameSpeed = function(_frame, _speed) 
	{	
		if (argument_count < 3) {
			#region Check
			if (__AE_DEBUG) {
			if (_frame >= frameCount || _frame < 0) { 
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
			} 
			if (_speed < 0) { 
			throw("Frame Speeds must always be larger than 0. To play a Snip backwards set the Snip speed to a negative value"); 
			} 
			}#endregion
			frameSpeed[_frame] = _speed;
			return self;
		}
		else {
			var i=0; repeat(argument_count div 2) {
				var _f = argument[i];
				var _s = argument[i+1];
				
				setFrameSpeed(_f, _s);
				
				i++;
			}
			return self;
		}
	}
	
	///@desc Returns the speed for the given frame in the given Snip
	///@param {real} frame The frame number to set to the given speed (not image_index)
	static getFrameSpeed = function(_frame)
	{
		#region Check
		if (__AE_DEBUG) {
		//Throw an error if a bad frame is given
		if (_frame >= frameCount || _frame < 0) {
			var _str = string("The Sprite given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} } #endregion
		return frameSpeed[_frame];
	}
	
	///@desc Resets all frame speeds in the given snip to 1
	static resetFrameSpeed = function()
	{
		var i=0; repeat(array_length(frameSpeed) ) frameSpeed[i++] = 1;
		return self;
	}
	
	///@desc Changes an snip's sprite
	///@param {Asset.GMSprite} sprite The sprite to set. The sprite must at least have a sub-image count of the snip's snip_frame_end property
	static setSprite = function(_sprite)
	{
		//Changing the sprite could cause some index out of bounds errors
		//So when changing the sprite, make sure it has enough sub-images for the snip
	
		//Get the number of frames in the sprite
		var _frames = sprite_get_number(_sprite);
		//If the sprite has fewer frames than the snip
		if (_frames < frameEnd) {
			var _str = string("The Sprite given in setSprite does not have enough sub-images. Sprite sub-image count: {0} Frames needed: {1}", _frames, frameEnd);
			throw(_str); 
		}
		else
		{
			//Set the sprite
			sprite = _sprite;
			speedScale = 1;
			//A value to handle the Sprite speed and speed types
			if (_sprite != undefined)
			{
				// Feather disable once GM1044
				var _type = (sprite_get_speed_type(_sprite) == spritespeed_framespergameframe);
				speedScale = (_type) ? sprite_get_speed(_sprite) : sprite_get_speed(_sprite) / game_get_speed(gamespeed_fps);
			}
		}
	}
	
	///@desc Returns the sprite used for the snip
	static getSprite = function()
	{
		return (sprite);
	}

	///@desc Sets the speed of the Snip.
	///@param {real} speed The speed to set the Snip to play at, positive values only
	static setSpeed = function(_speed)
	{
		#region Check
		if (__AE_DEBUG) {
		//Check to make sure the speed is a positive value
		if (_speed < 0)
		{
			throw ("The speed given in snip_set_speed cannot be negative. If you want a Snip to play backwards see snip_set_backward()");
		} } #endregion
		speed = _speed;
		return self;
	}
	
	///@desc Returns the overall speed of the given snip
	static getSpeed = function()
	{
		return (speed );
	}
	
	///@desc Adds a script that will execute every time an snip reaches a frame (only called once when changing to a frame)
	///@param {real}     frame      frame number (relative to the Snip, not the sprite... eg not image_index)
	///@param {Function} script     The script to run
	///@param {Array}    [argument] The value of the argument to pass into the script
	static setFrameCallback  = function(_frame, _fun, _args=[])
	{	
		#region Check
		if (__AE_DEBUG) {
		if (_frame >= frameCount || _frame < 0) {
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} }#endregion
		frameCallback    [_frame] =  _fun;
		frameCallbackArgs[_frame] = _args;
	}

	///@desc Returns the script assigned to the given snip frame
	///@param {real} frame The frame to get the script to
	static getFrameCallback = function(_frame)
	{
		#region Check
		if (__AE_DEBUG) {
		if (_frame >= frameCount || _frame < 0) {
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} } #endregion
		return (frameScripts[_frame] );
	}
	
	///@desc Returns the script assigned to the given snip frame
	///@param {real} frame The frame to get the script to
	static getFrameArguments = function(_frame)
	{
		#region Check
		if (__AE_DEBUG) {
		if (_frame >= frameCount || _frame < 0) {
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} } #endregion
		return (frameCallbackArgs[_frame] );
	}
	
	///@desc Sets the behavior for when the given Snip finishes playing and there is no animation to play next	
	///@param {Enum.AE_EndType} endType How to behave when the Snip finishes	
	static setEndType = function(_endType) 
	{
		endType = _endType;
	}
	
	/// @desc Returns what the Snip is set to do when it finishes as an enum AE_EndType
	/// @return {Enum.AE_EndType}
	static getEndType = function()
	{
		return (endType);
	}

	///@desc Sets the script that should be executed when the given snip ends
	///@param {Function} script     The script to execute when the given snip ends
	///@param {Array}    [argument] The value of argument to pass into the script
	static setCompletionCallback = function(_fun, _args=[])
	{
		completeScript = _fun;
		completeScriptArgs = _args;
		return self;
	}
	
	///@desc Sets the Snip direction to forward (AE_DIR_FORWARD) or backward (AE_DIR_BACKWARD)
	///@param {real} direction AE_DIR_FORWARD or AE_DIR_BACKWARD
	static setDirection = function(_direction)
	{
		#region Check
		if (__AE_DEBUG) {
		if (_direction != AE_DIR_FORWARD || _direction != AE_DIR_BACKWARD) {
			throw("The direction is not a Ae Direction Constant");
		} } #endregion
		direction = _direction;
		return self;
	}
	
	///@desc Sets the Snip direction to the opposite of what it currently is
	static reverseDirection = function()
	{
		direction = -direction;
		return self;
	}
	
	///@desc Gets the direction that a Snip is currently playing (AE_DIR_FORWARD or AE_DIR_BACKWARD)
	static getDirection = function()
	{
		return (direction);
	}
	
	///@desc Returns the given Snip frame as the sprite image index
	///@param {real} frame The frame number within the given Snip to get the index of
	static asFrame = function(_frame)
	{
		return (_frame + frameStart);
	}
	
	///@desc Returns the given sprite index as the given Snip's frame index
	///@param {real} index The sprite index number to convert into a Snip frame index
	static asIndex = function(_index)
	{
		return (_index - frameStart);
	}
	
	///@desc Returns the array of Loops in the snip
	static getLoops = function()
	{
		return (loops);
	}
	
	/// @desc Clone the current Snip
	static clone = function() 
	{
		//Create a new Snip with the same properties
		var _newSnip = new AESnip(sprite, speed, frameStart, frameEnd, endType, successor); 
		
		//Set other properties of the snip
		_newSnip.completeScript     = completeScript;
		_newSnip.completeScriptArgs = completeScriptArgs;
		_newSnip.direction = direction;
	
		//Loop through all the snip frames and copy the speeds
		var _this = self;
		var i=0; with (_newSnip) {
			#region Through all the snip frames and copy the speeds
			var _tframeSpeed  = _this.frameSpeed;
			var _tframeScript = _this.frameCallback, _tframeArgs = _this.frameCallbackArgs;
			repeat(frameCount) {
				setFrameSpeed(i, _tframeSpeed[i] );
				setFrameCallback(i , _tframeScript[i], _tframeArgs[i]);
				i++;
			} 
			#endregion
			
			#region Iterate through all the loops and create new loops for the new snip
			array_foreach(_this.loops, function(_loop) {
				var _nloop = new Loop(self, _loop.start, _loop.finish, _loop.iterate);	
			});
			
			#endregion
		
			#region Iterate through all the incoming transitions and add them to the new snip
			array_foreach(_this.incTransitions, function(_transition) {
				var _ntransition = new Transition(_transition.from, self, _transition.use);
			});
			
			#endregion
		
			#region Iterate through all the outgoing transitions and add them to the new snip
			array_foreach(_this.outTransitions, function(_transition) {
				var _ntransition = new Transition(self, _transition.to, _transition.use);
			});
			
			#endregion
		}
	
		return (_newSnip);
	}
	
	/// @desc Debug
	static toString = function()
	{
		return string("Snip [{0}]", sprite_get_name(sprite) );
	}
	
	#endregion
}
