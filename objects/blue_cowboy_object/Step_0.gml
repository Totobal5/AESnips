/// @description Perform the snip step event
show_debug_message("(Blue cowboy) image_index: {0}", my_player.imageIndex);

my_player.step();

//The user can press numbers 1-9 to change how many times the cowboy shoots his gun
if (keyboard_lastkey != -1) //If a key has been pressed
{
	//If a number was pressed
	if (keyboard_lastkey >= 48 and keyboard_lastkey <= 57)
	{
		//Find out which number was pressed
		fire_count = keyboard_lastkey - ord("0");
		
		//Set the shoot loop repeat count to fire_count
		//Subtract 1 because a loop count of 0 means the loop will still play through once (without repeating)
		//A loop count of -1 means the loop should be skipped
		shoot_loop.setIterate(fire_count - 1);
		
		//If the gun shot should be entirely skipped skip the entire firing and gun twirling sequence 
		//or 
		//If the gun is shooting at least once play the long loop 
		shoot_loop_with_twirl.setIterate( (fire_count == 0) ? -1 : 0);
	}
	keyboard_lastkey = -1; //Mark it as handled
}