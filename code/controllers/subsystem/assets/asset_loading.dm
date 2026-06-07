
/// Allows us to lazyload asset datums
/// Anything inserted here will fully load if directly gotten
/// So this just serves to remove the requirement to load assets fully during init
SUBSYSTEM_DEF(asset_loading)
	name = "Asset Loading"
	priority = FIRE_PRIORITY_ASSETS
	flags = SS_NO_INIT
	runlevels = RUNLEVEL_LOBBY|RUNLEVELS_DEFAULT
	var/list/datum/asset/generate_queue = list()
	var/last_queue_len = 0

/datum/controller/subsystem/asset_loading/fire(resumed)
	if(!islist(generate_queue))
		generate_queue = list()
	while(TRUE)
		var/queue_length = 0
		try
			queue_length = length(generate_queue)
		catch
			generate_queue = list()
			break
		if(!queue_length)
			break
		var/datum/asset/to_load
		try
			to_load = generate_queue[queue_length]
		catch
			generate_queue = list()
			break

		try
			to_load?.queued_generation()
		catch
			EMPTY_BLOCK_GUARD

		if(MC_TICK_CHECK)
			return
		try
			last_queue_len = length(generate_queue)
			generate_queue.len--
		catch
			generate_queue = list()
			break
	// We just emptied the queue
	var/queue_empty = FALSE
	try
		queue_empty = !length(generate_queue)
	catch
		queue_empty = TRUE
	if(last_queue_len && queue_empty)
		// Clean up cached icons, freeing memory.
		rustg_iconforge_cleanup()

/datum/controller/subsystem/asset_loading/proc/queue_asset(datum/asset/queue)
#ifdef DO_NOT_DEFER_ASSETS
	stack_trace("We queued an instance of [queue.type] for lateloading despite not allowing it")
#endif
	if(!islist(generate_queue))
		generate_queue = list()
	try
		if(!(queue in generate_queue))
			generate_queue += queue
	catch
		generate_queue = list(queue)

/datum/controller/subsystem/asset_loading/proc/dequeue_asset(datum/asset/queue)
	try
		if(islist(generate_queue))
			generate_queue -= queue
	catch
		generate_queue = list()
