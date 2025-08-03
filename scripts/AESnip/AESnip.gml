// Feather ignore all
/// @desc A Snip is a struct that defines an animation clip with its properties and behaviors.
/// @param {Asset.GMSprite} sprite The sprite to use for the snip.
/// @param {Real} speed The speed that the snip will play at.
/// @param {Real} [start_frame=0] Optional argument to create a snip from a subsection of a sprite.
/// @param {Real} [end_frame] Optional argument, defaults to the last frame of the sprite.
/// @param {Enum.AE_EndType} [end_type=AE_EndType.replay] How the Snip behaves when it finishes.
/// @param {Struct.AESnip} [successor] A Snip to play after this one finishes.
function AESnip(_sprite, _speed, _start_frame, _end_frame, _end_type=AE_EndType.Replay, _successor=undefined) constructor
{
	#region Public Instance Variables
	
	sprite = _sprite;
	speed = _speed;
	direction = AE_DIR_FORWARD;
	end_type = _end_type;
	successor = _successor;
	
	// Frame data (read-only)
	frame_start = 0;
	frame_end = 0;
	frame_count = 0;
	
	#endregion
	
	#region Private Instance Variables
	
	__incoming_transitions = [];
	__outgoing_transitions = [];
	__successor_transition = (_successor != undefined);
	__completion_script = undefined;
	__completion_script_args = [];
	__frame_callback = [];
	__frame_callback_args = [];
	__frame_speed = [];
	__loops = [];
	__speed_scale = 1;
	
	#endregion
	
	#region Initialization
	
	// Set frame range and initialize arrays
	var _end = _end_frame ?? sprite_get_number(sprite) - 1;
	__SetFrameRangeInternal(_start_frame ?? 0, _end);
	
	// Calculate speed scale based on sprite's properties
	__UpdateSpeedScale();
	
	#endregion
	
	#region Internal Logic Helpers (Private)
	
	/// @desc Sets the frame range and resizes associated arrays.
	/// @ignore
	static __SetFrameRangeInternal = function(_start, _end)
	{
		frame_start = _start;
		frame_end = _end;
		frame_count = (frame_end - frame_start) + 1;
		
		if (frame_count <= 0) {
			var _error = $"Error creating snip for {sprite_get_name(sprite)}: End frame ({frame_end}) must be greater than or equal to start frame ({frame_start}).";
			throw(_error);
		}
		
		// Initialize arrays based on the new frame count
		__frame_speed = array_create(frame_count, 1);
		__frame_callback = array_create(frame_count, undefined);
		__frame_callback_args = array_create(frame_count, []);
	}
	
	/// @desc Calculates the speed scale based on the sprite's speed type.
	/// @ignore
	static __UpdateSpeedScale = function()
	{
		__speed_scale = 1;
		if (sprite != undefined) {
			var _is_fps = (sprite_get_speed_type(sprite) == spritespeed_framespersecond);
			__speed_scale = _is_fps ? sprite_get_speed(sprite) / game_get_speed(gamespeed_fps) : sprite_get_speed(sprite);
		}
	}
	
	/// @desc Adds a loop to this Snip. Called by AELoop constructor.
	/// @ignore
	static __AddLoop = function(_loop)
	{
		array_push(__loops, _loop);
	}
	
	/// @desc Removes a loop from this Snip. Called by AELoop.
	/// @ignore
	static __RemoveLoop = function(_loop)
	{
		var _index = array_find_index(__loops, function(item) { return item == _loop; });
		if (_index > -1)
		{
			array_delete(__loops, _index, 1);
		}
	}
	
	/// @desc Adds an incoming transition. Called by AETransition constructor.
	/// @ignore
	static __AddIncomingTransition = function(_transition)
	{
		array_push(__incoming_transitions, _transition);
	}
	
	/// @desc Adds an outgoing transition. Called by AETransition constructor.
	/// @ignore
	static __AddOutgoingTransition = function(_transition)
	{
		array_push(__outgoing_transitions, _transition);
	}
	
	/// @desc Removes an incoming transition. Called by AETransition.
	/// @ignore
	static __RemoveIncomingTransition = function(_transition)
	{
		var _index = array_find_index(__incoming_transitions, function(item) { return item == _transition; });
		if (_index > -1)
		{
			array_delete(__incoming_transitions, _index, 1);
		}
	}
	
	/// @desc Removes an outgoing transition. Called by AETransition.
	/// @ignore
	static __RemoveOutgoingTransition = function(_transition)
	{
		var _index = array_find_index(__outgoing_transitions, function(item) { return item == _transition; });
		if (_index > -1)
		{
			array_delete(__outgoing_transitions, _index, 1);
		}
	}
	
	#endregion
	
	#region Public Methods
	
	/// @desc Changes the start and end frame of the Snip.
	/// @param {Real} start_frame The new starting frame.
	/// @param {Real} end_frame The new ending frame.
	static SetFrameRange = function(_start_frame, _end_frame)
	{
		__SetFrameRangeInternal(_start_frame, _end_frame);
		return self;
	}

	///@desc Sets a successor to play automatically when this Snip finishes.
	///@param {Struct.AESnip} successor_snip The snip to play next. Use 'undefined' to remove.
	///@param {Bool} [use_transition=true] Whether to look for a transition.
	static SetSuccessor = function(_successor_snip, _use_transition=true)
	{
		successor = _successor_snip;
		__successor_transition = _use_transition;
		return self;
	}
	
	///@desc Sets the speed for a specific frame within the Snip.
	///@param {Real} frame The frame number to modify (relative to the Snip).
	///@param {Real} frame_speed The new speed for that frame.
	static SetFrameSpeed = function(_frame, _frame_speed)
	{	
		#region Check
		if (__AE_DEBUG) {
			if (_frame >= frame_count || _frame < 0) {
				throw $"Frame index [{_frame}] is out of bounds for Snip with [{frame_count}] frames.";
			}
			if (_frame_speed < 0) {
				throw "Frame speeds must be positive. To play a Snip backwards, set its direction.";
			}
		}
		#endregion
		__frame_speed[_frame] = _frame_speed;
		return self;
	}
	
	///@desc Resets all custom frame speeds to 1.
	static ResetFrameSpeeds = function()
	{
		for (var i = 0; i < frame_count; i++)
		{
			__frame_speed[i] = 1;
		}
		return self;
	}
	
	///@desc Changes the Snip's sprite.
	///@param {Asset.GMSprite} new_sprite The new sprite to use.
	static SetSprite = function(_new_sprite)
	{
		#region Check
		if (__AE_DEBUG) {
			var _frames = sprite_get_number(_new_sprite);
			if (_frames <= frame_end) {
				throw $"The new sprite does not have enough frames. Frames needed: {frame_end + 1}, Sprite has: {_frames}.";
			}
		}
		#endregion
		
		sprite = _new_sprite;
		__UpdateSpeedScale();
		return self;
	}
	
	///@desc Sets the overall speed of the Snip.
	///@param {Real} new_speed The new speed (must be positive).
	static SetSpeed = function(_new_speed)
	{
		#region Check
		if (__AE_DEBUG && _new_speed < 0) {
			throw "Snip speed cannot be negative. Use SetDirection() to play backwards.";
		}
		#endregion
		speed = _new_speed;
		return self;
	}
	
	///@desc Adds a function that will execute when the Snip reaches a specific frame.
	///@param {Real} frame The frame number (relative to the Snip).
	///@param {Function} callback The function to run.
	///@param {Array} [args=[]] Arguments to pass to the function.
	static SetFrameCallback = function(_frame, _callback, _args=[])
	{	
		#region Check
		if (__AE_DEBUG && (_frame >= frame_count || _frame < 0)) {
			throw $"Frame index [{_frame}] is out of bounds for Snip with [{frame_count}] frames.";
		}
		#endregion
		__frame_callback[_frame] = _callback;
		__frame_callback_args[_frame] = _args;
		return self;
	}
	
	///@desc Sets the behavior for when the Snip finishes playing.
	///@param {Enum.AE_EndType} new_end_type The new end behavior.
	static SetEndType = function(_new_end_type)
	{
		end_type = _new_end_type;
		return self;
	}
	
	///@desc Sets a function to execute when the Snip completes.
	///@param {Function} callback The function to execute.
	///@param {Array} [args=[]] Arguments to pass to the function.
	static SetCompletionCallback = function(_callback, _args=[])
	{
		__completion_script = _callback;
		__completion_script_args = _args;
		return self;
	}
	
	///@desc Sets the Snip's playback direction.
	///@param {Real} new_direction AE_DIR_FORWARD (1) or AE_DIR_BACKWARD (-1).
	static SetDirection = function(_new_direction)
	{
		#region Check
		if (__AE_DEBUG && (_new_direction != AE_DIR_FORWARD && _new_direction != AE_DIR_BACKWARD)) {
			throw "Direction must be AE_DIR_FORWARD or AE_DIR_BACKWARD.";
		}
		#endregion
		direction = _new_direction;
		return self;
	}
	
	///@desc Reverses the Snip's current playback direction.
	static ReverseDirection = function()
	{
		direction *= -1;
		return self;
	}
	
	/// @desc Creates a deep copy of this Snip.
	static Clone = function()
	{
		var _new_snip = new AESnip(sprite, speed, frame_start, frame_end, end_type, successor);
		
		// Copy propertiesd
		_new_snip.direction = direction;
		_new_snip.__successor_transition =		__successor_transition;
		_new_snip.__completion_script =			__completion_script;
		_new_snip.__completion_script_args =	array_clone(__completion_script_args);
		
		// Copy arrays
		array_copy(_new_snip.__frame_speed, 0, __frame_speed, 0, array_length(__frame_speed) );
		array_copy(_new_snip.__frame_callback, 0, __frame_callback, 0, array_length(__frame_callback) );
		array_copy(_new_snip.__frame_callback_args, 0, __frame_callback_args, 0, array_length(__frame_callback_args) );
		
		// Clone complex structs
		array_foreach(__loops, method({ snip: _new_snip }, function(_loop) {
			new AELoop(snip, _loop.fstart, _loop.fend - 1, _loop.iterate);
		}) );
		
		array_foreach(__incoming_transitions, method({ snip: _new_snip }, function(_trans) {
			new AETransition(_trans.from, snip, _trans.transition);
		}) );
		
		array_foreach(__outgoing_transitions, method({ snip: _new_snip }, function(_trans) {
			new AETransition(snip, _trans.to, _trans.transition);
		}) );
	
		return _new_snip;
	}
	
	/// @desc Returns a string representation of the Snip for debugging.
	static ToString = function()
	{
		return $"Snip [{sprite_get_name(sprite)}]";
	}
	
	#endregion
	
	#region Public Getters
	
	/// @desc Gets the speed of a specific frame.
	static GetFrameSpeed = function(_frame)
	{
		#region Check
		if (__AE_DEBUG && (_frame >= frame_count || _frame < 0)) {
			throw $"Frame index [{_frame}] is out of bounds for Snip with [{frame_count}] frames.";
		}
		#endregion
		return __frame_speed[_frame];
	}
	
	/// @desc Gets the internal speed scale multiplier.
	static GetSpeedScale = function()
	{
		return __speed_scale;
	}
	
	/// @desc Gets the array of loops in this Snip.
	static GetLoops = function()
	{
		return __loops;
	}
	
	#endregion
}
