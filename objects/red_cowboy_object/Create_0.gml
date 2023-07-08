/// @description Set up the snips
//Create Snips
idle_snip = new AESnip(red_cowboy_full, .5, 0,  2,    AE_EndType.replay);
draw_snip = new AESnip(red_cowboy_full,  1, 3,  6,    AE_EndType.stopHead);
fire_snip = new AESnip(red_cowboy_full,  1, 7, 10,    AE_EndType.stopTail);
holster_snip = new AESnip(red_cowboy_full, 1, 11, 19, AE_EndType.stop);
//Set the idle Snip as the fire Snip's successor and automatically create a precursor
fire_snip.setSuccessor(idle_snip, true);
fire_snip.setFrameCallback(1, method(id, cowboy_fire_bullet), [-6]);

//Set some snips as transitions
//Add a transition between the idle snip and the firing snip
draw_transition = new AETransition(idle_snip, fire_snip, draw_snip);

//Add a transition between firing and idling
holster_transition = new AETransition(fire_snip, idle_snip, holster_snip);

//Add a loop to twirl the gun multiple times
twirl_loop = new AELoop(holster_snip, 0, 2, 3);

my_player = new AEPlayer();
my_player.play(idle_snip);