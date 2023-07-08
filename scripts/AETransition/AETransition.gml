// Feather ignore all
///@desc Creates a new transition between "from" and "to" using the given snip 
///@param {Struct.AESnip} from The snip that the transition is coming from
///@param {Struct.AESnip} to   The snip the the transition is going to
///@param {Struct.AESnip} transition The snip that should be played as the transition
function AETransition(_from, _to, _transition) constructor
{
	// Set up the values for the Transition
	/// @ignore The snip it is coming from
	from = _from; 
	/// @ignore The snip it is going to
	to   = _to;
	/// @ignore The snip that will play as the transition
	transition = _transition; 
	
	//Add this transition to the incoming and outgoing lists of the snips
	array_push(  _to.incTransitions, self);
	array_push(_from.outTransitions, self);
	
	#region Methods
	/// @desc Destroys the transition and removes it from the incoming and outgoing lists of the appropriate Snips
	static destroy = function()
	{
		static find = function(ae) {return (ae == self); }
		var _fout  = from.outTransitions;
		var _index = array_find_index(_fout, _f)
		if (_index > -1) array_delete(_fout, _index, 1)
		
		var _tiin = to.incTransitions;
		_index = array_find_index(_tiin, _f);
		if (_index > -1) array_delete(_fout, _index, 1);
	}
	
	///@desc Changes the given transition's to snip
	///@param {Struct.AESnip} to The transition to set as the new to value
	static setToSnip = function(_to)
	{
		static find = function(v) {return (v == self); }
		var _oto = to;
		// Change the transition's property
		to = _to;
		// Remove the transition from the old from snip's outgoing list
		var _index = array_find_index(_oto.incTransitions, find);
		// Eliminar del antiguo snip
		if (_index > -1) array_delete(_oto.incTransitions, _index, 1);
		
		// Add the transition
		array_push(_to.incTransitions, self);
		return self;
	}
	
	/// @desc Returns the snip that a transition is going to
	/// @return {Struct.AESnip}
	static getToSnip = function()
	{
		return (to);
	}
	
	///@desc Changes the given transition's from snip
	///@param {Struct.AESnip} from The transition to set as the new from value
	static setFrom = function(_from)
	{
		static find = function(v) {return (v == self); }
		var _ofrom = from;
		from = _from;
		// Remove the transition from the old from snip's outgoing list
		var _index = array_find_index(_ofrom.outTransitions, find);
		if (_index > -1) array_delete(_ofrom.outTransitions, _index, 1);
		
		// Add the transition to the from
		array_push(_from.outTransitions, self);
		return self;
	}
	
	///@desc Returns the snip that a transition is coming from
	///@return {Struct.AESnip}
	static getFrom = function()
	{
		return (from);
	}	
	
	///@desc Returns the snip that a transition plays
	///@return {Struct.AESnip}
	static getTransition = function()
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