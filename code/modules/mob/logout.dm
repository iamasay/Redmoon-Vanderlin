/mob/Logout()
	try
		SEND_SIGNAL(src, COMSIG_MOB_LOGOUT)
	catch
		EMPTY_BLOCK_GUARD
	log_message("[key_name(src)] is no longer owning mob [src]([src.type])", LOG_OWNERSHIP)
	try
		SStgui.on_logout(src)
	catch
		EMPTY_BLOCK_GUARD
	try
		unset_machine()
	catch
		EMPTY_BLOCK_GUARD
	try
		set_typing_indicator(FALSE)
	catch
		EMPTY_BLOCK_GUARD
	try
		if(islist(GLOB.player_list))
			GLOB.player_list -= src
	catch
		GLOB.player_list = list()
	try
		update_ambience_area(null) // Unset ambience vars so it plays again on login
	catch
		EMPTY_BLOCK_GUARD
	..()

	if(loc)
		try
			loc.on_log(FALSE)
		catch
			EMPTY_BLOCK_GUARD

	if(client)
		var/list/post_logout_callbacks
		try
			post_logout_callbacks = client.player_details?.post_logout_callbacks
		catch
			post_logout_callbacks = null
		if(islist(post_logout_callbacks))
			var/callback_count = 0
			try
				callback_count = length(post_logout_callbacks)
			catch
				callback_count = 0
			for(var/callback_index in 1 to callback_count)
				var/datum/callback/CB
				try
					CB = post_logout_callbacks[callback_index]
					CB.Invoke()
				catch
					continue

	try
		clear_important_client_contents(client)
	catch
		EMPTY_BLOCK_GUARD
	try
		remove_all_uis()
	catch
		EMPTY_BLOCK_GUARD
	return TRUE
