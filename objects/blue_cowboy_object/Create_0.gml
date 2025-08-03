/// @description Initialize object

// Create a new Snip with the cowboy sprite using the factory function
my_snip = aesnips_create_snip(blue_cowboy_sprite, 1);

// Chain methods using the new PascalCase naming
my_snip.SetFrameSpeed(4, 0.2, 8, 0.2, 16, 0.2);
my_snip.SetFrameCallback(6, method(id, cowboy_fire_bullet), [-10]);

// Create two loops that the user controls
shoot_loop_with_twirl = aesnips_create_loop(my_snip, 5, 12, 0);
shoot_loop = aesnips_create_loop(my_snip, 5, 8, 0);
// Since they repeat 0 times they don't do anything until the user presses a number

// A loop to make the cowboy look a little fancier
twirl_loop = aesnips_create_loop(my_snip, 9, 11, 3);

// A variable to tell the cowboy how many times to shoot
fire_count = 1;

// Create the player using the factory function
my_player = aesnips_create_player();
my_player.Play(my_snip);