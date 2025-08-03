// Feather ignore all

#macro __AE_DEBUG true

#macro AE_DIR_FORWARD 1
#macro AE_DIR_BACKWARD -1

/// @desc Defines how a Snip should behave when it finishes playing.
enum AE_EndType
{
    Stop,         // Freeze on the completed frame.
    StopHead,     // Jump back to the first frame and freeze.
    StopTail,     // Jump to the last frame and freeze.
    Replay,       // Jump back to the start and play again (DEFAULT).
    Pingpong,     // Reverse direction. Transitions on either end.
    PingpongHead, // Reverse direction. Only transitions when back at the start.
    PingpongTail  // Reverse direction. Only transitions when at the end.
}

///@desc Clones all transitions from a source Snip to a destination Snip.
///@param {Struct.AESnip} source_snip The Snip to copy transitions from.
///@param {Struct.AESnip} destination_snip The Snip to copy transitions to.
function aesnips_clone_transitions(_source_snip, _destination_snip)
{
    #region Check
    if (__AE_DEBUG) {
        if (!is_struct(_source_snip)) throw "aesnips_clone_transitions() Error: Source Snip is undefined.";
        if (!is_struct(_destination_snip)) throw "aesnips_clone_transitions() Error: Destination Snip is undefined.";
    }
    #endregion
    
    // Clone incoming transitions
    array_foreach(_source_snip.__incoming_transitions, method({ dest: _destination_snip }, function(_transition) {
        new AETransition(_transition.GetFromSnip(), dest, _transition.GetTransitionSnip());
    }));
    
    // Clone outgoing transitions
    array_foreach(_source_snip.__outgoing_transitions, method({ dest: _destination_snip }, function(_transition) {
        new AETransition(dest, _transition.GetToSnip(), _transition.GetTransitionSnip());
    }));
}

///@desc Clones all loops from a source Snip to a destination Snip.
///@param {Struct.AESnip} source_snip The Snip to copy loops from.
///@param {Struct.AESnip} destination_snip The Snip to copy loops to.
function aesnips_clone_loops(_source_snip, _destination_snip)
{
    #region Check
    if (__AE_DEBUG) {
        if (!is_struct(_source_snip)) throw "aesnips_clone_loops() Error: Source Snip is undefined.";
        if (!is_struct(_destination_snip)) throw "aesnips_clone_loops() Error: Destination Snip is undefined.";
    }
    #endregion
    
    array_foreach(_source_snip.__loops, method({ dest: _destination_snip }, function(_loop) {
        // Ensure the loop is valid within the destination snip's frame range
        if (_loop.GetEndFrame() < dest.frame_count)
        {
            new AELoop(dest, _loop.GetStartFrame(), _loop.GetEndFrame(), _loop.GetIterations());
        }
    }));
}

///@desc Pauses the entire snip system.
function aesnips_global_pause()
{
    AEPlayer.g_paused = true;
}

///@desc Resumes the entire snip system.
function aesnips_global_resume()
{
    AEPlayer.g_paused = false;
}

//================================================
#region Factory Functions
//================================================

///@desc Creates and returns a new AEPlayer instance.
function aesnips_create_player()
{
    return new AEPlayer();
}

///@desc Creates and returns a new AESnip instance.
///@param {Asset.GMSprite} sprite The sprite to use for the snip.
///@param {Real} speed The speed that the snip will play at.
///@param {Real} [start_frame=0] Optional argument to create a snip from a subsection of a sprite.
///@param {Real} [end_frame] Optional argument, defaults to the last frame of the sprite.
///@param {Enum.AE_EndType} [end_type=AE_EndType.Replay] How the Snip behaves when it finishes.
///@param {Struct.AESnip} [successor] A Snip to play after this one finishes.
function aesnips_create_snip(_sprite, _speed, _start_frame, _end_frame, _end_type=AE_EndType.Replay, _successor=undefined)
{
    // Pass all arguments to the constructor, including optional ones
    return new AESnip(argument[0], argument[1], argument[2], argument[3], argument[4], argument[5]);
}

///@desc Creates a new loop within a snip.
///@param {Struct.AESnip} parent_snip The snip that the loop will be a part of.
///@param {Real} start_frame The frame that the loop starts at (inclusive).
///@param {Real} end_frame The frame that the loop will end at (inclusive).
///@param {Real} iterations How many times to repeat after playing once.
function aesnips_create_loop(_parent_snip, _start_frame, _end_frame, _iterations)
{
    return new AELoop(_parent_snip, _start_frame, _end_frame, _iterations);
}

///@desc Creates a new transition between two snips.
///@param {Struct.AESnip} from_snip The snip the transition is coming from.
///@param {Struct.AESnip} to_snip The snip the transition is going to.
///@param {Struct.AESnip} transition_snip The snip that should be played as the transition.
function aesnips_create_transition(_from_snip, _to_snip, _transition_snip)
{
    return new AETransition(_from_snip, _to_snip, _transition_snip);
}

#endregion
