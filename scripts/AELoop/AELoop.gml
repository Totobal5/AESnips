// Feather ignore all
/// @desc Creates a loop within a snip that will repeat a given number of times.
/// @param {Struct.AESnip} parent_snip The snip that the loop will be a part of.
/// @param {Real} start_frame The frame that the loop starts at (inclusive).
/// @param {Real} end_frame The frame that the loop will end at (inclusive).
/// @param {Real} iterations How many times to repeat after playing once.
function AELoop(_parent_snip, _start_frame, _end_frame, _iterations) constructor
{
    #region Public Instance Variables (Read-Only)
    
    // The player logic treats the end frame as exclusive, so we add 1.
    start_frame =			_start_frame;
    end_frame_exclusive =	_end_frame + 1;
    iterations =			_iterations;
    
    #endregion
    
    #region Private Instance Variables
    
    __parent_snip = _parent_snip;
    
    #endregion
    
    #region Initialization
    
    // Register this loop with its parent snip
    if (is_struct(__parent_snip))
    {
        __parent_snip.__AddLoop(self);
    }
    
    #endregion
    
    #region Public Methods
    
    /// @desc Destroys the loop and removes it from its parent Snip.
    /// @warn This requires a __RemoveLoop helper method to be added to AESnip.
    static Destroy = function()
    {
        if (is_struct(__parent_snip))
        {
            __parent_snip.__RemoveLoop(self);
        }
    }
    
    /// @desc Sets the number of times the loop will repeat.
    /// @param {Real} new_iterations The number of times to repeat after it plays once.
    static SetIterations = function(_new_iterations)
    {
        iterations = _new_iterations;
        return self;
    }
    
    /// @desc Returns a string representation for debugging.
    static ToString = function()
    {
        return $"Loop from [{start_frame}] to [{end_frame_exclusive - 1}] repeating [{iterations}] times.";
    }
    
    #endregion
    
    #region Public Getters
    
    /// @desc Returns the Snip that this loop is attached to.
    static GetParentSnip = function()
    {
        return __parent_snip;
    }
    
    /// @desc Returns the number of times a loop will repeat.
    static GetIterations = function()
    {
        return iterations;
    }
    
    /// @desc Returns the starting frame of the loop.
    static GetStartFrame = function()
    {
        return start_frame;
    }
    
    /// @desc Returns the ending frame of the loop (inclusive).
    static GetEndFrame = function()
    {
        return end_frame_exclusive - 1;
    }
    
    #endregion
}
