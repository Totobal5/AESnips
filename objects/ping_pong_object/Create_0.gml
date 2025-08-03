/// @description Create the Snip and perform events

/*
This is just a quick object to showcase the pingpong end type,
nothing fancy
*/

// Create the snip using the factory function
my_snip = aesnips_create_snip(sprite_index, 1);

// Chain methods using the new PascalCase naming
my_snip.SetFrameSpeed(0, 0.5, 9, 0.5);
my_snip.SetCompletionCallback(method(id, function() {
	// The original code had this check.
	// In this context, 'self' refers to the instance 'id', which is not a method.
	if (!is_method(self)) 
	{
		image_angle += 5;
	}
}));
my_snip.SetEndType(AE_EndType.Pingpong);
// Adjust the end type to see how the different pingpong types change the behavior
// AE_EndType.Pingpong
// AE_EndType.PingpongHead
// AE_EndType.PingpongTail

// Create the player and play the snip
my_player = aesnips_create_player();
my_player.Play(my_snip, false);
