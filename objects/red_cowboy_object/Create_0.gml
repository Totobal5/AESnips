/// @description Set up the snips

// Create Snips using the factory functions
idle_snip = aesnips_create_snip(red_cowboy_full, 0.5, 0, 2, AE_EndType.Replay);
draw_snip = aesnips_create_snip(red_cowboy_full, 1, 3, 6, AE_EndType.StopHead);
fire_snip = aesnips_create_snip(red_cowboy_full, 1, 7, 10, AE_EndType.StopTail);
holster_snip = aesnips_create_snip(red_cowboy_full, 1, 11, 19, AE_EndType.Stop);

// Set the idle Snip as the fire Snip's successor
fire_snip.SetSuccessor(idle_snip, true);
fire_snip.SetFrameCallback(1, method(id, cowboy_fire_bullet), [-6]);

// Set some snips as transitions
draw_transition = aesnips_create_transition(idle_snip, fire_snip, draw_snip);
holster_transition = aesnips_create_transition(fire_snip, idle_snip, holster_snip);

// Add a loop to twirl the gun multiple times
twirl_loop = aesnips_create_loop(holster_snip, 0, 2, 3);

// Create the player and start with the idle snip
my_player = aesnips_create_player();
my_player.Play(idle_snip);