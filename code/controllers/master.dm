/**
 * StonedMC
 *
 * Designed to properly split up a given tick among subsystems
 * Note: if you read parts of this code and think "why is it doing it that way"
 * Odds are, there is a reason
 *
 **/

//This is the ABSOLUTE ONLY THING that should init globally like this
//2019 update: the failsafe,config and Global controllers also do it
GLOBAL_REAL(Master, /datum/controller/master)

//THIS IS THE INIT ORDER
//Master -> SSPreInit -> GLOB -> world -> config -> SSInit -> Failsafe
//GOT IT MEMORIZED?

/datum/controller/master
	name = "Master"

	/// Are we processing (higher values increase the processing delay by n ticks)
	var/processing = TRUE
	/// How many times have we ran
	var/iteration = 0
	/// Stack end detector to detect stack overflows that kill the mc's main loop
	var/datum/stack_end_detector/stack_end_detector

	/// world.time of last fire, for tracking lag outside of the mc
	var/last_run

	/// List of subsystems to process().
	var/list/subsystems

	// Vars for keeping track of tick drift.
	var/init_timeofday
	var/init_time
	var/tickdrift = 0

	/// How long is the MC sleeping between runs, read only (set by Loop() based off of anti-tick-contention heuristics)
	var/sleep_delta = 1

	/// makes the mc main loop runtime
	var/make_runtime = 0

	var/initializations_finished_with_no_players_logged_in	//I wonder what this could be?

	/// The type of the last subsystem to be fire()'d.
	var/last_type_processed

	/// Start of queue linked list
	var/datum/controller/subsystem/queue_head
	/// End of queue linked list (used for appending to the list)
	var/datum/controller/subsystem/queue_tail
	/// Running total so that we don't have to loop thru the queue each run to split up the tick
	var/queue_priority_count = 0
	/// Same, but for background subsystems
	var/queue_priority_count_bg = 0
	/// Are we loading in a new map?
	var/map_loading = FALSE
	/// for scheduling different subsystems for different stages of the round
	var/current_runlevel
	var/sleep_offline_after_initializations = TRUE

	var/static/restart_clear = 0
	var/static/restart_timeout = 0
	var/static/restart_count = 0

	var/static/random_seed

	//current tick limit, assigned before running a subsystem.
	//used by CHECK_TICK as well so that the procs subsystems call can obey that SS's tick limits
	var/static/current_ticklimit = TICK_LIMIT_RUNNING

	var/static/initialized_all = FALSE

/datum/controller/master/New()
	if(!config)
		config = new
	// Highlander-style: there can only be one! Kill off the old and replace it with the new.

	if(!random_seed)
#ifdef UNIT_TESTS
		random_seed = 29051994
#else
		random_seed = rand(1, 1e9)
#endif
		rand_seed(random_seed)

	var/list/_subsystems = list()
	subsystems = _subsystems
	if (Master != src)
		if (istype(Master))
			Recover()
			qdel(Master)
		else
			var/list/subsytem_types = subtypesof(/datum/controller/subsystem)
			sortTim(subsytem_types, GLOBAL_PROC_REF(cmp_subsystem_init))
			for(var/I in subsytem_types)
				_subsystems += new I
		Master = src

	if(!GLOB)
		new /datum/controller/global_vars

/datum/controller/master/Destroy()
	..()
	// Tell qdel() to Del() this object.
	return QDEL_HINT_HARDDEL_NOW

/datum/controller/master/proc/ensure_subsystems_list()
	if(islist(subsystems))
		try
			var/subsystem_count = length(subsystems)
			if(subsystem_count >= 0)
				return TRUE
		catch
			EMPTY_BLOCK_GUARD
	subsystems = list()
	var/list/subsystem_types = subtypesof(/datum/controller/subsystem)
	sortTim(subsystem_types, GLOBAL_PROC_REF(cmp_subsystem_init))
	for(var/subsystem_type in subsystem_types)
		subsystems += new subsystem_type
	return TRUE

/datum/controller/master/Shutdown()
	processing = FALSE
	sortTim(subsystems, GLOBAL_PROC_REF(cmp_subsystem_init))
	reverseRange(subsystems)
	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		return
	for(var/subsystem_index in 1 to subsystem_count)
		var/datum/controller/subsystem/ss
		try
			ss = subsystems[subsystem_index]
		catch
			continue
		if(!istype(ss))
			continue
		log_world("Shutting down [ss.name] subsystem...")
		ss.Shutdown()
	log_world("Shutdown complete")

// Returns 1 if we created a new mc, 0 if we couldn't due to a recent restart,
//	-1 if we encountered a runtime trying to recreate it
/proc/Recreate_MC()
	. = -1 //so if we runtime, things know we failed
	if (world.time < Master.restart_timeout)
		return 0
	if (world.time < Master.restart_clear)
		Master.restart_count *= 0.5

	var/delay = 50 * ++Master.restart_count
	Master.restart_timeout = world.time + delay
	Master.restart_clear = world.time + (delay * 2)
	Master.processing = FALSE //stop ticking this one
	try
		new/datum/controller/master()
	catch
		return -1
	return 1


/datum/controller/master/Recover()
	var/msg = "## DEBUG: [time2text(world.timeofday)] MC restarted. Reports:\n"
	for (var/varname in Master.vars)
		switch (varname)
			if("name", "tag", "bestF", "type", "parent_type", "vars", "statclick") // Built-in junk.
				continue
			else
				var/varval = Master.vars[varname]
				if (istype(varval, /datum)) // Check if it has a type var.
					var/datum/D = varval
					msg += "\t [varname] = [D]([D.type])\n"
				else
					msg += "\t [varname] = [varval]\n"
	log_world(msg)

	var/datum/controller/subsystem/BadBoy = Master.last_type_processed
	var/FireHim = FALSE
	if(istype(BadBoy))
		msg = null
		LAZYINITLIST(BadBoy.failure_strikes)
		switch(++BadBoy.failure_strikes[BadBoy.type])
			if(2)
				msg = "The [BadBoy.name] subsystem was the last to fire for 2 controller restarts. It will be recovered now and disabled if it happens again."
				FireHim = TRUE
			if(3)
				msg = "The [BadBoy.name] subsystem seems to be destabilizing the MC and will be offlined."
				BadBoy.flags |= SS_NO_FIRE
		if(msg)
			to_chat(GLOB.admins, "<span class='boldannounce'>[msg]</span>")
			log_world(msg)

	if (istype(Master.subsystems))
		if(FireHim)
			Master.subsystems += new BadBoy.type	//NEW_SS_GLOBAL will remove the old one
		subsystems = Master.subsystems
		current_runlevel = Master.current_runlevel
		StartProcessing(10)
	else
		to_chat(world, "<span class='boldannounce'>The Master Controller is having some issues, we will need to re-initialize EVERYTHING</span>")
		Initialize(20, TRUE)

// Please don't stuff random bullshit here,
// 	Make a subsystem, give it the SS_NO_FIRE flag, and do your work in it's Initialize()
/datum/controller/master/Initialize(delay, init_sss, tgs_prime)
	set waitfor = 0

	if(delay)
		sleep(delay)

	if(tgs_prime)
		world.TgsInitializationComplete()

	if(init_sss)
		init_subtypes(/datum/controller/subsystem, subsystems)
#ifdef TESTING
	to_chat(world, "<span class='boldannounce'>Initializing subsystems...</span>")
#endif
	// Sort subsystems by init_order, so they initialize in the correct order.
	sortTim(subsystems, GLOBAL_PROC_REF(cmp_subsystem_init))

	var/start_timeofday = REALTIMEOFDAY
	// Initialize subsystems.
	current_ticklimit = CONFIG_GET(number/tick_limit_mc_init)
	ensure_subsystems_list()
	var/init_subsystem_count = 0
	try
		init_subsystem_count = length(subsystems)
	catch
		init_subsystem_count = 0
	for (var/init_subsystem_index in 1 to init_subsystem_count)
		var/datum/controller/subsystem/SS
		try
			SS = subsystems[init_subsystem_index]
		catch
			continue
		if(!istype(SS))
			continue
		if (SS.flags & SS_NO_INIT)
			continue
#ifdef LOWMEMORYMODE
		if(SS.lazy_load)
			continue
#endif
		SS.Initialize(REALTIMEOFDAY)
		CHECK_TICK
	current_ticklimit = TICK_LIMIT_RUNNING

	var/time = (REALTIMEOFDAY - start_timeofday) / 10

	var/msg = "Initializations complete within [time] second[time == 1 ? "" : "s"]!"

	to_chat(world, "<span class='boldannounce'>[msg]</span>")
	log_world(msg)

	SSplexora.serverinitdone(time)

	if (!current_runlevel)
		SetRunLevel(1)

	setup_cargo_boat()
	// Sort subsystems by display setting for easy access.
	#ifndef LOWMEMORYMODE
	sortTim(subsystems, GLOBAL_PROC_REF(cmp_subsystem_display))
	#endif
	// Set world options.
	world.change_fps(CONFIG_GET(number/fps))
	var/initialized_tod = REALTIMEOFDAY

	if(sleep_offline_after_initializations)
		world.sleep_offline = TRUE
	sleep(1)

	if(sleep_offline_after_initializations && CONFIG_GET(flag/resume_after_initializations))
		world.sleep_offline = FALSE
	initializations_finished_with_no_players_logged_in = initialized_tod < REALTIMEOFDAY - 10
	// Loop.
	Master.StartProcessing(0)
	SSgamemode.handle_picking_storyteller()
	#ifdef LOWMEMORYMODE
	low_memory_force_start()
	#endif

/datum/controller/master/proc/SetRunLevel(new_runlevel)
	var/old_runlevel = current_runlevel
	if(isnull(old_runlevel))
		old_runlevel = "NULL"

	testing("MC: Runlevel changed from [old_runlevel] to [new_runlevel]")
	current_runlevel = log(2, new_runlevel) + 1
	if(current_runlevel < 1)
		CRASH("Attempted to set invalid runlevel: [new_runlevel]")

// Starts the mc, and sticks around to restart it if the loop ever ends.
/datum/controller/master/proc/StartProcessing(delay)
	set waitfor = 0
	if(delay)
		sleep(delay)
	testing("Master starting processing")
	var/rtn = Loop()
	if (rtn > 0 || processing < 0)
		return //this was suppose to happen.
	//loop ended, restart the mc
	log_game("MC crashed or runtimed, restarting")
	message_admins("MC crashed or runtimed, restarting")
	var/rtn2 = Recreate_MC()
	if (rtn2 <= 0)
		log_game("Failed to recreate MC (Error code: [rtn2]), it's up to the failsafe now")
		message_admins("Failed to recreate MC (Error code: [rtn2]), it's up to the failsafe now")
		if(!Failsafe)
			new /datum/controller/failsafe()
		if(Failsafe)
			Failsafe.defcon = 2

// Main loop.
/datum/controller/master/proc/Loop()
	. = -1
	#ifdef LOWMEMORYMODE
	if(!initialized_all)
		var/total_count = 0
		try
			total_count = length(subsystems)
		catch
			total_count = 0
		for (var/lowmem_subsystem_index in 1 to total_count)
			var/datum/controller/subsystem/SS
			try
				SS = subsystems[lowmem_subsystem_index]
			catch
				continue
			if(!istype(SS))
				total_count--
				continue
			if(SS.initialized)
				total_count--
				continue
			if (SS.flags & SS_NO_INIT)
				total_count--
				continue
			if(!SS.lazy_load)
				total_count--
				continue
			SS.Initialize(REALTIMEOFDAY)
			CHECK_TICK
			total_count--
		if(total_count <= 0)
			initialized_all = TRUE
			sortTim(subsystems, GLOBAL_PROC_REF(cmp_subsystem_display))
	#endif

	//Prep the loop (most of this is because we want MC restarts to reset as much state as we can, and because
	//	local vars rock

	//all this shit is here so that flag edits can be refreshed by restarting the MC. (and for speed)
	var/list/tickersubsystems = list()
	var/list/runlevel_sorted_subsystems = list(list())	//ensure we always have at least one runlevel
	var/timer = world.time
	ensure_subsystems_list()
	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		ensure_subsystems_list()
		subsystem_count = length(subsystems)
	for (var/subsystem_index in 1 to subsystem_count)
		var/thing
		try
			thing = subsystems[subsystem_index]
		catch
			continue
		var/datum/controller/subsystem/SS = thing
		if(!istype(SS))
			continue
		if (SS.flags & SS_NO_FIRE)
			continue
		SS.queued_time = 0
		SS.queue_next = null
		SS.queue_prev = null
		SS.state = SS_IDLE
		if (SS.flags & SS_TICKER)
			try
				tickersubsystems += SS
			catch
				tickersubsystems = list(SS)
			// Timer subsystems aren't allowed to bunch up, so we offset them a bit
			timer += world.tick_lag * rand(0, 1)
			SS.next_fire = timer
			continue

		var/ss_runlevels = SS.runlevels
		var/added_to_any = FALSE
		var/bitflag_count = 0
		try
			bitflag_count = length(GLOB.bitflags)
		catch
			bitflag_count = 0
		for(var/I in 1 to bitflag_count)
			var/bitflag
			try
				bitflag = GLOB.bitflags[I]
			catch
				continue
			if(ss_runlevels & bitflag)
				while(length(runlevel_sorted_subsystems) < I)
					runlevel_sorted_subsystems += list(list())
				var/list/runlevel_list = runlevel_sorted_subsystems[I]
				try
					if(!(SS in runlevel_list))
						runlevel_list += SS
				catch
					runlevel_sorted_subsystems[I] = list(SS)
				added_to_any = TRUE
		if(!added_to_any)
			WARNING("[SS.name] subsystem is not SS_NO_FIRE but also does not have any runlevels set!")

	queue_head = null
	queue_tail = null
	//these sort by lower priorities first to reduce the number of loops needed to add subsequent SS's to the queue
	//(higher subsystems will be sooner in the queue, adding them later in the loop means we don't have to loop thru them next queue add)
	sortTim(tickersubsystems, GLOBAL_PROC_REF(cmp_subsystem_priority))
	var/runlevel_list_count = length(runlevel_sorted_subsystems)
	for(var/runlevel_index in 1 to runlevel_list_count)
		var/list/runlevel_subsystems
		try
			runlevel_subsystems = runlevel_sorted_subsystems[runlevel_index]
		catch
			continue
		if(!islist(runlevel_subsystems))
			runlevel_subsystems = list()
			runlevel_sorted_subsystems[runlevel_index] = runlevel_subsystems
		sortTim(runlevel_subsystems, GLOBAL_PROC_REF(cmp_subsystem_priority))
		try
			runlevel_subsystems += tickersubsystems
		catch
			runlevel_sorted_subsystems[runlevel_index] = tickersubsystems.Copy()

	var/cached_runlevel = current_runlevel
	var/list/current_runlevel_subsystems
	try
		current_runlevel_subsystems = runlevel_sorted_subsystems[cached_runlevel]
	catch
		current_runlevel_subsystems = list()

	init_timeofday = REALTIMEOFDAY
	init_time = world.time

	iteration = 1
	var/error_level = 0
	var/sleep_delta = 1
	var/list/subsystems_to_check

	//setup the stack overflow detector
	stack_end_detector = new()
	var/datum/stack_canary/canary = stack_end_detector.prime_canary()
	canary.use_variable()

	//the actual loop.

	while (1)
		tickdrift = max(0, MC_AVERAGE_FAST(tickdrift, (((REALTIMEOFDAY - init_timeofday) - (world.time - init_time)) / world.tick_lag)))
		var/starting_tick_usage = TICK_USAGE
		if (processing <= 0)
			current_ticklimit = TICK_LIMIT_RUNNING
			sleep(10)
			continue

		//Anti-tick-contention heuristics:
		//if there are mutiple sleeping procs running before us hogging the cpu, we have to run later.
		//	(because sleeps are processed in the order received, longer sleeps are more likely to run first)
		if (starting_tick_usage > TICK_LIMIT_MC) //if there isn't enough time to bother doing anything this tick, sleep a bit.
			sleep_delta *= 2
			current_ticklimit = TICK_LIMIT_RUNNING * 0.5
			sleep(world.tick_lag * (processing * sleep_delta))
			continue

		//Byond resumed us late. assume it might have to do the same next tick
		if (last_run + CEILING(world.tick_lag * (processing * sleep_delta), world.tick_lag) < world.time)
			sleep_delta += 1

		sleep_delta = MC_AVERAGE_FAST(sleep_delta, 1) //decay sleep_delta

		if (starting_tick_usage > (TICK_LIMIT_MC*0.75)) //we ran 3/4 of the way into the tick
			sleep_delta += 1

		//debug
		if (make_runtime)
			var/datum/controller/subsystem/SS
			SS.can_fire = 0

		if (!Failsafe || (Failsafe.processing_interval > 0 && (Failsafe.lasttick+(Failsafe.processing_interval*5)) < world.time))
			new/datum/controller/failsafe() // (re)Start the failsafe.

		//now do the actual stuff
		if (!queue_head || !(iteration % 3))
			var/checking_runlevel = current_runlevel
			if(cached_runlevel != checking_runlevel)
				//resechedule subsystems
				var/list/old_subsystems = current_runlevel_subsystems
				cached_runlevel = checking_runlevel
				try
					current_runlevel_subsystems = runlevel_sorted_subsystems[cached_runlevel]
				catch
					current_runlevel_subsystems = list()

				//now we'll go through all the subsystems we want to offset and give them a next_fire
				var/current_runlevel_subsystem_count = 0
				try
					current_runlevel_subsystem_count = length(current_runlevel_subsystems)
				catch
					current_runlevel_subsystems = list()
				for(var/current_runlevel_index in 1 to current_runlevel_subsystem_count)
					var/datum/controller/subsystem/SS
					try
						SS = current_runlevel_subsystems[current_runlevel_index]
					catch
						continue
					if(!istype(SS))
						continue
					//we only want to offset it if it's new and also behind
					var/was_in_old_subsystems = FALSE
					try
						was_in_old_subsystems = (SS in old_subsystems)
					catch
						was_in_old_subsystems = FALSE
					if(SS.next_fire > world.time || was_in_old_subsystems)
						continue
					SS.next_fire = world.time + world.tick_lag * rand(0, DS2TICKS(min(SS.wait, 2 SECONDS)))

			subsystems_to_check = current_runlevel_subsystems
		else
			subsystems_to_check = tickersubsystems

		if (CheckQueue(subsystems_to_check) <= 0)
			if (!SoftReset(tickersubsystems, runlevel_sorted_subsystems))
				log_world("MC: SoftReset() failed, crashing")
				return
			if (!error_level)
				iteration++
			error_level++
			current_ticklimit = TICK_LIMIT_RUNNING
			sleep(10)
			continue

		if (queue_head)
			if (RunQueue() <= 0)
				if (!SoftReset(tickersubsystems, runlevel_sorted_subsystems))
					log_world("MC: SoftReset() failed, crashing")
					return
				if (!error_level)
					iteration++
				error_level++
				current_ticklimit = TICK_LIMIT_RUNNING
				sleep(10)
				continue
		error_level--
		if (!queue_head) //reset the counts if the queue is empty, in the off chance they get out of sync
			queue_priority_count = 0
			queue_priority_count_bg = 0

		iteration++
		last_run = world.time
		src.sleep_delta = MC_AVERAGE_FAST(src.sleep_delta, sleep_delta)
		current_ticklimit = TICK_LIMIT_RUNNING
		if (processing * sleep_delta <= world.tick_lag)
			current_ticklimit -= (TICK_LIMIT_RUNNING * 0.25) //reserve the tail 1/4 of the next tick for the mc if we plan on running next tick
		sleep(world.tick_lag * (processing * sleep_delta))




// This is what decides if something should run.
/datum/controller/master/proc/CheckQueue(list/subsystemstocheck)
	. = 0 //so the mc knows if we runtimed

	//we create our variables outside of the loops to save on overhead
	var/datum/controller/subsystem/SS
	var/SS_flags

	var/subsystems_to_check_count = 0
	try
		subsystems_to_check_count = length(subsystemstocheck)
	catch
		return FALSE
	for (var/check_index in 1 to subsystems_to_check_count)
		try
			SS = subsystemstocheck[check_index]
		catch
			continue
		if(!istype(SS))
			continue
		if (SS.state != SS_IDLE)
			continue
		if (SS.can_fire <= 0)
			continue
		if (SS.next_fire > world.time)
			continue
		SS_flags = SS.flags
		if (SS_flags & SS_NO_FIRE)
			continue
		if ((SS_flags & (SS_TICKER|SS_KEEP_TIMING)) == SS_KEEP_TIMING && SS.last_fire + (SS.wait * 0.75) > world.time)
			continue
		if (SS.postponed_fires >= 1)
			SS.postponed_fires--
			SS.update_nextfire()
			continue
		if(!SS.enqueue())
			return FALSE
	. = 1


// Run thru the queue of subsystems to run, running them while balancing out their allocated tick precentage
/datum/controller/master/proc/RunQueue()
	. = 0
	var/datum/controller/subsystem/queue_node
	var/queue_node_flags
	var/queue_node_priority
	var/queue_node_paused

	var/current_tick_budget
	var/tick_precentage
	var/tick_remaining
	var/ran = TRUE //this is right
	var/ran_non_ticker = FALSE
	var/bg_calc //have we swtiched current_tick_budget to background mode yet?
	var/tick_usage

	//keep running while we have stuff to run and we haven't gone over a tick
	//	this is so subsystems paused eariler can use tick time that later subsystems never used
	while (ran && queue_head && TICK_USAGE < TICK_LIMIT_MC)
		ran = FALSE
		bg_calc = FALSE
		current_tick_budget = queue_priority_count
		queue_node = queue_head
		while (queue_node)
			if (ran && TICK_USAGE > TICK_LIMIT_RUNNING)
				break

			queue_node_flags = queue_node.flags
			queue_node_priority = queue_node.queued_priority

			//super special case, subsystems where we can't make them pause mid way through
			//if we can't run them this tick (without going over a tick)
			//we bump up their priority and attempt to run them next tick
			//(unless we haven't even ran anything this tick, since its unlikely they will ever be able run
			//	in those cases, so we just let them run)
			if (queue_node_flags & SS_NO_TICK_CHECK)
				if (queue_node.tick_usage > TICK_LIMIT_RUNNING - TICK_USAGE && ran_non_ticker)
					if (!(queue_node_flags & SS_BACKGROUND))
						queue_node.queued_priority += queue_priority_count * 0.1
						queue_priority_count -= queue_node_priority
						queue_priority_count += queue_node.queued_priority
						current_tick_budget -= queue_node_priority
						queue_node = queue_node.queue_next
					continue

			if (!bg_calc && (queue_node_flags & SS_BACKGROUND))
				current_tick_budget = queue_priority_count_bg
				bg_calc = TRUE

			tick_remaining = TICK_LIMIT_RUNNING - TICK_USAGE

			if (current_tick_budget > 0 && queue_node_priority > 0)
				tick_precentage = tick_remaining / (current_tick_budget / queue_node_priority)
			else
				tick_precentage = tick_remaining

			tick_precentage = max(tick_precentage*0.5, tick_precentage-queue_node.tick_overrun)

			current_ticklimit = round(TICK_USAGE + tick_precentage)

			if (!(queue_node_flags & SS_TICKER))
				ran_non_ticker = TRUE
			ran = TRUE

			queue_node_paused = (queue_node.state == SS_PAUSED || queue_node.state == SS_PAUSING)
			last_type_processed = queue_node

			queue_node.state = SS_RUNNING

			tick_usage = TICK_USAGE
			var/state = queue_node.ignite(queue_node_paused)
			tick_usage = TICK_USAGE - tick_usage

			if (state == SS_RUNNING)
				state = SS_IDLE
			current_tick_budget -= queue_node_priority


			if (tick_usage < 0)
				tick_usage = 0
			queue_node.tick_overrun = max(0, MC_AVG_FAST_UP_SLOW_DOWN(queue_node.tick_overrun, tick_usage-tick_precentage))
			queue_node.state = state

			if (state == SS_PAUSED)
				queue_node.paused_ticks++
				queue_node.paused_tick_usage += tick_usage
				queue_node = queue_node.queue_next
				continue

			queue_node.ticks = MC_AVERAGE(queue_node.ticks, queue_node.paused_ticks)
			tick_usage += queue_node.paused_tick_usage

			queue_node.tick_usage = MC_AVERAGE_FAST(queue_node.tick_usage, tick_usage)

			queue_node.cost = MC_AVERAGE_FAST(queue_node.cost, TICK_DELTA_TO_MS(tick_usage))
			queue_node.paused_ticks = 0
			queue_node.paused_tick_usage = 0

			if (bg_calc) //update our running total
				queue_priority_count_bg -= queue_node_priority
			else
				queue_priority_count -= queue_node_priority

			queue_node.last_fire = world.time
			queue_node.times_fired++

			queue_node.update_nextfire()

			queue_node.queued_time = 0

			//remove from queue
			queue_node.dequeue()

			queue_node = queue_node.queue_next

	. = 1

//resets the queue, and all subsystems, while filtering out the subsystem lists
//	called if any mc's queue procs runtime or exit improperly.
/datum/controller/master/proc/SoftReset(list/ticker_SS, list/runlevel_SS)
	. = 0
	log_world("MC: SoftReset called, resetting MC queue state.")
	if (!istype(subsystems) || !istype(ticker_SS) || !istype(runlevel_SS))
		log_world("MC: SoftReset: Bad list contents: '[subsystems]' '[ticker_SS]' '[runlevel_SS]'")
		return
	var/list/subsystemstocheck = list()
	var/list/source_lists = list(subsystems, ticker_SS)
	var/runlevel_count = 0
	try
		runlevel_count = length(runlevel_SS)
	catch
		runlevel_count = 0
	for(var/runlevel_index in 1 to runlevel_count)
		var/list/runlevel_entry
		try
			runlevel_entry = runlevel_SS[runlevel_index]
		catch
			continue
		if(islist(runlevel_entry))
			source_lists += list(runlevel_entry)
	for(var/list/source_list as anything in source_lists)
		var/source_count = 0
		try
			source_count = length(source_list)
		catch
			continue
		for(var/source_index in 1 to source_count)
			var/source_entry
			try
				source_entry = source_list[source_index]
			catch
				continue
			if(!(source_entry in subsystemstocheck))
				subsystemstocheck += source_entry

	var/subsystemstocheck_count = length(subsystemstocheck)
	for (var/check_index in 1 to subsystemstocheck_count)
		var/datum/controller/subsystem/SS = subsystemstocheck[check_index]
		if (!SS || !istype(SS))
			//list(SS) is so if a list makes it in the subsystem list, we remove the list, not the contents
			try
				subsystems -= list(SS)
				ticker_SS -= list(SS)
				var/runlevel_remove_count = length(runlevel_SS)
				for(var/runlevel_remove_index in 1 to runlevel_remove_count)
					var/list/runlevel_remove_list = runlevel_SS[runlevel_remove_index]
					runlevel_remove_list -= list(SS)
			catch
				EMPTY_BLOCK_GUARD
			log_world("MC: SoftReset: Found bad entry in subsystem list, '[SS]'")
			continue
		if (SS.queue_next && !istype(SS.queue_next))
			log_world("MC: SoftReset: Found bad data in subsystem queue, queue_next = '[SS.queue_next]'")
		SS.queue_next = null
		if (SS.queue_prev && !istype(SS.queue_prev))
			log_world("MC: SoftReset: Found bad data in subsystem queue, queue_prev = '[SS.queue_prev]'")
		SS.queue_prev = null
		SS.queued_priority = 0
		SS.queued_time = 0
		SS.state = SS_IDLE
	if (queue_head && !istype(queue_head))
		log_world("MC: SoftReset: Found bad data in subsystem queue, queue_head = '[queue_head]'")
	queue_head = null
	if (queue_tail && !istype(queue_tail))
		log_world("MC: SoftReset: Found bad data in subsystem queue, queue_tail = '[queue_tail]'")
	queue_tail = null
	queue_priority_count = 0
	queue_priority_count_bg = 0
	log_world("MC: SoftReset: Finished.")
	. = 1

	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		subsystem_count = 0
	for(var/subsystem_index in 1 to subsystem_count) //this is incase a runlevel error occurs, we don't want random shit being left queued up since if a queue ends up half parsed.
		var/datum/controller/subsystem/ss
		try
			ss = subsystems[subsystem_index]
		catch
			continue
		if(istype(ss))
			ss.state = SS_IDLE

/datum/controller/master/stat_entry(msg)
	msg = "(TickRate:[Master.processing]) (Iteration:[Master.iteration]) (TickLimit: [round(Master.current_ticklimit, 0.1)])"
	return msg

/datum/controller/master/StartLoadingMap()
	//disallow more than one map to load at once, multithreading it will just cause race conditions
	while(map_loading)
		stoplag()
	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		return
	for(var/subsystem_index in 1 to subsystem_count)
		var/datum/controller/subsystem/SS
		try
			SS = subsystems[subsystem_index]
		catch
			continue
		if(!istype(SS))
			continue
		SS.StartLoadingMap()
	map_loading = TRUE

/datum/controller/master/StopLoadingMap(bounds = null)
	map_loading = FALSE
	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		return
	for(var/subsystem_index in 1 to subsystem_count)
		var/datum/controller/subsystem/SS
		try
			SS = subsystems[subsystem_index]
		catch
			continue
		if(!istype(SS))
			continue
		SS.StopLoadingMap()


/datum/controller/master/proc/UpdateTickRate()
	if (!processing)
		return
	var/client_count = 0
	try
		client_count = length(GLOB.clients)
	catch
		GLOB.clients = list()
	if (client_count < CONFIG_GET(number/mc_tick_rate/disable_high_pop_mc_mode_amount))
		processing = CONFIG_GET(number/mc_tick_rate/base_mc_tick_rate)
	else if (client_count > CONFIG_GET(number/mc_tick_rate/high_pop_mc_mode_amount))
		processing = CONFIG_GET(number/mc_tick_rate/high_pop_mc_tick_rate)

/datum/controller/master/proc/OnConfigLoad()
	var/subsystem_count = 0
	try
		subsystem_count = length(subsystems)
	catch
		return
	for (var/subsystem_index in 1 to subsystem_count)
		var/datum/controller/subsystem/SS
		try
			SS = subsystems[subsystem_index]
		catch
			continue
		if(!istype(SS))
			continue
		SS.OnConfigLoad()
