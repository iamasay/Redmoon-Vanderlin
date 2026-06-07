SUBSYSTEM_DEF(atoms)
	name = "Atoms"
	init_order = INIT_ORDER_ATOMS
	flags = SS_NO_FIRE

	var/init_start_time

	var/old_initialized

	var/list/late_loaders = list()

	var/list/BadInitializeCalls = list()

	var/list/queued_deletions = list()

	initialized = INITIALIZATION_INSSATOMS

/datum/controller/subsystem/atoms/Initialize(timeofday)
	GLOB.fire_overlay.appearance_flags = RESET_COLOR
	initialized = INITIALIZATION_INNEW_MAPLOAD
	InitializeAtoms()
	initialized = INITIALIZATION_INNEW_REGULAR
	GLOB.obtained_from_reverse = build_obtained_from_reverse()
	return ..()

/datum/controller/subsystem/atoms/proc/InitializeAtoms(list/atoms)
	if(initialized == INITIALIZATION_INSSATOMS)
		return

	old_initialized = initialized
	initialized = INITIALIZATION_INNEW_MAPLOAD

	var/count
	var/list/mapload_arg = list(TRUE)

	if(atoms)
		count = length(atoms)
		for(var/I in 1 to count)
			var/atom/A = atoms[I]
			if(!(A.flags_1 & INITIALIZED_1))
				CHECK_TICK
				InitAtom(A, mapload_arg)
	else
		count = 0
		for(var/atom/A as anything in world)
			if(!(A.flags_1 & INITIALIZED_1))
				InitAtom(A, mapload_arg)
				++count
				CHECK_TICK

	testing("Initialized [count] atoms")
	pass(count)

	initialized = old_initialized

	if(length(late_loaders))
		for(var/I in 1 to length(late_loaders))
			var/atom/A = late_loaders[I]
			//I hate that we need this
			if(QDELETED(A))
				continue
			A.LateInitialize()
		testing("Late initialized [length(late_loaders)] atoms")
		late_loaders.Cut()

	for(var/queued_deletion in queued_deletions)
		qdel(queued_deletion)

	testing("[length(queued_deletions)] atoms were queued for deletion.")
	queued_deletions.Cut()

/datum/controller/subsystem/atoms/proc/InitAtom(atom/A, list/init_args)
	var/the_type = A.type
	if(QDELING(A))
		// Check init_start_time to not worry about atoms created before the atoms SS that are cleaned up before this
		if (A.gc_destroyed > init_start_time)
			BadInitializeCalls[the_type] |= BAD_INIT_QDEL_BEFORE
		return TRUE

	#ifdef UNIT_TESTS
	var/start_tick = world.time
	#endif

	var/arglen = 0
	if(islist(init_args))
		try
			arglen = length(init_args)
		catch
			arglen = 0
	var/mapload = FALSE
	if(arglen >= 1)
		try
			mapload = init_args[1]
		catch
			arglen = 0

	var/result
	if(arglen <= 1)
		result = A.Initialize(mapload)
	else if(arglen == 2)
		var/arg1_2 = mapload
		var/arg2_2
		try
			arg2_2 = init_args[2]
		catch
			arglen = 1
		if(arglen == 1)
			result = A.Initialize(mapload)
		else
			result = A.Initialize(arg1_2, arg2_2)
	else if(arglen == 3)
		var/arg1_3 = mapload
		var/arg2_3
		var/arg3_3
		try
			arg2_3 = init_args[2]
			arg3_3 = init_args[3]
		catch
			arglen = 1
		if(arglen == 1)
			result = A.Initialize(mapload)
		else
			result = A.Initialize(arg1_3, arg2_3, arg3_3)
	else if(arglen == 4)
		var/arg1_4 = mapload
		var/arg2_4
		var/arg3_4
		var/arg4_4
		try
			arg2_4 = init_args[2]
			arg3_4 = init_args[3]
			arg4_4 = init_args[4]
		catch
			arglen = 1
		if(arglen == 1)
			result = A.Initialize(mapload)
		else
			result = A.Initialize(arg1_4, arg2_4, arg3_4, arg4_4)
	else
		var/list/extra_init_args = list()
		try
			extra_init_args.len = arglen
			for(var/i in 1 to arglen)
				extra_init_args[i] = init_args[i]
		catch
			extra_init_args = null
		if(extra_init_args)
			result = A.Initialize(arglist(extra_init_args))
		else
			result = A.Initialize(mapload)

	#ifdef UNIT_TESTS
	if(start_tick != world.time)
		BadInitializeCalls[the_type] |= BAD_INIT_SLEPT
	#endif

	var/qdeleted = FALSE

	switch(result)
		if (INITIALIZE_HINT_NORMAL)
			EMPTY_BLOCK_GUARD // pass
		if(INITIALIZE_HINT_LATELOAD)
			if(mapload)
				late_loaders += A
			else
				A.LateInitialize()
		if(INITIALIZE_HINT_QDEL)
			qdel(A)
			qdeleted = TRUE
		else
			try
				if(!islist(BadInitializeCalls))
					BadInitializeCalls = list()
				BadInitializeCalls[the_type] |= BAD_INIT_NO_HINT
			catch
				BadInitializeCalls = list()
				BadInitializeCalls[the_type] = BAD_INIT_NO_HINT

	if(!A)	//possible harddel
		qdeleted = TRUE
	else if(!(A.flags_1 & INITIALIZED_1))
		try
			if(!islist(BadInitializeCalls))
				BadInitializeCalls = list()
			BadInitializeCalls[the_type] |= BAD_INIT_DIDNT_INIT
		catch
			BadInitializeCalls = list()
			BadInitializeCalls[the_type] = BAD_INIT_DIDNT_INIT
	else
		try
			SEND_SIGNAL(A, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZE)
		catch
			EMPTY_BLOCK_GUARD
		var/atom/location = A.loc
		if(location)
			/// Sends a signal that the new atom `src`, has been created at `loc`
			try
				SEND_SIGNAL(location, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, A, mapload)
			catch
				EMPTY_BLOCK_GUARD

	return qdeleted || QDELING(A)

/datum/controller/subsystem/atoms/proc/map_loader_begin()
	old_initialized = initialized
	initialized = INITIALIZATION_INSSATOMS

/datum/controller/subsystem/atoms/proc/map_loader_stop()
	initialized = old_initialized

/datum/controller/subsystem/atoms/Recover()
	initialized = SSatoms.initialized
	if(initialized == INITIALIZATION_INNEW_MAPLOAD)
		InitializeAtoms()
	old_initialized = SSatoms.old_initialized
	BadInitializeCalls = SSatoms.BadInitializeCalls

/datum/controller/subsystem/atoms/proc/InitLog()
	. = ""
	for(var/path in BadInitializeCalls)
		. += "Path : [path] \n"
		var/fails = BadInitializeCalls[path]
		if(fails & BAD_INIT_DIDNT_INIT)
			. += "- Didn't call atom/Initialize()\n"
		if(fails & BAD_INIT_NO_HINT)
			. += "- Didn't return an Initialize hint\n"
		if(fails & BAD_INIT_QDEL_BEFORE)
			. += "- Qdel'd in New()\n"
		if(fails & BAD_INIT_SLEPT)
			. += "- Slept during Initialize()\n"

/// Prepares an atom to be deleted once the atoms SS is initialized.
/datum/controller/subsystem/atoms/proc/prepare_deletion(atom/target)
	if (initialized == INITIALIZATION_INNEW_REGULAR)
		// Atoms SS has already completed, just kill it now.
		qdel(target)
	else
		queued_deletions += WEAKREF(target)

/datum/controller/subsystem/atoms/Shutdown()
	var/initlog = InitLog()
	if(initlog)
		text2file(initlog, "[GLOB.log_directory]/initialize.log")
