/// @description Mouse click flip
var _shift = keyboard_check(vk_shift);
if (my_player.isPlaying(runner_snip_holder.left_snip, true) ) {
	if (_shift)
	{
		my_player.play(runner_snip_holder.right_snip, true);
	}
	else
	{
		my_player.playNext(runner_snip_holder.right_snip, true);
	}	
}
else
{
	if (_shift)
	{
		my_player.play(runner_snip_holder.left_snip, true);
	}
	else
	{
		my_player.playNext(runner_snip_holder.left_snip, true);
	}
}