/// @description Create the snips and transitions that the runners will use
left_snip  = new Snip(run_left_sprite, .5);
right_snip = new Snip(run_right_sprite, .5);

left_right_snip = (new Snip(run_left_to_right, .5) ).setFrameSpeed(2, .9).setFrameSpeed(3, .7).setFrameSpeed(4, .9);
right_left_snip = (new Snip(run_right_to_left, .5) ).setFrameSpeed(2, .9).setFrameSpeed(3, .7).setFrameSpeed(4, .9);

//Create transitions with the snips
r_l_transition = new Transition(right_snip, left_snip, right_left_snip);
l_r_transition = new Transition(left_snip, right_snip, left_right_snip);