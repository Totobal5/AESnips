/// @desc Create the Snip and perform events

/*
This is just a quick object to showcase the pingpong end type,
nothing fancy
*/
my_snip = new AESnip(sprite_index, 1).setFrameSpeed(0,.5, 9,.5);
my_snip.setCompletionCallback(method(id, function() {
	if (!is_method(self) ) image_angle += 5;
}) );
my_snip.setEndType(AE_EndType.pingpong);
//Adjust the end type to see how the different pingpong types change the behavior
//end_pingpong
//end_pingpong_head
//end_pingpong_tail

my_player = new AEPlayer();
my_player.play(my_snip, false);