/// @description Switch to the right-facing animation.

// Only switch if we are not already going right.
if (!my_player.IsPlaying(runner_snip_holder.right_snip, true))
{
    var _interrupt = keyboard_check(vk_shift);
    var _use_transition = true; // Always try to use the turning animation

    // Use Play to interrupt immediately, or PlayNext to wait.
    if (_interrupt)
    {
        my_player.Play(runner_snip_holder.right_snip, _use_transition);
    }
    else
    {
        my_player.PlayNext(runner_snip_holder.right_snip, _use_transition);
    }
}