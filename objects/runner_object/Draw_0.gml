/// @description Draw the player and its debug info

my_player.DrawDebug(0, y + 64);

// The original code drew two sprites. Replicating that here.
my_player.Draw(x + 64, y);
my_player.Draw(x - 64, y);