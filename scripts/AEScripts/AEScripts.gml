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

///@desc Clones all the Transitions associated with the source and applies them to the destination as well (clears all previous Transitions in the destination)
///@param {Struct.AESnip} source      The Snip with the Transitions 
///@param {Struct.AESnip} destination The Snip that you want to clone the Transitions to
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
///@param {Struct.AESnip} source      The Snip to copy the Loops from
///@param {Struct.AESnip} destination The Snip to copy the Loops to
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