// Feather ignore all
/// @desc A SnipPlayer is a struct that allows Snips to be played withouth being attached to any object and without relying on object properties like image_index or image_speed
function AEPlayer() constructor
{
	#region Globar variables
	/// @ignore Global pause
	static gPaused = false;
	
	#endregion
	
	#region Instance variables
	/* ! Changing these values directly from other parts of the code could cause big problems ! */
	/* ! Please use the given Arbiter functions unless you know what you're doing ! */
	//These are all instance variables for the SnipPlayer
	/// @ignore The snip that is currently playing
	currentSnip = undefined;
	/// @ignore The loop that the Snip is currently playing
	currentLoop = undefined;
	/// @ignore The current loop index
	currentLoopIndex = 0;
	/// @ignore The frame that the Snip is currently on
	currentFrame = -1;
	/// @ignore The snip that is set to play when the current snip finishes
	nextSnip = undefined;
	/// @ignore Whether or not the object playing the snip is paused
	isPaused = false;
	/// @ignore Whether or not the snip should has been frozen on the last frame
	isFrozen = false;
	/// @ignore Whether or not the snip should try to transition to the next snip
	shouldTransition = false;
	/// @ignore If a transition is splaying then this will hold the snip that the snip is supposed to transitioning to
	currentTarget = undefined;
	/// @ignore How many times this loop has been repeated as the current snip is playing
	loopPerformances = [];
	/// @ignore 
	loopPerformancesIndex = 1;
	
	/// @ignore The direction (forwards:1 or backwards:-1) that the current Snip is being played at
	snipDirection = AE_DIR_FORWARD;
	
	/// @ignore Whether or not the Snip has changed since the last step
	playerChanged = false;
	/// @ignore The frame of the sprite that should be drawn
	imageIndex = 0;
	/// @ignore The final speed that the Snip should be played at
	imageSpeed = 0;
	/// @ignore The sprite index
	spriteIndex = -1;
	
	/// @ignore Step event
	step = time_source_create(time_source_game, 1, time_source_units_frames, method(self, update), [], -1);
	time_source_start(step);
	
	#endregion
	
	#region Control
	
	/// @desc Call once every step to ensure that the Snip player is updating
	/// @ignore
	static update = function()
	{
		var _epsilon = math_get_epsilon();
		
		/// Feather disble all
		//Quit if there is no snip
		if (currentSnip == undefined) exit;
		
		//Continue with the script if there is an snip playing
		//Should be placed in the Step Event for each object that uses the snip system
		var _snip  = currentSnip; //Get the snip that is currently playing
		var _index = imageIndex;  //Get the current image index
		var _start = currentSnip.frameStart;
		var _end   = currentSnip.frameEnd;
		
		//Whether or not the Snip is being played forward
		var _forward = (snipDirection * _snip.direction * _snip.speed) > 0;
		//The frame speed for the Snip based on the index and start
		var _speed = _snip.frameSpeed[(_index - _start)];
	
		//Adjust the speed of the sprite depending on the following values
		//Frame Speed - Snip Speed - Snip Direction - Individual snip paused? - Individual Snip stopped? - All snips paused?
		imageSpeed = _speed           // The speed for the current snip's current frame
					* _snip.speed     // The speed for the whole current snip
					* _snip.direction // Whether the Snip wants to be played forwards or backwards
					* snipDirection   // Whether the Snip is being played forwards or backwards by the SnipPlayer
					* !isPaused       // If the snip is paused then this is 0, if not then it's 1
					* !isFrozen       // If the snip is frozen at the end of an snip
					* !gPaused;       // If the snip system as a whole is paused

		//Find out what frame the Snip will be on next frame
		var _nframe = _index + ( imageSpeed * _snip.speedScale);
		
		#region Check to see if the Snip's next frame will go past the end or the start
		if ( ((_nframe >= _end + 1 - _epsilon) && _forward) || (_nframe <= _start && !_forward) )
		{
			//Call the Snip End Event Script to simulate the end of a sprite animating
			animationEnd();
			//Break out of this step script and restart next frame
			exit;
		}
		
		#endregion
		
		#region Before anything happens see if the snip is on a new frame
		if (floor(currentFrame) != floor(imageIndex - _start) || playerChanged)
		{
			//Make sure there is an Snip playing
			if (_snip != undefined)
			{
				// Get the script for the current frame (undefined if there is no script)
				var _script = _snip.frameCallback    [imageIndex - _start];
				var _arg    = _snip.frameCallbackArgs[imageIndex - _start];  //Get the argument set for the script
		
				// Check to see if there is a script to execute
				if (_script != undefined)
				{
					// If the script is a method then execute it like a method
					if (is_method(_script) )
					{
						method_call(_script, _arg);
					}
					// If not, then execute it like a script
					else
					{
						script_execute(_script, _arg);
					}
				}
			}
			
			// Reset the Snip change variable
			playerChanged = false;
		}
		
		#endregion
		
		//This has to happen after checking whether or not a Snip is on a new frame
		currentFrame = _index - _start; //Set the current frame to the image index

		// Only do this Snip logic if both the snip and the snip system are not paused
		if (gPaused) exit;
		if (!isPaused && !isFrozen)
		{
			// If the snip has more than 0 loops
			var _sloops  = _snip.loops;
			var _sloopsL = array_length(_sloops); 
			if (_sloopsL > 0)
			{
				#region If the object isn't currently playing a loop
				if (currentLoop == undefined)
				{
					//Loop through all the Snip's Loops
					var i=0; repeat(_sloopsL)
					{
						//Get the current loop
						var _current_loop = _sloops[i];
						//{bool} Find out if the current index is within the start and end of the loop
						var _is_within_loop = (_index - _start >= _current_loop.fstart) && (_index - _start < _current_loop.fend);
						//{bool} Find out whether or not the loop has already been performed the proper number of times
						var _loop_done_performing = (loopPerformances[i] >= _current_loop.iterate);
						//{bool} Find out if the system should just completely skip the loop
						var _loop_should_skip = (_current_loop.iterate < 0 && loopPerformances[i] <= 0);
					
						//No use the three bool variables to handle looping the snip properly
						if (_is_within_loop && (!_loop_done_performing || _loop_should_skip))
						{
							//If the loop should be skipped then skip it
							if (_loop_should_skip)
							{
								//Tell the loop that is has been performed
								loopPerformances[i] += 1;
							
								// If the Snip is being played forward
								if (_forward)
								{
									//Jump to the end of the loop and skip everything inside the loop
									imageIndex = _current_loop.fend - _start;
								}
								else //If the Snip is being played backward
								{
									//Jump to the end of the loop and skip everything inside the loop
									imageIndex = _current_loop.fstart - _start - _epsilon;
								}
								break; //Break out of the repeat()
							}
							else //The loop should not skip
							{
								//Set the object's currently playing loop
								currentLoop = _current_loop;
								currentLoopIndex = i;
								break; //Break out of the repeat()
							}
						}
						// Don't forget to increment the counter!
						i += 1;
					}
				}
				
				#endregion
				
				#region If the Snip is currently in the middle of a loop
				else 
				{
					//Get the loop that is currently being played
					var _currently_playing_loop = currentLoop;
				
					//If the Snip has played past the end of the Loop
					var _snip_past_end = (_index - _start >= _currently_playing_loop.fend);
					//If the Snip has played past the start of the Loop (assuming it is being played backwards)
					var _snip_past_start = (_index - _start < _currently_playing_loop.fstart);
				
					//If the Snip has reached the end of the loop (either forward or backward)
					if ((_snip_past_end  && _forward) || (_snip_past_start && !_forward) )
					{
						//Tell the loop that it has been performed by incrementing the variable
						loopPerformances[currentLoopIndex] += 1;
					
						//If the Snip is being played forward
						if (_forward)
						{
							//Set the current image index to the start of the Loop
							imageIndex = _currently_playing_loop.fstart + _start;
						}
						else
						{
							//Set the current image index to the end of the Loop
							imageIndex = _currently_playing_loop.fend + _start - _epsilon;
						}
					
						//If the loop has been repeated the proper number of times
						//Tell the object that it is no longer inside that loop
						if (loopPerformances[currentLoopIndex] >= _currently_playing_loop.iterate)
						{
							//Reset the current loop variable
							currentLoop = undefined;
							currentLoopIndex = -1;
						}
					}
				}
			
				#endregion
			}
			
			//Now change the image index to the next frame
			imageIndex += imageSpeed * _snip.speedScale;
		}
	}
	
	/// @desc Mimic's the animation end event
	/// @ignore
	static animationEnd = function()
	{
		//If there's not a Snip playing then just return false and skip the rest of the function
		if (currentSnip == undefined) exit;
		var _epsilon = math_get_epsilon();
		
		#region If the Snip is currently in the middle of a loop
		if (currentLoop != undefined)
		{
			//Whether or not the Snip is being played forward
			var _snip_forward = (currentSnip.direction * snipDirection >= 0);
			//The starting frame of the Snip
			var _start = currentSnip.frameStart;
		
			//Tell the loop that it has been performed by incrementing the variable
			loopPerformances[loopPerformancesIndex] += 1;
			
			//If the Snip is being played forward
			if (_snip_forward)
			{
				//Set the current image index to the start of the Loop
				imageIndex = currentLoop.fstart + _start;
			}
			else
			{
				//Set the current image index to the end of the Loop
				imageIndex = currentLoop.fend + _start - _epsilon;
			}
			
			//If the loop has been repeated the proper number of times
			//Tell the object that it is no longer inside that loop
			if (loopPerformances[currentLoopIndex] >= currentLoop.iterate)
			{
				//Reset the current loop variable
				currentLoop = undefined;
				currentLoopIndex = -1;
			}
		
			//Return to skip the rest of the function
			exit;
		}
		
		#endregion
		
		/* We know a Snip is playing */
		#region If the Snip's end type is a pingpong head, we reverse the animation speed and skip the rest
		if (currentSnip.endType = AE_EndType.pingpongHead)
		{
			//Check to see if the Snip is playing forwards
			if (currentSnip.speed * currentSnip.direction * snipDirection > 0)
			{
				//Set the image_index to the last frame possible
				imageIndex = currentSnip.frameEnd + (1 - _epsilon);
				
				//Tell the player to start playing the Snip in the opposite direction
				snipDirection = -snipDirection;
				
				//Reset the loops
				resetLoops(currentSnip);
				
				return; // Return so the Snip never actually "completes"
			}
		}
		
		#endregion
		
		#region If the Snip's end type is a pingpong tail, we reverse the animation speed and skip the rest
		else if (currentSnip.endType = AE_EndType.pingpongTail)
		{
			//Check to see if the Snip is playing backwards
			if (currentSnip.speed * currentSnip.direction * snipDirection < 0)
			{
				//Make sure to jump to the start
				imageIndex = currentSnip.frameStart; //Reset the image_index to the start 
				//Tell the player to start playing the Snip in the opposite direction
				snipDirection = -snipDirection;
				//Reset the loops
				resetLoops(currentSnip);
				return; //Return so the Snip never actually "completes"
			}
		}
		
		#endregion
		
		// If there is a script/method to execute then allow execute it
		if (currentSnip.completeScript != undefined)
		{
			//If the script is a method
			var _fun = currentSnip.completeScript, _args = currentSnip.completeScriptArgs;
			
			// Execute it as a method with the argument
			if (is_method(_fun) )
			{
				method_call(_fun, _args);
			}
			// If it's not a method
			else
			{
				// Execute it as a script with the argument
				script_execute(_fun, _args);
			}
		}
	
		//If there's a next snip that should be played and it's not the same snip
		if (nextSnip != currentSnip && nextSnip != undefined)
		{
			//Play the snip and use the transition if desired
			play(nextSnip, shouldTransition)
		}
		else
		{
			#region If there isn't a next snip to play then look for a successor to the current snip
			if (nextSnip == undefined)
			{
				//Get the follow-up Snip and should_transition value
				var _follower = currentSnip.successor;
				var _follower_transition = currentSnip.successorTransition;
			
				//If there is a follow-up Snip
				if (_follower != undefined)
				{
					//Then play it immediately with the snip's successor transition variable
					play(_follower, _follower_transition);
				}
				else
				{
					switch (currentSnip.endType)
					{
						case AE_EndType.replay:   #region Replay
							//If the Snip is being played forwards
							if (currentSnip.direction * snipDirection >= 0)
							{
								//Just loop the Snip by going back to the start
								imageIndex = currentSnip.frameStart; //Reset the image_index to the start 
							}
							else //If the Snip is being played backwards
							{
								//Just loop the Snip by going to the end of the final frame (as close to snip_frame_end+1 as possible)
								imageIndex = currentSnip.frameEnd + (1 - _epsilon);
							}
							currentFrame     = imageIndex;  // Set the current frame to the image index
							currentLoop      = undefined;   // Reset the loop value
							currentLoopIndex = -1;          // Reset the loop index
							playerChanged = true;           // Tell the object that the snip has changed because it has looped back
							resetLoops(currentSnip); // Reset the loops
						break; #endregion
						
						case AE_EndType.stop:     #region Stop
							imageSpeed   = 0;          // Freeze the image_speed so it stays on that index
							currentFrame = imageIndex; // Set the current frame to the image index
							isFrozen     = true;       // Freeze the Snip so it won't keep repeating
						break; #endregion
						
						case AE_EndType.stopTail: #region Stop tail
							//Set the Snip to the very last frame
							imageIndex = currentSnip.frameEnd; // Make sure the image is on the last frame 
							imageSpeed = 0;                    // Freeze the image_speed so it stays on that index
							currentFrame = imageIndex;         // Set the current frame to the image index
							isFrozen = true;                   // Freeze the Snip so it won't keep repeating
						break; #endregion
						
						case AE_EndType.stopHead: #region Stop Head
							//Jump back to the first frame and freeze
							imageIndex = currentSnip.frameStart; // Make sure the image is on the first frame 
							imageSpeed = 0;                      // Freeze the image_speed so it stays on that index
							currentFrame = imageIndex;           // Set the current frame to the image index
							isFrozen = true;                     // Freeze the Snip so it won't keep repeating
						break; #endregion
						
						case AE_EndType.pingpong:
						case AE_EndType.pingpongHead:
						case AE_EndType.pingpongTail: #region pingpong (Head && Tail)
							var _is_forward = (currentSnip.speed * currentSnip.direction * snipDirection) > 0;
							// Reset the image_index to the start or set the image_index to the last frame possible
							imageIndex    = (!_is_forward) ? currentSnip.frameStart : currentSnip.frameEnd + (1 - _epsilon);
							// Reverse the direction that the SnipPlayer is playing the Snip at
							snipDirection = -snipDirection; 
							
							//Clear the image speed
							imageSpeed   = 0;
							//Reset the Snip's current frame
							currentFrame = imageIndex; //Set the current frame to the image index
							//Reset the loops
							resetLoops(currentSnip);
							
						break; #endregion
					}
				}
			}
			
			#endregion
			
			// If the Snip should just play itself again
			else
			{
				play(currentSnip, false);
			}
		}
	}

	///@desc Returns the snip that is currently playing (or undefined if none)
	static current = function()
	{
		return (currentSnip);
	}

	/// @desc Destroy the time-source of this AEPlayer
	static destroy = function()
	{
		time_source_destroy(step);
	}
	
	#endregion
	
	#region Drawing functions
	
	/// @desc Draws the SnipPlayers currently playing Snip at the given location
	/// @param {Real} x The x position to draw at
	/// @param {Real} y The y position to draw at
	static draw = function(_x,_y)
	{
		//Ask to make sure the SnipPlayer is actually playing a Snip
		if (currentSnip != undefined)
		{
			var _sprite = currentSnip.sprite;
			//Draw the sprite if there is a sprite
			if (_sprite != undefined) draw_sprite(_sprite, imageIndex, _x, _y);
		}
	}
	
	/// @desc Draws the SnipPlayers currently playing Snip at the given location
	/// @param {Real}            x         The x position to draw at
	/// @param {Real}            y         The y position to draw at
	/// @param {Real}            xscale    The x scale to draw with
	/// @param {Real}            yscale    The y scale to draw with
	/// @param {Real}            rotation  The angle to draw at
	/// @param {Constant.Color}  color     The color to draw with
	/// @param {Real}            alpha     The alpha to draw with
	static drawExt = function(_x, _y, _xscale, _yscale, _rotation, _color, _alpha)
	{
		//Ask to make sure the SnipPlayer is actually playing a Snip
		if (currentSnip != undefined)
		{
			var _sprite = currentSnip.sprite;
			//Draw the sprite if there is a sprite
			if (_sprite != undefined) draw_sprite_ext(_sprite, imageIndex, _x, _y, _xscale, _yscale, _rotation, _color, _alpha);
		}
	}

	/// @desc Draws a visual representation of the Snip that an Object is currently playing
	/// @param {real} x The x position to draw the debug panel
	/// @param {real} y The y position to draw the debug panel
	/// @ignore
	static drawDebug = function(_x,_y)
	{	
		//Get the draw values so that it can be reset at the end of the function
		var _old_color = draw_get_color();
		var _old_alpha = draw_get_alpha();
	
		//The first step is to quit with a red box if there is no Snip associated with the object
		if (currentSnip == undefined)
		{
			draw_set_color(c_red);
				draw_rectangle(_x,_y, _x+16, _y+16, false);
			draw_set_color(_old_color);
			exit;
		}
	
		//The next step is to get all the relevant information from the currently playing Snip
		var _sprite = currentSnip.sprite;
		var _width  = sprite_get_width(_sprite);
		var _height = sprite_get_height(_sprite);
		var _count  = sprite_get_number(_sprite);
		var _start  = currentSnip.frameStart;
		var _end    = currentSnip.frameEnd;
		var _index  = floor(imageIndex);
	
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
			var _callbacks = currentSnip.frameCallback;
			if (_i - _start < array_length(_callbacks)
			and _i - _start >= 0)
			{	
				var _frame = _callbacks[_i - _start];
				if (_frame != undefined)
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
		var _px2 = _px1 + (_width * (imageIndex - _index));
		var _py1 = _y + _height + 1;
		var _py2 = _py1 + _current_frame_offset - 1;
		draw_set_color(_progress_bar_color);
		draw_rectangle(_px1, _py1, _px2, _py2, false);
	
		//Now draw the Loops in the Snip
		//First, draw the base loops
		_i = 0;
		repeat(array_length(currentSnip.loops))
		{
			//Get the loop
			var _loop = currentSnip.loops[_i];
		
			//If the loop should repeat
			if(_loop.iterate > 0)
			{
				draw_set_color(_loop_color);
			
				if (_loop == currentLoop)
				{
					draw_set_color(_loop_current_color);
				}
			
				draw_set_alpha(_loop_alpha);
			}
			else
			{
				draw_set_alpha(_no_loop_alpha);
				//If the loop should skip
				if (_loop.iterate < 0)
				{
					draw_set_color(_loop_none_color);
				}
				else //If the loop should play without repeating
				{
					draw_set_color(_loop_zero_color);
				}
			
			}
		
			//Get the values for the start vertical line
			var _sx1 = _x + ((_loop.fstart + _start) * _width) + (_separation * (_loop.fstart + _start));
			var _sx2 = _sx1 + _loop_line_size;
			
			//Get the values for the end vertical line
			var _ex1 = _x + ((_loop.fend + _start) * _width) - (_loop_line_size*2) + ((_loop.fend + 1 + _start) * _separation) - 1;
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
	
	#region Playback functions
	
	///@desc Immediately plays the given snip with or without transition
	///@param {Struct.AESnip} Snip       The Snip that the SnipPlayer should play
	///@param {bool} [should_transition] Whether or not the SnipPlayer should try to find a transition between the current snip and the snip to play
	static play = function(_snip, _shouldTransition=false)
	{
		//Unfreeze the Snip any time a new Snip is played
		isFrozen = false;
		
		//Reset the direction that the player should play the Snip at
		snipDirection = 1;
	
		//If the given Snip is different than the current Snip, set the Snip as changed
		if (_snip != currentSnip) playerChanged = true;
		
		//By default use the given snip as the Snip to play
		var _play_snip = _snip;
		//By default there should be no next Snip
		var _next_snip = undefined;
	
		//If the system should search for a transition and there is an snip currently playing
		if (_shouldTransition && currentSnip != undefined)
		{
			//When looking for the transition use the current Snip as the "from"
			var _from = currentSnip;
		
			//If the Snip is currently transitioning to another Snip then use the target as the "from"
			if (currentTarget != undefined) _from = currentTarget;
			
			//Reset the target variable here
			currentTarget = undefined;
		
			//Try to find a transition snip to play
			var _transition = findTransition(_from, _snip);
		
			//If a transition was found then do not use the given snip, use the transition snip
			if (_transition != undefined)
			{
				//Set the play snip to the transition's use snip
				_play_snip = _transition.transition;
				//Tell the system to play the given snip after the transition snip is done
				_next_snip = _snip;
				//Save the target of the transition into the target variable
				currentTarget = _snip;
			}
		}
		else //If the system should not search for a transition then clear the target
		{
			currentTarget = undefined;
		}
	
		currentSnip = _play_snip; //Set the current snip
		nextSnip    = _next_snip; //Reset the next snip
		currentLoop = undefined; //Reset the current loop
		// Set the proper sprite index
		spriteIndex = _play_snip.sprite; 
	
		//If the next Snip will be played forwards
		var _epsilon = math_get_epsilon();
		imageIndex = (_play_snip.direction >= 0) ? _play_snip.frameStart :  currentSnip.frameEnd + (1 - _epsilon);
		imageSpeed = 0;
		
		currentFrame = imageIndex;
	
		//Reset all the loop counters in the object
		if (currentSnip != undefined) resetLoops(currentSnip);
		
		return self;
	}
	
	///@desc Sets an snip to play as soon as the current snip is done playing
	///@param {Struct.AESnip} Snip    The snip to play
	///@param {bool} shouldTransition Whether or not the system should try to find a transition between the current snip and the snip to play
	static playNext = function(_snip, _shouldTransition=false)
	{
		//If there isn't an Snip playing right now
		if (currentSnip == undefined || isFrozen)
		{
			//Just play the snip now
			play(_snip, _shouldTransition);
		}
		else
		{
			//Set the snip to play on the Snip End
			nextSnip = _snip;
			shouldTransition = _shouldTransition;
		}
		
		return self;
	}

	///@desc Only plays the given Snip if it is not already playing
	///@param {Struct.AESnip} Snip      The Snip you would like to play
	///@param {bool} [shouldTransition] Whether or not to Transition when playing the Snip
	static playRequest = function(_snip, _shouldTransition=false)
	{
		//Only play the Snip if it is not currently playing
		if (!isPlaying(_snip, true) ) play(_snip, _shouldTransition);
		return self;
	}

	/// @desc Returns the snip that will play after the current snip finishes (undefined if none or if the Snip will freeze)
	static getNext = function()
	{
		//If there is a next snip then immediately return it and ignore everything else
		if (nextSnip != undefined) return nextSnip;
	
		//If there's not even an snip playing then return nothing
		var _current = currentSnip;
		if (currentSnip != undefined)
		{
			var _follower = currentSnip.successor;  // The successor or precursor depending on whether or not a Snip is playing forwards or backwards 
			var _follower_transition = currentSnip.successorTransition; // Whether or not to use the transition
			
			if (_follower != undefined)
			{
				//Check to see if it should use a transition
				if (_follower_transition)
				{
					// Try to find transition
					var _transition = findTransition(currentSnip, _follower);
					// Return the transition if one was found or If no transition was found then return the follower
					return (_transition != undefined) ? _transition.use : _follower;
				} 
				// If it should ignore transitions then return the follower
				else
				{
					return _follower;
				}
			}
			
			if (currentSnip.endType != AE_EndType.stop) return currentSnip;
		}
		
		return undefined;
	}
	
	///@desc This will cancel the Snip that the object has queued to play next
	static cancelNext = function()
	{
		//If the Snip is transitioning then the current target will have a Snip
		//So this will play the Snip that is being transitioned to
	
		//But if the Snip is not transitioning then the current target will be undefined
		//So this will clear the next Snip value
		nextSnip = currentTarget;
		shouldTransition = false;
		
		return self;
	}
	
	///@desc Resets the performance count in all the loops in the given snip
	///@param {Struct.AESnip} Snip The snip that the loops are a part of
	static resetLoops = function(_snip)
	{
		//Clear out the performance array
		loopPerformances = array_create(array_length(_snip.loops), 0);
		
		return self;
	}

	///@desc Stops the Snip that the object is currently playing and keep it on the same frame
	static stop = function()
	{
		isFrozen = true;           // Freeze the Snip so it stops completely
		
		imageSpeed   = 0;          // Freeze the image_speed so it stays on that index
		currentFrame = imageIndex; // Set the current frame to the image index
		
		return self;
	}

	///@desc Stops the Snip that the object is currently playing and jumps to the last frame (as if the end_type is end_stop)
	static stopTail = function()
	{
		isFrozen = true;                    // Freeze the Snip so it won't keep repeating
		
		//Set the Snip to the very last frame
		imageIndex = currentSnip.frameEnd; // Make sure the image is on the last frame 
		imageSpeed = 0;                    // Freeze the image_speed so it stays on that index
		currentFrame = imageIndex;         // Set the current frame to the image index
		
		return self;
	}
	
	///@desc Stops the Snip that the object is currently playing and reloads it to the first frame (as if the end_type is end_stop_beginning)
	static stopHead = function()
	{
		isFrozen = true;                     // Freeze the Snip so it won't keep repeating
		
		//Jump back to the first frame and freeze
		imageIndex = currentSnip.frameStart; // Make sure the image is on the first frame 
		imageSpeed = 0;                      // Freeze the image_speed so it stays on that index
		currentFrame = imageIndex;           // Set the current frame to the image index
		
		return self;
	}

	///@desc Pauses the Snip that the object is currently playing
	static pause = function()
	{
		isPaused = true;
		return self;
	}

	///@desc Un-pauses the Snip that the object is currently playing
	static resume = function()
	{
		isPaused = false;
		return self;
	}
	
	///@desc Returns whether or not the given snip is currently playing (or if a transition to the snip is playing depending on the second parameter)
	///@param {Struct.AESnip} Snip   The Snip to check
	///@param {bool} checkTransition Whether or not to check if the current Snip is transitioning to the given snip
	static isPlaying = function(_snip, _target)
	{
		return ((currentSnip == _snip && !isFrozen) || (currentTarget == _snip && _target));
	}

	///@desc Returns a transition snip between the from snip and the to snip (or undefined if none exists)
	///@param {Struct.AESnip} from The snip that the transition comes from
	///@param {Struct.AESnip} to   The snip that the transition comes from
	static findTransition = function(_from, _to)
	{
		// The list to loop through to try to find the snip
		var _useArray = _from.outTransitions;
		// Get the size of the from's outgoing list
		var _outSize  = array_length(_useArray);
		// Get the size of the to's incoming list
		var _inSize   = array_length(_to.incTransitions);
		// If the from list is smaller than the in list search through the to's incoming transitions 
		if (_outSize < _inSize) _useArray = _to.incTransitions;
	
		//Loop through the from list or the to list
		var i=0; repeat(array_length(_useArray) )
		{
			//Get the current snip in the list
			var _current_transition = _useArray[i];
			if (_current_transition.from == _from && _current_transition.to == _to)
			{
				//Return the transition's use snip if it matches the from and the to
				return _current_transition;
			}
		
			i += 1;
		}
	
		//If no transition has been found then return undefined
		return undefined;
	}

	///@desc Immediately goes to the given frame in the current snip and may or may not reset loops
	///@param {Real} frame      The frame index to go to
	///@param {Bool} resetLoops Whether or not to reset the loops in the current snip and play them again or not
	static toFrame  = function(_frame, _reset=false)
	{
		#region Check
		if (__AE_DEBUG) {
		if (_frame > currentSnip.frameCount || _frame < 0) {
			var _str = string("The given frame index [{0}] is outside the bounds of the given Snip with [{1}] frames", _frame, currentSnip.frameCount);
			throw(_str);
		} } #endregion
		// Reiniciar
		if (_reset) resetLoops(currentSnip);
		var _start = currentSnip.frameStart, _end = currentSnip.frameEnd;
		imageIndex = _start + _frame;
		// Limitar valor
		if (imageIndex >   _end) {imageIndex = _start; } else
		if (imageIndex < _start) {imageIndex =   _end; } 
		
		return self;
	}
	
	/// @desc Get the current frame
	static getFrame = function()
	{
		return (imageIndex);
	}
	
	/// @desc Returns the number of times the current loop has left to play (0 if not in a loop)
	/// @return {Real}
	static remainingLoops = function()
	{
		return (is_undefined(currentLoop) ) ? 
			0 : currentLoop.iterate - loopPerformances[loopPerformancesIndex];
	}

	/// @desc Returns the given sprite index as the given Snip's frame index
	/// @param {Real} index The sprite index number to convert into a Snip frame index
	/// @return {Real}
	static asFrame = function(_index)
	{
		return (_index - currentSnip.frameStart);
	}

	/// @desc Returns the given Snip frame as the sprite image index
	/// @param {Real} frame The frame number within the given Snip to get the index of
	/// @return {Real}
	static asIndex = function(_frame)
	{
		return (_frame + currentSnip.frameStart);
	}


	#endregion
}