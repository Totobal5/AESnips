/// @description Initialize object

//Create a new Snip with the cowboy sprite
my_snip = new Snip(blue_cowboy_sprite, 1).setFrameSpeedExt([4,.2,  8,.2,  16,.2]);
my_snip.setFrameCallback(6, method(id, cowboy_fire_bullet), [-10]);

//Create two loops that the user controls
shoot_loop_with_twirl = new Loop(my_snip, 5, 12, 0);
shoot_loop = new Loop(my_snip, 5, 8, 0);
//Since they repeat 0 times they don't do anything until the user presses a number

//A loop to make the cowboy look a little fancier
twirl_loop = new Loop(my_snip, 9, 11, 3);

//A variable to tell the cowboy how many times to shoot
fire_count = 1;

my_player = new SnipPlayer();
my_player.start(my_snip);
