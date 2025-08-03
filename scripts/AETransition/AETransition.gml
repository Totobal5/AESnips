// Feather ignore all
/// @desc Creates a new transition between a "from" and a "to" snip.
/// @param {Struct.AESnip} from_snip The snip the transition is coming from.
/// @param {Struct.AESnip} to_snip The snip the transition is going to.
/// @param {Struct.AESnip} transition_snip The snip that should be played as the transition.
function AETransition(_from_snip, _to_snip, _transition_snip) constructor
{
    #region Private Instance Variables
    
    __from_snip = _from_snip;
    __to_snip = _to_snip;
    __transition_snip = _transition_snip;
    
    #endregion
    
    #region Initialization
    
    // Register this transition with the associated snips
    if (is_struct(__from_snip)) __from_snip.__AddOutgoingTransition(self);
    if (is_struct(__to_snip))   __to_snip.__AddIncomingTransition(self);
    
    #endregion
    
    #region Public Methods
    
    /// @desc Destroys the transition and removes it from the associated Snips.
    static Destroy = function()
    {
        // Unregister from snips
        if (is_struct(__from_snip)) __from_snip.__RemoveOutgoingTransition(self);
        if (is_struct(__to_snip))   __to_snip.__RemoveIncomingTransition(self);
    }
    
    ///@desc Changes the destination Snip for this transition.
    ///@param {Struct.AESnip} new_to_snip The new destination Snip.
    static SetToSnip = function(_new_to_snip)
    {
        // Unregister from the old snip
        if (is_struct(__to_snip)) __to_snip.__RemoveIncomingTransition(self);
        
        // Update and register with the new snip
        __to_snip = _new_to_snip;
        if (is_struct(__to_snip)) __to_snip.__AddIncomingTransition(self);
        
        return self;
    }
    
    ///@desc Changes the source Snip for this transition.
    ///@param {Struct.AESnip} new_from_snip The new source Snip.
    static SetFromSnip = function(_new_from_snip)
    {
        // Unregister from the old snip
        if (is_struct(__from_snip)) __from_snip.__RemoveOutgoingTransition(self);
        
        // Update and register with the new snip
        __from_snip = _new_from_snip;
        if (is_struct(__from_snip)) __from_snip.__AddOutgoingTransition(self);
        
        return self;
    }
    
    /// @desc Returns a string representation for debugging.
    static ToString = function()
    {
        var _from_str =		is_struct(__from_snip) ? __from_snip.ToString() : "undefined";
        var _to_str =		is_struct(__to_snip) ? __to_snip.ToString() : "undefined";
        var _trans_str =	is_struct(__transition_snip) ? __transition_snip.ToString() : "undefined";
        
		return $"Transition from [{_from_str}] to [{_to_str}] using [{_trans_str}]";
    }
    
    #endregion
    
    #region Public Getters
    
    /// @desc Returns the snip that this transition comes from.
    static GetFromSnip = function()
    {
        return __from_snip;
    }
    
    /// @desc Returns the snip that this transition goes to.
    static GetToSnip = function()
    {
        return __to_snip;
    }
    
    /// @desc Returns the snip that is played as the transition.
    static GetTransitionSnip = function()
    {
        return __transition_snip;
    }
    
    #endregion
}
