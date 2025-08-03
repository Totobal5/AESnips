// Feather ignore all
/// @desc An AEPlayer is a struct that allows Snips to be played without being attached to an object.
function AEPlayer() constructor
{
	#region Global Variables
	/// @ignore Global system pause
	static g_paused = false;
	
	#endregion
	
	#region Variables (Private)
	/// @ignore
	__current_snip = undefined;
	/// @ignore
	__current_loop = undefined;
	/// @ignore
	__current_loop_index = -1;
	/// @ignore
	__current_frame = -1;
	/// @ignore
	__next_snip = undefined;
	/// @ignore
	__is_paused = false;
	/// @ignore
	__is_frozen = false;
	/// @ignore
	__should_transition = false;
	/// @ignore
	__current_target = undefined;
	/// @ignore
	__loop_performances = [];
	/// @ignore
	__snip_direction = AE_DIR_FORWARD;
	/// @ignore
	__player_changed = false;
	/// @ignore
	__speed_multiplier = 1;
		
	/// @ignore Time source for the step event
	__time_source = time_source_create(time_source_game, 1, time_source_units_frames, method(self, __Update), [], -1);
	time_source_start(__time_source);
	
	#endregion
	
	#region Variables (Public)
	
	// These variables are public so they can be read externally (e.g., for drawing)
	image_index = 0;
	image_speed = 0;
	sprite_index = -1;	
	
	#endregion
	
	#region Internal Methods (Private)
	
	/// @desc Called every frame to update the player's logic.
	/// @ignore
	static __Update = function()
	{
		if (__current_snip == undefined || __is_frozen || __is_paused || g_paused) exit;
		
		__CalculateImageSpeed();
		
		if (__CheckAnimationFinished())
		{
			__AnimationEnd();
			exit;
		}
		
		__ExecuteFrameCallback();
		__HandleLoops();
		
		image_index += image_speed * __current_snip.__speed_scale;
	}
	
	/// @desc Handles the end of an animation.
	/// @ignore
	static __AnimationEnd = function()
	{
		if (__current_snip == undefined) exit;
		
		// If in the middle of a loop, handle it first
		if (__current_loop != undefined)
		{
			if (__ProcessLoopEnd()) exit;
		}
		
		// If the EndType is PingPong, handle it and return
		if (__HandlePingPong()) return;
		
		__ExecuteCompletionCallback();
		__PlayNextOrSuccessor();
	}

	#endregion

	#region Internal Logic Helpers (Private)

	/// @desc Calculates the final animation speed for the current frame.
	/// @ignore
	static __CalculateImageSpeed = function()
	{
		var _snip = __current_snip;
		var _speed_on_frame = _snip.__frame_speed[(image_index - _snip.frame_start)];
		
		image_speed = _speed_on_frame
					* _snip.speed
					* _snip.direction
					* __snip_direction
					* __speed_multiplier;
	}

	/// @desc Checks if the animation has passed its last frame.
	/// @ignore
	/// @return {Bool}
	static __CheckAnimationFinished = function()
	{
		var _epsilon = math_get_epsilon();
		var _next_frame = image_index + (image_speed * __current_snip.__speed_scale);
		var _is_forward = (__snip_direction * __current_snip.direction * __current_snip.speed) > 0;
		
		return ((_next_frame >= __current_snip.frame_end + 1 - _epsilon) && _is_forward) 
			|| ((_next_frame <= __current_snip.frame_start) && !_is_forward);
	}
	
	/// @desc Executes a frame's callback if the frame has changed.
	/// @ignore
	static __ExecuteFrameCallback = function()
	{
		if (floor(__current_frame) != floor(image_index - __current_snip.frame_start) || __player_changed)
		{
			var _frame_relative = image_index - __current_snip.frame_start;
			var _script = __current_snip.__frame_callback[_frame_relative];
			
			if (_script != undefined)
			{
				var _arg = __current_snip.__frame_callback_args[_frame_relative];
				if (is_method(_script)) method_call(_script, _arg);
				else script_execute(_script, _arg);
			}
			
			__player_changed = false;
			__current_frame = _frame_relative;
		}
	}

	/// @desc Manages loop logic (entering and processing).
	/// @ignore
	static __HandleLoops = function()
	{
		var _snip_loops = __current_snip.__loops;
		if (array_length(_snip_loops) == 0) exit;
		
		var _is_forward = (__snip_direction * __current_snip.direction * __current_snip.speed) > 0;
		var _index_relative = image_index - __current_snip.frame_start;

		// If not in a loop, look for one
		if (__current_loop == undefined)
		{
			for (var i = 0; i < array_length(_snip_loops); i++)
			{
				var _loop = _snip_loops[i];
				var _is_in_loop = (_index_relative >= _loop.start_frame) && (_index_relative < _loop.end_frame_exclusive);
				var _is_done = (__loop_performances[i] >= _loop.iterations);
				var _should_skip = (_loop.iterations < 0 && __loop_performances[i] <= 0);
			
				if (_is_in_loop && (!_is_done || _should_skip))
				{
					if (_should_skip)
					{
						__loop_performances[i]++;
						image_index = _is_forward ?
							(_loop.end_frame_exclusive + __current_snip.frame_start) : 
							(_loop.start_frame + __current_snip.frame_start - 0.001) ;
						
						break;
					}
					else
					{
						__current_loop = _loop;
						__current_loop_index = i;
						
						break;
					}
				}
			}
		}
		// If already in a loop, process it
		else
		{
			var _loop_end = (_index_relative >= __current_loop.end_frame_exclusive);
			var _loop_start = (_index_relative < __current_loop.start_frame);
		
			if ((_loop_end && _is_forward) || (_loop_start && !_is_forward))
			{
				__loop_performances[__current_loop_index]++;
				image_index = _is_forward ? (__current_loop.start_frame + __current_snip.frame_start) : (__current_loop.end_frame_exclusive + __current_snip.frame_start - 0.001);
			
				if (__loop_performances[__current_loop_index] >= __current_loop.iterations)
				{
					__current_loop = undefined;
					__current_loop_index = -1;
				}
			}
		}
	}

	/// @desc Processes the end of an active loop. Returns true if the flow should stop.
	/// @ignore
	/// @return {Bool}
	static __ProcessLoopEnd = function()
	{
		var _is_forward = (__current_snip.direction * __snip_direction >= 0);
		var _start = __current_snip.frame_start;
	
		__loop_performances[__current_loop_index]++;
		
		image_index = _is_forward ? (__current_loop.start_frame + _start) : (__current_loop.end_frame_exclusive + _start - 0.001);
		
		if (__loop_performances[__current_loop_index] >= __current_loop.iterations)
		{
			__current_loop = undefined;
			__current_loop_index = -1;
			
			// Continue to AnimationEnd logic
			return false; 
		}
		
		// Stop the flow, the loop repeats
		return true; 
	}

	/// @desc Manages Ping-Pong logic. Returns true if it was applied.
	/// @ignore
	/// @return {Bool}
	static __HandlePingPong = function()
	{
		var _snip = __current_snip;
		var _is_forward = (_snip.speed * _snip.direction * __snip_direction) > 0;

		if (_snip.end_type == AE_EndType.PingpongHead && _is_forward)
		{
			image_index = _snip.frame_end + (1 - 0.001);
			__snip_direction *= -1;
			__ResetLoops(_snip);
			return true;
		}
		
		if (_snip.end_type == AE_EndType.PingpongTail && !_is_forward)
		{
			image_index = _snip.frame_start;
			__snip_direction *= -1;
			__ResetLoops(_snip);
			return true;
		}

		return false;
	}

	/// @desc Executes the Snip's completion script.
	/// @ignore
	static __ExecuteCompletionCallback = function()
	{
		var _script = __current_snip.__completion_script;
		if (_script != undefined)
		{
			var _args = __current_snip.__completion_script_args;
			if (is_method(_script) ) method_call(_script, _args);
			else script_execute(_script, _args);
		}
	}
	
	/// @desc Decides which Snip to play next or what to do based on the EndType.
	/// @ignore
	static __PlayNextOrSuccessor = function()
	{
		// If a snip is explicitly queued, play it
		if (__next_snip != undefined && __next_snip != __current_snip)
		{
			Play(__next_snip, __should_transition);
		}
		// Otherwise, look for a successor
		else if (__current_snip.successor != undefined)
		{
			Play(__current_snip.successor, __current_snip.__successor_transition);
		}
		// If none, apply the EndType
		else
		{
			__HandleEndType();
		}
	}

	/// @desc Applies the Snip's final behavior (replay, stop, etc.).
	/// @ignore
	static __HandleEndType = function()
	{
		var _snip = __current_snip;
		var _epsilon = 0.001;

		switch (_snip.end_type)
		{
			case AE_EndType.Replay:
				var _is_forward = _snip.direction * __snip_direction >= 0;
				image_index = _is_forward ? _snip.frame_start : _snip.frame_end + (1 - _epsilon);
				__player_changed = true;
				__ResetLoops(_snip);
			break;
			
			case AE_EndType.Stop:
				__is_frozen = true;
			break;
			
			case AE_EndType.StopTail:
				image_index = _snip.frame_end;
				__is_frozen = true;
			break;
			
			case AE_EndType.StopHead:
				image_index = _snip.frame_start;
				__is_frozen = true;
			break;
			
			case AE_EndType.Pingpong:
			case AE_EndType.PingpongHead:
			case AE_EndType.PingpongTail:
				var _is_forward = (_snip.speed * _snip.direction * __snip_direction) > 0;
				image_index = (!_is_forward) ? _snip.frame_start : _snip.frame_end + (1 - _epsilon);
				__snip_direction *= -1;
				__ResetLoops(_snip);
			break;
		}
		
		__current_frame = image_index - _snip.frame_start;
	}

	///@desc Resets the loop counters for a Snip.
	///@param {Struct.AESnip} _snip The snip whose loops will be reset.
	///@ignore
	static __ResetLoops = function(_snip)
	{
		__loop_performances = array_create(array_length(_snip.__loops), 0);
		__current_loop = undefined;
		__current_loop_index = -1;
		return self;
	}
	
	#endregion
	
	#region Control Methods (Public)
	
	///@desc Plays a Snip immediately.
	///@param {Struct.AESnip} _snip The Snip to play.
	///@param {bool} [_should_transition=false] Whether it should look for a transition.
	static Play = function(_snip, _should_transition=false)
	{
		__is_frozen = false;
		__snip_direction = AE_DIR_FORWARD;
	
		if (_snip != __current_snip) __player_changed = true;
		
		var _play_snip = _snip;
		var _next_snip_after_transition = undefined;
	
		if (_should_transition && __current_snip != undefined)
		{
			var _from = (__current_target != undefined) ? __current_target : __current_snip;
			var _transition = FindTransition(_from, _snip);
		
			if (_transition != undefined)
			{
				_play_snip = _transition.GetTransitionSnip();
				_next_snip_after_transition = _snip;
				__current_target = _snip;
			}
		}
		else
		{
			__current_target = undefined;
		}
	
		__current_snip = _play_snip;
		__next_snip = _next_snip_after_transition;
		sprite_index = _play_snip.sprite;
	
		var _epsilon = 0.001;
		image_index = (_play_snip.direction >= 0) ? _play_snip.frame_start : _play_snip.frame_end + (1 - _epsilon);
		image_speed = 0;
		__current_frame = image_index - __current_snip.frame_start;
	
		if (__current_snip != undefined) __ResetLoops(__current_snip);
		
		return self;
	}
	
	///@desc Queues a Snip to be played when the current one finishes.
	///@param {Struct.AESnip} _snip The snip to play.
	///@param {bool} [_should_transition=false] Whether to use a transition.
	static PlayNext = function(_snip, _should_transition=false)
	{
		if (__current_snip == undefined || __is_frozen)
		{
			Play(_snip, _should_transition);
		}
		else
		{
			__next_snip = _snip;
			__should_transition = _should_transition;
		}
		return self;
	}

	///@desc Plays a Snip only if it is not already playing.
	///@param {Struct.AESnip} _snip The Snip you want to play.
	///@param {bool} [_should_transition=false] Whether to use a transition.
	static PlayRequest = function(_snip, _should_transition=false)
	{
		if (!IsPlaying(_snip, true)) Play(_snip, _should_transition);
		return self;
	}
	
	///@desc Stops the animation on the current frame.
	static Stop = function()
	{
		__is_frozen = true;
		image_speed = 0;
		return self;
	}

	///@desc Stops the animation and jumps to the last frame.
	static StopTail = function()
	{
		if (__current_snip == undefined) return self;
		Stop();
		
		image_index = __current_snip.frame_end;
		__current_frame = image_index - __current_snip.frame_start;
		
		return self;
	}
	
	///@desc Stops the animation and jumps to the first frame.
	static StopHead = function()
	{
		if (__current_snip == undefined) return self;
		Stop();
		
		image_index = __current_snip.frame_start;
		__current_frame = image_index - __current_snip.frame_start;
		
		return self;
	}

	///@desc Pauses the current animation.
	static Pause = function()
	{
		__is_paused = true;
		return self;
	}

	///@desc Resumes the current animation.
	static Resume = function()
	{
		__is_paused = false;
		return self;
	}
	
	///@desc Cancels the Snip that was queued.
	static CancelNext = function()
	{
		__next_snip = __current_target;
		__should_transition = false;
		return self;
	}
	
	///@desc Jumps to a specific frame of the current animation.
	///@param {Real} _frame The frame index to jump to.
	///@param {Bool} [_reset_loops=false] Whether the loops should be reset.
	static ToFrame = function(_frame, _reset_loops=false)
	{
		if (__current_snip == undefined) return self;
		
		#region Check
		if (__AE_DEBUG) {
		if (_frame >= __current_snip.frame_count || _frame < 0) {
			var _str = string("Frame [{0}] is out of bounds for the Snip with [{1}] frames.", _frame, __current_snip.frame_count);
			throw(_str);
		} } #endregion
		
		if (_reset_loops) __ResetLoops(__current_snip);
		
		image_index = __current_snip.frame_start + _frame;
		__current_frame = _frame;
		
		return self;
	}
	
	/// @desc Sets the player's speed multiplier.
	/// @param {Real} multiplier A value to multiply the final speed by.
	static SetSpeedMultiplier = function(_multiplier)
	{
		__speed_multiplier = _multiplier;
		return self;
	}
	
	/// @desc Sets the player's playback direction.
	/// @param {Real} direction AE_DIR_FORWARD or AE_DIR_BACKWARD.
	static SetDirection = function(_direction)
	{
		#region Check
		if (__AE_DEBUG && (_direction != AE_DIR_FORWARD && _direction != AE_DIR_BACKWARD)) {
			throw "Direction must be AE_DIR_FORWARD or AE_DIR_BACKWARD.";
		}
		#endregion
		__snip_direction = _direction;
		return self;
	}
	
	/// @desc Reverses the player's current playback direction.
	static ReverseDirection = function()
	{
		__snip_direction *= -1;
		return self;
	}
	
	/// @desc Destroys this player's time source to stop updates.
	static Destroy = function()
	{
		if (time_source_exists(__time_source) ) { time_source_destroy(__time_source); }
	}
	
	#endregion
	
	#region Query Methods (Public)
	
	///@desc Returns the Snip that is currently playing.
	static GetCurrent = function()
	{
		return (__current_snip);
	}

	/// @desc Returns the Snip that will play next.
	static GetNext = function()
	{
		if (__next_snip != undefined) return __next_snip;
	
		if (__current_snip != undefined)
		{
			var _follower = __current_snip.successor;
			if (_follower == undefined)
			{
				return (__current_snip.end_type == AE_EndType.Stop) ? undefined : __current_snip;
			}
			
			if (__current_snip.__successor_transition)
			{
				var _transition = FindTransition(__current_snip, _follower);
				return (_transition != undefined) ? _transition.GetTransitionSnip() : _follower;
			}
			
			return _follower;
		}
		
		return undefined;
	}
	
	///@desc Checks if a specific Snip is playing.
	///@param {Struct.AESnip} _snip The Snip to check.
	///@param {bool} _check_target Whether to also check if it's the target of a transition.
	static IsPlaying = function(_snip, _check_target)
	{
		return ((__current_snip == _snip && !__is_frozen) || (__current_target == _snip && _check_target));
	}
	
	/// @desc Returns true if the player is currently paused.
	static IsPaused = function()
	{
		return __is_paused;
	}
	
	/// @desc Returns true if the player is currently frozen.
	static IsFrozen = function()
	{
		return __is_frozen;
	}

	///@desc Finds a transition between two Snips.
	///@param {Struct.AESnip} _from The source snip.
	///@param {Struct.AESnip} _to The destination snip.
	static FindTransition = function(_from, _to)
	{
		var _outgoing = _from.__outgoing_transitions;
		var _incoming = _to.__incoming_transitions;
		
		var _array_to_search = _outgoing;
		if (array_length(_outgoing) > array_length(_incoming) )
		{
			_array_to_search = _incoming;
		}
	
		for(var i = 0; i < array_length(_array_to_search); i++)
		{
			var _transition = _array_to_search[i];
			if (_transition.GetFromSnip() == _from && _transition.GetToSnip() == _to)
			{
				return _transition;
			}			
		}
		
		return undefined;
	}
	
	/// @desc Returns the current animation frame (sprite index).
	static GetFrame = function()
	{
		return (image_index);
	}
	
	/// @desc Returns the current frame relative to the Snip (from 0 to frameCount-1).
	static GetFrameRelative = function()
	{
		return (__current_frame);
	}
	
	/// @desc Returns the remaining repetitions of the current loop.
	static GetRemainingLoops = function()
	{
		if (is_undefined(__current_loop) || __current_loop_index == -1) return 0;
		return __current_loop.iterations - __loop_performances[__current_loop_index];
	}

	/// @desc Converts a sprite index to a Snip frame index.
	static AsFrame = function(_index)
	{
		if (__current_snip == undefined) return -1;
		return (_index - __current_snip.frame_start);
	}

	/// @desc Converts a Snip frame index to a sprite index.
	static AsIndex = function(_frame)
	{
		if (__current_snip == undefined) return -1;
		return (_frame + __current_snip.frame_start);
	}
	
	#endregion
	
	#region Draw Methods (Public)
	
	/// @desc Draws the current Snip frame.
	static Draw = function(_x, _y)
	{
		if (__current_snip != undefined)
		{
			var _sprite = __current_snip.sprite;
			if (_sprite != undefined) draw_sprite(_sprite, image_index, _x, _y);
		}
	}
	
	/// @desc Draws the current Snip frame with extended options.
	static DrawExt = function(_x, _y, _xscale, _yscale, _rotation, _color, _alpha)
	{
		if (__current_snip != undefined)
		{
			var _sprite = __current_snip.sprite;
			if (_sprite != undefined) draw_sprite_ext(_sprite, image_index, _x, _y, _xscale, _yscale, _rotation, _color, _alpha);
		}
	}

	/// @desc Draws a debug interface for the current Snip.
	/// @ignore
	static DrawDebug = function(_x, _y)
	{	
		var _old_color = draw_get_color();
		var _old_alpha = draw_get_alpha();
	
		if (__current_snip == undefined)
		{
			draw_set_color(c_red);
			draw_rectangle(_x, _y, _x + 16, _y + 16, false);
			draw_set_color(_old_color);
			exit;
		}
	
		var _sprite = __current_snip.sprite;
		var _width  = sprite_get_width(_sprite);
		var _height = sprite_get_height(_sprite);
		var _count  = sprite_get_number(_sprite);
		var _start  = __current_snip.frame_start;
		var _end    = __current_snip.frame_end;
		var _index  = floor(image_index);
	
		// Visual debug settings
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
	
		// Draw each sprite frame
		for (var i = 0; i < _count; i++)
		{
			var _x1 = _x + (i * _width) + (_separation * i);
			var _x2 = _x1 + _width;
			var _y1 = _y;
			var _y2 = _y + _height;
		
			draw_set_alpha((i >= _start && i <= _end) ? 1 : _transparent_amount);
		
			if (i == _index)
			{
				_y2 += _current_frame_offset;
			}
		
			draw_set_color(_back_color);
			draw_rectangle(_x1, _y1, _x2, _y2, false);
			draw_sprite(_sprite, i, _x1 + _sprite_x_axis, _y1 + _sprite_y_axis);
		
			// Draw frame callback indicator
			var _callbacks = __current_snip.__frame_callback;
			if (i - _start < array_length(_callbacks) && i - _start >= 0)
			{	
				if (_callbacks[i - _start] != undefined)
				{
					draw_set_color(_frame_script_color);
					draw_ellipse(_x1 + (_width / 2), _y1 + _height, _x1 + (_width / 2) + 5, _y1 + _height + 5, false);
				}
			}
		}
	
		draw_set_alpha(1);
		
		// Draw progress bar for the current frame
		var _px1 = _x + (_index * _width) + (_separation * _index);
		var _px2 = _px1 + (_width * (image_index - _index));
		var _py1 = _y + _height + 1;
		var _py2 = _py1 + _current_frame_offset - 1;
		draw_set_color(_progress_bar_color);
		draw_rectangle(_px1, _py1, _px2, _py2, false);
	
		// Draw loop indicators
		for (var i = 0; i < array_length(__current_snip.__loops); i++)
		{
			var _loop = __current_snip.__loops[i];
			var _is_current_loop = (_loop == __current_loop);
			
			if (_loop.iterations > 0)
			{
				draw_set_color(_is_current_loop ? _loop_current_color : _loop_color);
				draw_set_alpha(_loop_alpha);
			}
			else
			{
				draw_set_alpha(_no_loop_alpha);
				draw_set_color((_loop.iterations < 0) ? _loop_none_color : _loop_zero_color);
			}
		
			var _sx1 = _x + ((_loop.start_frame + _start) * _width) + (_separation * (_loop.start_frame + _start));
			var _sx2 = _sx1 + _loop_line_size;
			var _ex1 = _x + ((_loop.end_frame_exclusive + _start) * _width) - (_loop_line_size * 2) + ((_loop.end_frame_exclusive + _start) * _separation) - 1;
			var _ex2 = _ex1 + _loop_line_size;
			var _ly1 = _y + _height + 1;
			var _ly2 = _ly1 + ((i + 1) * _loop_line_size) + (i * _separation) + _current_frame_offset;
			
			draw_rectangle(_sx1, _ly1, _sx2, _ly2 - 1, false);
			draw_rectangle(_ex1, _ly1, _ex2, _ly2 - 1, false);
			draw_rectangle(_sx1, _ly2, _ex2, _ly2 + _loop_line_size - 1, false);
		}
	
		draw_set_color(_old_color);
		draw_set_alpha(_old_alpha);
	}
	
	#endregion
}

script_execute(AEPlayer);