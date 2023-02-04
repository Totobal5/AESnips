/// @desc Create the Snip and perform events

/*
This is just a quick object to showcase the pingpong end type,
nothing fancy
*/
my_snip = new Snip(sprite_index, 1).setFrameSpeedExt([0,.5,  9,.5]);
my_snip.setCompletionCallback(method(id, function() {
	if (!is_method(self) ) image_angle += 5;
}) );
my_snip.setEndType(SnipEnd.pingpong);
//Adjust the end type to see how the different pingpong types change the behavior
//end_pingpong
//end_pingpong_head
//end_pingpong_tail

my_player = new SnipPlayer();
my_player.play(my_snip, false);