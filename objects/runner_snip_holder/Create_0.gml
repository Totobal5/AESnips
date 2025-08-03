/// @description Create the snips and transitions that the runners will use

// Create Snips for each state using the factory functions
left_snip = aesnips_create_snip(run_left_sprite, 0.5);
right_snip = aesnips_create_snip(run_right_sprite, 0.5);

// Create the transition animations and chain methods to set frame speeds
left_to_right_snip = aesnips_create_snip(run_left_to_right, 0.5);
left_to_right_snip.SetFrameSpeed(2, 0.9).SetFrameSpeed(3, 0.7).SetFrameSpeed(4, 0.9);

right_to_left_snip = aesnips_create_snip(run_right_to_left, 0.5);
right_to_left_snip.SetFrameSpeed(2, 0.9).SetFrameSpeed(3, 0.7).SetFrameSpeed(4, 0.9);

// Create transitions with the snips
aesnips_create_transition(right_snip, left_snip, right_to_left_snip);
aesnips_create_transition(left_snip, right_snip, left_to_right_snip);