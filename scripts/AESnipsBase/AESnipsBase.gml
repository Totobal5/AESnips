//How the Snip should behave when it finishes playing
#macro AE_DEBUG true

#macro AE_DIR_FORWARD   1
#macro AE_DIR_BACKWARD -1

enum SnipEnd {
	stop    ,     //Freeze on the completed frame
	stopHead,     //Jump back to the first frame and freeze
	stopTail,     //Jump to the last frame and freeze
	replay  ,     //Jump back to the first frame and play again (or the last frame if the Snip is being played backward)  DEFAULT
	pingpong,     //Reverse the Snip speed, transition to the next step when it hits the first or last frame
	pingpongHead, //Reverse the Snip speed, only transition to next Snip when it's back to the first frame
	pingpongTail  //Reverse the Snip speed, only transition to next Snip when it's back to the final frame
}

#region Snip, Transition, and Loop creation

///@desc A Snip is a struct. It contains a lot of properties (you can find the properties and descriptions in the AESnipBase script).
///      Snips will override an objects image_index, sprite_index, and image_speed
///@param {Asset.GMSprite} sprite       The sprite to use for the snip
///@param {real}           speed        The speed that the snip will play at (same scale as image_speed)
///@param {real}           [startFrame] Optional argument to create an snip from a subsection of a sprite (default 0)
///@param {real}           [endFrame]   Optional argument to create an snip from a subsection of a sprite (default sprite_get_number(sprite)-1)
///@param {Enum.SnipEnd}   [endType]    How to behave when the Snip finishes	
///@param {Struct.Snip}    [successor]  A Snip to play after this snip finished playing forwards (use -1 or undefined for no successor)
function Snip(_sprite, _speed, _start, _end, _endType=SnipEnd.replay, _successor=undefined) constructor
{
	sprite = _sprite;   // The sprite used for the snip
	speed  = _speed;    // The speed that the snip should be played at
	direction = 1;      //The default direction to play the Snip (1 for forward, -1 for backwards)
	incTransitions = array_create(0);  // A list of transitions that lead to this snip
	outTransitions = array_create(0);  // A list of transitions that come from this snip
	// How the Snip should act when it finishes playing and there's not a Snip to play next
	endType = _endType; //The end_type will be overridden with snip_play_next(), or if the Snip has a successor/precursor
	
	// The successor will be overridden by the snip_play_next() function
	// Successors will also be ignored if the Snip is played as a transition
	successor           = _successor;                   // The Snip to play every time this Snip ends playing forward
	successorTransition = (_successor != undefined);    // Whether or not to use Transitions when playing this Snip's successor
	
	completeScript     = function() {};  // A script to execute when the snip finishes playing
	completeScriptArgs = [];  // The argument to use in the script completion
	completeScript = undefined;
	// Set the start frame of the snip to 0 if no value is given or set it to the given start value
	frameStart = _start ?? 0;
	// Set the end value to sprite_get_number(_sprite) - 1 if no value is given or set it to the given end value
	frameEnd   = _end ?? sprite_get_number(_sprite) - 1;
	//Get the total number of frames in the snip by subtracting the start from the end and adding 1
	frameCount = (frameEnd - frameStart) + 1;
	
	// Throw an error if the start and end don't match right
	if (frameCount <= 0)
	{
		throw("Error creating snip for " + sprite_get_name(_sprite) +
		      ": End must be greater than start. Start:" + string(frameStart) +
		      "  End:" + string(frameEnd) );
	}
	
	// Array to hold per-frame items like speed and actions
	frameSpeed     = array_create(frameCount, 1);
	frameCallback  = array_create(frameCount, undefined);
	var _arr=[];
	frameCallbackArgs = array_create(frameCount, _arr);
	frameCallback[0]  = function() {}
	
	//A list to hold all the loops in the snip
	loops = array_create(0);
	//A value to handle the Sprite speed and speed types
	speedScale = 1;
	if (_sprite != undefined)
	{
		// Feather disable once GM1044
		var _type = (sprite_get_speed_type(_sprite) == spritespeed_framespergameframe);
		speedScale = (_type) ? sprite_get_speed(_sprite) : sprite_get_speed(_sprite) / game_get_speed(gamespeed_fps);
	}
	
	#region Methods
	
	///@desc When a Snip finishes playing forwards, if it has a successor it will automatically play it with or without transition
	///@param {Struct.Snip} successor       The snip to play after the given snip is finished playing (use undefined or -1 to remove the successor)
	///@param {bool}        [useTransition] Optional whether or not to use a transition (default = true)
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
		#region Check
		if (AE_DEBUG) {
		if (_frame >= frameCount || _frame < 0) 
		{ 
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} 
		if (_speed < 0) { 
			throw("Frame Speeds must always be larger than 0. To play a Snip backwards set the Snip speed to a negative value"); 
		} }#endregion
		frameSpeed[_frame] = _speed;
		return self;
	}

	///@param {Array<real>} array [frame, speed]
	static setFrameSpeedExt = function(_array) 
	{
		var i=0; repeat(array_length(_array) div 2)
		{
			setFrameSpeed(_array[i], _array[i + 1] );
			i = i + 1;
		}
		return self;
	}

	///@desc Returns the speed for the given frame in the given Snip
	///@param {real} frame The frame number to set to the given speed (not image_index)
	static getFrameSpeed = function(_frame)
	{
		#region Check
		if (AE_DEBUG) {
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
		var i=0; repeat(frameCount) {frameSpeed[i++] = 1; }
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
		if (AE_DEBUG) {
		//Check to make sure the speed is a positive value
		if (_speed < 0)
		{
			throw ("The speed given in snip_set_speed cannot be negative. If you want a Snip to play backwards see snip_set_backward()");
		} } #endregion
		speed = _speed;
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
		if (AE_DEBUG) {
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
		if (AE_DEBUG) {
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
		if (AE_DEBUG) {
		if (_frame >= frameCount || _frame < 0) {
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, frameCount);
			throw(_str); 
		} } #endregion
		return (frameCallbackArgs[_frame] );
	}
	
	///@desc Sets the behavior for when the given Snip finishes playing and there is no animation to play next	
	///@param {Enum.SnipEnd} end_type How to behave when the Snip finishes	
	static setEndType = function(_endType) 
	{
		endType = _endType;
	}
	
	/// @desc Returns what the Snip is set to do when it finishes as an enum SnipEnd
	/// @return {Enum.SnipEnd}
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
		if (AE_DEBUG) {
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
	static toFrame = function(_frame)
	{
		return (_frame + frameStart);
	}
	
	///@desc Returns the given sprite index as the given Snip's frame index
	///@param {real} index The sprite index number to convert into a Snip frame index
	static toIndex = function(_index)
	{
		return (_index - frameStart);
	}
	
	///@desc Returns the array of Loops in the snip
	static getLoops = function()
	{
		return (loops);
	}
	
	static clone = function() 
	{
		//Create a new Snip with the same properties
		var _newSnip = new Snip(sprite, speed, frameStart, frameEnd, endType, successor); 

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
	
	static toString = function()
	{
		return string("Snip [{0}]", sprite_get_name(sprite) );
	}
	
	#endregion
}

///@desc Creates a new transition between "from" and "to" using the given snip 
///@param {Struct.Snip} from The snip that the transition is coming from
///@param {Struct.Snip} to   The snip the the transition is going to
///@param {Struct.Snip} snip The snip that should be played as the transition
function Transition(_from, _to, _snip) constructor
{
	// Set up the values for the Transition
	from = _from; // The snip it is coming from
	to   = _to;   // The snip it is going to
	use  = _snip; // The snip that will play as the transition
	
	//Add this transition to the incoming and outgoing lists of the snips
	array_push(  _to.incTransitions, self);
	array_push(_from.outTransitions, self);
	
	#region Methods
	/// @desc Destroys the transition and removes it from the incoming and outgoing lists of the appropriate Snips
	static destroy = function()
	{
		static _f = function(v) {
			return (v == self);
		}
		var _fout  = from.outTransitions;
		var _index = array_find_index(_fout, _f) 
		if (_index > -1) array_delete(_fout, _index, 1)
		
		var _tiin = to.incTransitions;
		_index = array_find_index(_tiin, _f);
		if (_index > -1) array_delete(_fout, _index, 1);
	}
	
	///@desc Changes the given transition's to snip
	///@param {Struct.Snip} to The transition to set as the new to value
	static setTo   = function(_to)
	{
		var _oto = to;
		// Change the transition's property
		to = _to;
		// Remove the transition from the old from snip's outgoing list
		var _index = array_find_index(_oto.incTransitions, function(v, i) {
			return (v == self);
		})
		array_delete(_oto.incTransitions, _index, 1);
		
		// Add the transition to the from
		array_push(_oto.incTransitions, self);
	}

	///@desc Returns the snip that a transition is going to
	///@return {Struct.Snip}
	static getTo = function()
	{
		return (to);
	}
	
	///@desc Changes the given transition's from snip
	///@param {Struct.Snip} from The transition to set as the new from value
	static setFrom = function(_from)
	{
		var _ofrom = from;
		from = _from;
		// Remove the transition from the old from snip's outgoing list
		var _index = array_find_index(_ofrom.outTransitions, function(v, i) {
			return (v == self);
		})
		array_delete(_ofrom.outTransitions, _index, 1);
		
		// Add the transition to the from
		array_push(_from.outTransitions, self);
		
		return self;
	}
	
	///@desc Returns the snip that a transition is coming from
	///@return {Struct.Snip}
	static getFrom = function()
	{
		return (from);
	}	
	
	///@desc Returns the snip that a transition plays
	///@return {Struct.Snip}
	static getUse  = function()
	{
		return (use);
	}
	
	/// @desc Debug message
	static toString = function()
	{
		return "Transition[" + string(use) + "]";
	}
	
	#endregion
}

///@desc Creates a loop in the snip that will play once and then repeat the given number of times
///@param {Struct.Snip} snip    The snip that the loop will be a part of
///@param {real}        start   The frame that the loop starts at (inclusive)
///@param {real}        finish  The frame that the loop will end at (inclusive)
///@param {real}        iterate How many times to repeat after playing once (0 means the loop will play once and any number less than 0 will skip the loop entirely)
function Loop(_snip, _start, _finish, _iterate) constructor
{
	snip   =  _snip;        //The snip that the loop belongs to
	start  = _start;        //The start frame should always be a frame before the end
	finish = _finish + 1;   //The end frame should always be after the start
	// 1 is added to make the end frame inclusive
	iterate = _iterate; // Loops repeat once and then repeat this many times so they'll play (repeat + 1) times
	
	//Add the loop to the snip's list
	array_push(_snip.loops, self);
	
	#region Methods
	
	static destroy = function()
	{
		static _f = function(v) {
			return (v == self);
		}
		var _index = array_find_index(snip.loops, _f);
		if (_index > -1) array_delete(snip.loops, _index, 1);
	}
	
	/// @desc Sets the repeat count of the loop to the given repeat count
	/// @param {real} iterate The number of times to repeat the loop after it plays once
	static setIterate = function(_iterate)
	{
		iterate = _iterate;
		return self;
	}
	
	///@desc Returns the number of times a loop will repeat (not counting the first time it plays)
	static getIterate = function()
	{
		return (iterate);
	}
	
	///@desc Returns the Snip that the given loop is attached to
	static getSnip = function()
	{
		return (snip);
	}
	
	///@desc Returns the starting frame of the given loop
	static getStart  = function()
	{
		return (start);
	}
	
	///@desc Returns the ending frame of the given loop
	static getFinish = function()
	{
		return (finish);
	}
	
	#endregion
}

#endregion

#region GML-like

///@desc Immediately plays the given snip with or without transition
///@param {Struct.SnipPlayer} snipPlayer          snip player
///@param {Struct.Snip}       snip                The snip to play
///@param {bool}              [shouldTransition]  Whether or not the system should try to find a transition between the current snip and the snip to play
function snip_play(_snipPlayer, _snip, _shouldTransition)
{
	_snipPlayer.play(_snip, _shouldTransition);
}

///@desc Sets an snip to play as soon as the current snip is done playing
///@param {Struct.SnipPlayer} snipPlayer          snip player
///@param {Struct.Snip}       snip                The snip to play
///@param {bool}              [shouldTransition]  Whether or not the system should try to find a transition between the current snip and the snip to play
function snip_play_next(_snipPlayer, _snip, _shouldTransition)
{
	_snipPlayer.playNext(_snip, _shouldTransition);
}

///@desc This will cancel the Snip that the object has queued to play next
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_cancel_play_next(_snipPlayer)
{
	_snipPlayer.cancelNext();
}

///@desc Resets the performance count in all the loops in the given snip
///@param {Struct.SnipPlayer} snipPlayer snip player
///@param {Snip} snip The snip that the loops are a part of
function snip_reset_loops(_snipPlayer, _snip)
{	
	_snipPlayer.resetLoops(_snip);
}

///@desc Clones all the Transitions associated with the source and applies them to the destination as well (clears all previous Transitions in the destination)
///@param {Struct.Snip} source      The Snip with the Transitions 
///@param {Struct.Snip} destination The Snip that you want to clone the Transitions to
function snip_clone_transitions(_source, _destination)
{
	#region Check
	if (AE_DEBUG) {
	if (_source == undefined)
	{
		throw "snip_clone_transitions() Source undefined";
		return;
	}
	if (_destination == undefined)
	{
		throw "snip_clone_transitions() destination undefined";
		return;
	} } #endregion
	
	var _sinc = _source.incTransitions, _sout = _source.outTransitions;
	#region Iterate through all the incoming transitions and add them to the destination
	var i=0; repeat(array_length(_sinc) ) {
		var _transition  = _source.incTransitions[i];
		var _ntransition = new Transition(_transition.from, _destination, _transition.use);
		i = i + 1;
	}
	
	#endregion
	
	#region Iterate through all the outgoing transitions and add them to the new snip
	i=0; repeat(array_length(_sout) ) {
		var _transition  = _sout[i];
		var _ntransition = new Transition(_destination, _transition.to,_transition.use);
		i = i + 1;
	}
	
	#endregion
}

///@desc Clones all the Loops found in the source Snip and applies them to the destination Snip (unless the Loop is outside the bounds of the destination)
///@param {Struct.Snip} source      The Snip to copy the Loops from
///@param {Struct.Snip} destination The Snip to copy the Loops to
function snip_clone_loops(_source, _destination)
{
	#region Check
	if (AE_DEBUG) {
	if (_source == undefined)
	{
		throw "snip_clone_loops() Source undefined";
		return;
	}
	if (_destination == undefined)
	{
		throw "snip_clone_loops() destination undefined";
		return;
	} } #endregion
	
	#region Iterate through all the loops and create new Loops for the destination
	var _sloops = _source.loops;
	var i=0; repeat(array_length(_sloops) ) 
	{
		var _loop = _sloops[i];
		if ((_loop.start > _source.frameStart) && _loop.finish < _source.frameEnd) {
			var _nloop = new Loop(_destination, _loop.start, _loop.finish, _loop.iterate);
		}
		i += 1;
	}
	
	#endregion
}

///@desc Pauses the Snip that the object is currently playing
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_pause(_snipPlayer)
{
	_snipPlayer.pause();
}

///@desc Un-pauses the Snip that the object is currently playing
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_resume(_snipPlayer)
{
	_snipPlayer.resume();
}

///@desc Stops the Snip that the object is currently playing on the exact frame
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_stop(_snipPlayer)
{
	_snipPlayer.stop();
}

///@desc Stops the Snip that the object is currently playing and jumps to the last frame (as if the end_type is end_stop)
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_stop_tail(_snipPlayer)
{
	_snipPlayer.stopTail();
}

///@desc Stops the Snip that the object is currently playing and reloads it to the first frame (as if the end_type is end_stop_beginning)
///@param {Struct.SnipPlayer} snipPlayer snip player
function snip_stop_head(_snipPlayer)
{
	_snipPlayer.stopHead();
}

///@func snip_play_request(snip, transition)
///@desc Only plays the given Snip if it is not already playing
///@param {Struct.SnipPlayer} snipPlayer       snip player
///@param {Snip}              snip             The Snip you would like to play
///@param {bool}              shouldTransition Whether or not to Transition when playing the Snip
function snip_play_request(_snipPlayer, _snip, _shouldTransition)
{
	_snipPlayer.playRequest(_snip, _shouldTransition);
}

///@desc Pauses the entire snip system
function snip_global_pause()
{
	static sn = new SnipPlayer();
	sn.gPaused = true;
}

///@desc Resumes the entire snip system (but does not resume snips that have been individually paused)
function snip_global_resume()
{
	static sn = new SnipPlayer();
	sn.gPaused = false;
}


#endregion Snip Controls

#region Snip debug
///@func snip_draw_debug(x,y)
///@desc Draws a visual representation of the Snip that an Object is currently playing
///@param {real} x The x position to draw the debug panel
///@param {real} y The y position to draw the debug panel
function snip_draw_debug(_x,_y)
{	
	//Get the draw values so that it can be reset at the end of the function
	var _old_color = draw_get_color();
	var _old_alpha = draw_get_alpha();
	
	//The first step is to quit with a red box if there is no Snip associated with the object
	if (ae_snip_current_snip == undefined)
	{
		draw_set_color(c_red);
			draw_rectangle(_x,_y, _x+16, _y+16, false);
		draw_set_color(_old_color);
		return;
	}
	
	//The next step is to get all the relevant information from the currently playing Snip
	var _sprite = ae_snip_current_snip.snip_sprite;
	var _width = sprite_get_width(_sprite);
	var _height = sprite_get_height(_sprite);
	var _count = sprite_get_number(_sprite);
	var _start = ae_snip_current_snip.snip_frame_start;
	var _end = ae_snip_current_snip.snip_frame_end;
	var _index = floor(image_index);
	
	//Now set up values to change the way it looks
	var _back_color = c_white;
	var _progress_bar_color = c_lime;
	var _separation = 2;
	var _transparent_amount = .4;
	var _current_frame_offset = floor(_height * .25);
	var _loop_line_size = floor(_width * .1);
	var _loop_current_color = c_lime;
	var _loop_color = c_aqua;
	var _loop_zero_color = c_yellow;
	var _loop_none_color = c_red;
	var _loop_alpha = .7;
	var _no_loop_alpha = .25;
	var _frame_script_color = c_orange;
	
	var _sprite_x_axis = sprite_get_xoffset(_sprite);
	var _sprite_y_axis = sprite_get_yoffset(_sprite);
	
	//Draw each frame of the sprite
	var _i = 0;
	repeat(_count)
	{
		//Get the x and y values for the current sprite frame
		var _x1 = _x + (_i * _width) + (_separation * _i);
		var _x2 = _x1 + _width;
		var _y1 = _y;
		var _y2 = _y + _height;
		
		//Draw a background for the sprite
		//If it's a part of the Snip then it should have full opacity
		//If it's not then reduce the alpha
		if (_i >= _start and _i <= _end)
		{
			//The frame is part of the Snip so set the alpha to 1
			draw_set_alpha(1);
		}
		else
		{
			//Set the alpha to the transparent value
			draw_set_alpha(_transparent_amount);
		}
		
		//Make the frame stick out if it's the current image_index
		if (_i == _index)
		{
			_y2 = _y + _height + _current_frame_offset;
		}
		
		//Now draw everything
		draw_set_color(_back_color);
		
		//Draw the background for the frame
		draw_rectangle(_x1, _y1, _x2, _y2, false);
		
		//Draw each sprite frame
		draw_sprite(_sprite, _i, _x1 + _sprite_x_axis, _y1 + _sprite_y_axis);
		
		//If the frame has a script add a small dot below it
		if (_i - ae_snip_current_snip.snip_frame_start < array_length(ae_snip_current_snip.frame_script)
		and _i - ae_snip_current_snip.snip_frame_start >= 0)
		{
			if (ae_snip_current_snip.frame_script[_i - ae_snip_current_snip.snip_frame_start] != undefined)
			{
				draw_set_color(_frame_script_color);
				draw_ellipse(_x1 + (_width /2), _y1 + _height, _x1 + (_width/2) + 5, _y1 + _height + 5, false);
			}
		}
		
		_i += 1;
	}
	
	draw_set_alpha(1);
	
	//Now draw some more things
	//A progress bar to show how much time has been spent on a single frame
	var _px1 = _x + (_index * _width)  + (_separation * _index);
	var _px2 = _px1 + (_width * (image_index - _index));
	var _py1 = _y + _height + 1;
	var _py2 = _py1 + _current_frame_offset - 1;
	draw_set_color(_progress_bar_color);
	draw_rectangle(_px1, _py1, _px2, _py2, false);
	
	//Now draw the Loops in the Snip
	//First, draw the base loops
	_i = 0;
	repeat(ds_list_size(ae_snip_current_snip.snip_loops))
	{
		//Get the loop
		var _loop = ae_snip_current_snip.snip_loops[|_i];
		
		//If the loop should repeat
		if(_loop.loop_repeat > 0)
		{
			draw_set_color(_loop_color);
			
			if (_loop == ae_snip_current_loop)
			{
				draw_set_color(_loop_current_color);
			}
			
			draw_set_alpha(_loop_alpha);
		}
		else
		{
			draw_set_alpha(_no_loop_alpha);
			//If the loop should skip
			if (_loop.loop_repeat < 0)
			{
				draw_set_color(_loop_none_color);
			}
			else //If the loop should play without repeating
			{
				draw_set_color(_loop_zero_color);
			}
			
		}
		
		//Get the values for the start vertical line
		var _sx1 = _x + ((_loop.loop_start + _start) * _width) + (_separation * (_loop.loop_start + _start));
		var _sx2 = _sx1 + _loop_line_size;
			
		//Get the values for the end vertical line
		var _ex1 = _x + ((_loop.loop_end + _start) * _width) - (_loop_line_size*2) + ((_loop.loop_end + 1 + _start) * _separation) - 1;
		var _ex2 = _ex1 + _loop_line_size;
			
		//Get the vertical values
		var _ly1 = _y + _height + 1;
		var _ly2 = _ly1 + ((_i+1) * _loop_line_size) + (_i * _separation) + _current_frame_offset;
			
		//Draw the vertical lines on the start and end frames
		draw_rectangle(_sx1, _ly1, _sx2, _ly2 - 1, false);
		draw_rectangle(_ex1, _ly1, _ex2, _ly2 - 1, false);
		//Draw the horizontal line
		draw_rectangle(_sx1, _ly2, _ex2, _ly2 + _loop_line_size - 1, false);
		
		_i +=1;
	}
	
	//Reset back to the old values
	draw_set_color(_old_color);
	draw_set_alpha(_old_alpha);
}

#endregion