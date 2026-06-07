
/mob/living/carbon/human/dummy
	real_name = "Test Dummy"
	status_flags = GODMODE|CANPUSH
	mouse_drag_pointer = MOUSE_INACTIVE_POINTER
	var/in_use = FALSE

INITIALIZE_IMMEDIATE(/mob/living/carbon/human/dummy)

/mob/living/carbon/human/dummy/Initialize()
	. = ..()
	// Can we PLEASE get a consistent way to wipe these dummies no matter how we spawn in?
	GLOB.human_list -= src
	GLOB.carbon_list -= src
	GLOB.mob_living_list -= src
	GLOB.alive_mob_list -= src
	GLOB.mob_list -= src

/mob/living/carbon/human/dummy/Destroy()
	in_use = FALSE
	return ..()

/mob/living/carbon/human/dummy/Life()
	return

// no reason for these to ever be hearing sensitive, it just wastes time on spatial grid stuff
/mob/living/carbon/human/dummy/become_hearing_sensitive(trait_source)
	return

/mob/living/carbon/human/dummy/proc/wipe_state()
	delete_equipment()
	cut_overlays(TRUE)

/mob/living/carbon/human/dummy/setup_human_dna()
	create_dna(src)
	randomize_human(src)
	dna.initialize_dna(skip_index = TRUE) //Skip stuff that requires full round init.

//Inefficient pooling/caching way.
GLOBAL_LIST_EMPTY(human_dummy_list)
GLOBAL_LIST_EMPTY(dummy_mob_list)

/proc/generate_or_wait_for_human_dummy(slotkey)
	if(!slotkey)
		return new /mob/living/carbon/human/dummy
	if(!islist(GLOB.human_dummy_list))
		GLOB.human_dummy_list = list()
	if(!islist(GLOB.dummy_mob_list))
		GLOB.dummy_mob_list = list()
	var/mob/living/carbon/human/dummy/D
	try
		D = GLOB.human_dummy_list[slotkey]
	catch
		GLOB.human_dummy_list = list()
		D = null
	if(istype(D))
		UNTIL(!D.in_use)
	if(QDELETED(D))
		D = new
		try
			GLOB.human_dummy_list[slotkey] = D
		catch
			GLOB.human_dummy_list = list()
			GLOB.human_dummy_list[slotkey] = D
		try
			if(!(D in GLOB.dummy_mob_list))
				GLOB.dummy_mob_list += D
		catch
			GLOB.dummy_mob_list = list(D)
	D.in_use = TRUE
	return D

/proc/unset_busy_human_dummy(slotnumber)
	if(!slotnumber)
		return
	if(!islist(GLOB.human_dummy_list))
		GLOB.human_dummy_list = list()
	var/mob/living/carbon/human/dummy/D
	try
		D = GLOB.human_dummy_list[slotnumber]
	catch
		D = null
	if(istype(D))
		try
			D.wipe_state()
		catch
			EMPTY_BLOCK_GUARD
		D.in_use = FALSE
