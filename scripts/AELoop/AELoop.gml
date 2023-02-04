///@desc Creates a loop in the snip that will play once and then repeat the given number of times
///@param {Struct.AESnip} snip    The snip that the loop will be a part of
///@param {real}          start   The frame that the loop starts at (inclusive)
///@param {real}          finish  The frame that the loop will end at (inclusive)
///@param {real}          iterate How many times to repeat after playing once (0 means the loop will play once and any number less than 0 will skip the loop entirely)
function AELoop(_snip, _start, _finish, _iterate) constructor
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
