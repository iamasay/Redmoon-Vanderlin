// Clients aren't datums so we have to define these procs indpendently.
// These verbs are called for all key press and release events
/client/verb/keyDown(_key as text)
	set instant = TRUE
	set hidden = TRUE

	if(mob.focus && istype(mob.focus, /obj/abstract/visual_ui_element/console_input))
		var/obj/abstract/visual_ui_element/console_input/console_input = mob.focus
		if(console_input.handle_keydown(_key))
			return
	if(istype(click_intercept, /datum/buildmode) && (_key == "Shift"))
		var/datum/buildmode/B = click_intercept
		B.toggle_pixel_positioning_mode(TRUE)

	// If not handled by console, continue with normal key handling
	client_keysend_amount += 1

	var/cache = client_keysend_amount

	if(keysend_tripped && next_keysend_trip_reset <= world.time)
		keysend_tripped = FALSE

	if(next_keysend_reset <= world.time)
		client_keysend_amount = 0
		next_keysend_reset = world.time + (1 SECONDS)

	//The "tripped" system is to confirm that flooding is still happening after one spike
	//not entirely sure how byond commands interact in relation to lag
	//don't want to kick people if a lag spike results in a huge flood of commands being sent
	if(cache >= MAX_KEYPRESS_AUTOKICK)
		if(!keysend_tripped)
			keysend_tripped = TRUE
			next_keysend_trip_reset = world.time + (2 SECONDS)
		else
			log_admin("Client [ckey] was just autokicked for flooding keysends; likely abuse but potentially lagspike.")
			message_admins("Client [ckey] was just autokicked for flooding keysends; likely abuse but potentially lagspike.")
			qdel(src)
			return

	///Check if the key is short enough to even be a real key
	if(LAZYLEN(_key) > MAX_KEYPRESS_COMMANDLENGTH)
		to_chat(src, "<span class='danger'>Invalid KeyDown detected! You have been disconnected from the server automatically.</span>")
		log_admin("Client [ckey] just attempted to send an invalid keypress. Keymessage was over [MAX_KEYPRESS_COMMANDLENGTH] characters, autokicking due to likely abuse.")
		message_admins("Client [ckey] just attempted to send an invalid keypress. Keymessage was over [MAX_KEYPRESS_COMMANDLENGTH] characters, autokicking due to likely abuse.")
		qdel(src)
		return

	//Focus Chat failsafe. Overrides movement checks to prevent WASD.
	if(!prefs.hotkeys && length(_key) == 1 && _key != "Alt" && _key != "Ctrl" && _key != "Shift")
		winset(src, null, "input.focus=true ; input.text=[url_encode(_key)]")
		return

	try
		if(!islist(keys_held))
			keys_held = list()
		if(length(keys_held) > MAX_HELD_KEYS)
			keys_held.Cut(1,2)
		keys_held[_key] = TRUE
	catch
		keys_held = list()
		keys_held[_key] = TRUE
	var/movement
	try
		movement = islist(movement_keys) ? movement_keys[_key] : null
	catch
		movement = null
	var/ctrl_held = FALSE
	try
		ctrl_held = islist(keys_held) && keys_held["Ctrl"]
	catch
		keys_held = list()
	if(!(next_move_dir_sub & movement) && !ctrl_held)
		next_move_dir_add |= movement

	// Client-level keybindings are ones anyone should be able to do at any time
	// Things like taking screenshots, hitting tab, and adminhelps.
	var/AltMod = ""
	var/CtrlMod = ""
	var/ShiftMod = ""
	try
		AltMod = islist(keys_held) && keys_held["Alt"] ? "Alt" : ""
		CtrlMod = islist(keys_held) && keys_held["Ctrl"] ? "Ctrl" : ""
		ShiftMod = islist(keys_held) && keys_held["Shift"] ? "Shift" : ""
	catch
		keys_held = list()
	var/full_key
	switch(_key)
		if("Alt", "Ctrl", "Shift")
			full_key = "[AltMod][CtrlMod][ShiftMod]"
		else
			full_key = "[AltMod][CtrlMod][ShiftMod][_key]"
	var/keycount = 0
	var/list/key_bindings = null
	try
		key_bindings = prefs?.key_bindings[full_key]
	catch
		key_bindings = null
	if(islist(key_bindings))
		var/key_binding_count = 0
		try
			key_binding_count = length(key_bindings)
		catch
			key_binding_count = 0
		for(var/key_binding_index in 1 to key_binding_count)
			var/kb_name
			var/datum/keybinding/kb
			try
				kb_name = key_bindings[key_binding_index]
				kb = GLOB.keybindings_by_name[kb_name]
			catch
				continue
			keycount++
			if(istype(kb, /datum/keybinding/client/say))
				continue
			if(kb)
				if(kb.can_use(src) && kb.down(src) && keycount >= MAX_COMMANDS_PER_KEY)
					break


	holder?.key_down(_key, src)
	mob?.focus?.key_down(_key, src)
	mob?.update_mouse_pointer()

/client/verb/keyUp(_key as text)
	set instant = TRUE
	set hidden = TRUE

	// Check if the mob's focus is a console input
	if(mob.focus && istype(mob.focus, /obj/abstract/visual_ui_element/console_input))
		var/obj/abstract/visual_ui_element/console_input/console_input = mob.focus
		if(console_input.handle_keyup(_key))
			return

	if(istype(click_intercept, /datum/buildmode) && (_key == "Shift"))
		var/datum/buildmode/B = click_intercept
		B.toggle_pixel_positioning_mode(FALSE)

	try
		if(islist(keys_held))
			keys_held -= _key
	catch
		keys_held = list()
	var/movement
	try
		movement = islist(movement_keys) ? movement_keys[_key] : null
	catch
		movement = null
	if(!(next_move_dir_add & movement))
		next_move_dir_sub |= movement

	// We don't do full key for release, because for mod keys you
	// can hold different keys and releasing any should be handled by the key binding specifically
	var/list/key_bindings = null
	try
		key_bindings = prefs?.key_bindings[_key]
	catch
		key_bindings = null
	if(islist(key_bindings))
		var/key_binding_count = 0
		try
			key_binding_count = length(key_bindings)
		catch
			key_binding_count = 0
		for(var/key_binding_index in 1 to key_binding_count)
			var/kb_name
			var/datum/keybinding/kb
			try
				kb_name = key_bindings[key_binding_index]
				kb = GLOB.keybindings_by_name[kb_name]
			catch
				continue
			if(istype(kb, /datum/keybinding/client/say))
				continue
			if(kb)
				if(kb.up(src))
					break
	holder?.key_up(_key, src)
	mob.focus?.key_up(_key, src)
	mob.update_mouse_pointer()

/client/verb/activeInput()
	set hidden = 1
	if(isliving(mob))
		var/mob/living/L = mob
		if(L.stat)
			return
		mob.set_typing_indicator(TRUE)

/client/verb/disableInput()
	set hidden = 1
	if(isliving(mob))
		mob.set_typing_indicator(FALSE)
