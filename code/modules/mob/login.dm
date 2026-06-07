/**
 * Run when a client is put in this mob or reconnects to byond and their client was on this mob
 *
 * Things it does:
 * * Adds player to player_list
 * * sets lastKnownIP
 * * sets computer_id
 * * logs the login
 * * tells the world to update it's status (for player count)
 * * create mob huds for the mob if needed
 * * reset next_move to 1
 * * parent call
 * * if the client exists set the perspective to the mob loc
 * * call on_log on the loc (sigh)
 * * reload the huds for the mob
 * * reload all full screen huds attached to this mob
 * * load any global alternate apperances
 * * sync the mind datum via sync_mind()
 * * call any client login callbacks that exist
 * * grant any actions the mob has to the client
 * * calls [auto_deadmin_on_login](mob.html#proc/auto_deadmin_on_login)
 * * send signal COMSIG_MOB_CLIENT_LOGIN
 */


/mob/Login()
	if(QDELETED(src) || QDELETED(client))
		return
	try
		if(!islist(GLOB.player_list))
			GLOB.player_list = list()
		if(!(src in GLOB.player_list))
			GLOB.player_list += src
	catch
		GLOB.player_list = list(src)
	lastKnownIP	= client.address
	computer_id	= client.computer_id
	log_access("Mob Login: [key_name(src)] was assigned to a [type]")
	try
		world.update_status()
	catch
		EMPTY_BLOCK_GUARD
	client.screen = list()				//remove hud items just in case
	client.images = list()

	if(!hud_used)
		create_mob_hud()
	if(hud_used && client && client.prefs)
		try
			hud_used.show_hud(hud_used.hud_version)
			hud_used.update_ui_style(ui_style2icon(client.prefs.UI_style))
		catch
			EMPTY_BLOCK_GUARD

	next_move = 1

	..()
	try
		SEND_SIGNAL(src, COMSIG_MOB_LOGIN)
	catch
		EMPTY_BLOCK_GUARD

	if (client && key != client.key)
		key = client.key
	try
		reset_perspective(loc)
	catch
		EMPTY_BLOCK_GUARD

	if(loc)
		try
			loc.on_log(TRUE)
		catch
			EMPTY_BLOCK_GUARD

	//readd this mob's HUDs (antag, med, etc)
	try
		reload_huds()
	catch
		EMPTY_BLOCK_GUARD

	try
		reload_fullscreen() // Reload any fullscreen overlays this mob has.
	catch
		EMPTY_BLOCK_GUARD

	try
		add_click_catcher()
	catch
		EMPTY_BLOCK_GUARD

	try
		sync_mind()
	catch
		EMPTY_BLOCK_GUARD

	//Reload alternate appearances
	if(islist(GLOB.active_alternate_appearances))
		var/appearance_count = 0
		try
			appearance_count = length(GLOB.active_alternate_appearances)
		catch
			appearance_count = 0
		for(var/appearance_index in 1 to appearance_count)
			var/datum/atom_hud/alternate_appearance/AA
			try
				AA = GLOB.active_alternate_appearances[appearance_index]
				AA?.onNewMob(src)
			catch
				continue

	try
		update_client_colour()
	catch
		EMPTY_BLOCK_GUARD
	try
		update_mouse_pointer()
	catch
		EMPTY_BLOCK_GUARD
	try
		update_ambience_area(get_area(src))
	catch
		EMPTY_BLOCK_GUARD

	if(!can_hear())
		stop_sound_channel(CHANNEL_AMBIENCE)

	if(client)
		var/list/player_actions = null
		var/list/post_login_callbacks = null
		try
			player_actions = client.player_details?.player_actions
			post_login_callbacks = client.player_details?.post_login_callbacks
		catch
			player_actions = null
			post_login_callbacks = null
		if(islist(player_actions))
			var/action_count = 0
			try
				action_count = length(player_actions)
			catch
				action_count = 0
			for(var/action_index in 1 to action_count)
				var/datum/action/A
				try
					A = player_actions[action_index]
					A?.Grant(src)
				catch
					continue

		if(islist(post_login_callbacks))
			var/callback_count = 0
			try
				callback_count = length(post_login_callbacks)
			catch
				callback_count = 0
			for(var/callback_index in 1 to callback_count)
				var/datum/callback/CB
				try
					CB = post_login_callbacks[callback_index]
					CB?.Invoke()
				catch
					continue
		try
			log_played_names(client.ckey,name,real_name)
		catch
			EMPTY_BLOCK_GUARD
		try
			auto_deadmin_on_login()
		catch
			EMPTY_BLOCK_GUARD

	if(SSticker.current_state == GAME_STATE_FINISHED)
		do_game_over()

	log_message("Client [key_name(src)] has taken ownership of mob [src]([src.type])", LOG_OWNERSHIP)
	try
		enable_client_mobs_in_contents(client)
	catch
		EMPTY_BLOCK_GUARD

	try
		SEND_SIGNAL(src, COMSIG_MOB_CLIENT_LOGIN, client)
	catch
		EMPTY_BLOCK_GUARD

	try
		client.init_verbs()
	catch
		EMPTY_BLOCK_GUARD

	try
		addtimer(CALLBACK(src, PROC_REF(send_pref_messages)), 2 SECONDS)
	catch
		EMPTY_BLOCK_GUARD
	try
		resend_all_uis()
	catch
		EMPTY_BLOCK_GUARD
	if(client)
		try
			client.preload_music()
		catch
			EMPTY_BLOCK_GUARD

/mob/proc/send_pref_messages()
	if(client?.prefs)
		for(var/message in client.prefs.preference_message_list)
			to_chat(src, message)

/**
 * Checks if the attached client is an admin and may deadmin them
 *
 * Configs:
 * * flag/auto_deadmin_players
 * * client.prefs?.toggles & DEADMIN_ALWAYS
 * * User is antag and flag/auto_deadmin_antagonists or client.prefs?.toggles & DEADMIN_ANTAGONIST
 * * or if their job demands a deadminning SSjob.handle_auto_deadmin_roles()
 *
 * Called from [login](mob.html#proc/Login)
 */
/mob/proc/auto_deadmin_on_login() //return true if they're not an admin at the end.
	if(!client?.holder)
		return TRUE
	if(CONFIG_GET(flag/auto_deadmin_players) || (client.prefs?.toggles & DEADMIN_ALWAYS))
		return client.holder.auto_deadmin()
	if(mind.has_antag_datum(/datum/antagonist) && (CONFIG_GET(flag/auto_deadmin_antagonists) || client.prefs?.toggles & DEADMIN_ANTAGONIST))
		return client.holder.auto_deadmin()
	if(job)
		return SSjob.handle_auto_deadmin_roles(client, job)
