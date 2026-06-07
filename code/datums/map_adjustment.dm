//PORT OF https://github.com/BeeStation/BeeStation-Hornet/pull/11210
/*
 *	[What does this do?]
 * 		It supports to make adjustment for each map
 *
 * 	[Why don't you just make this with map json file?]
 * 		Some stuff is easy to mistake.
 * 		Being a part of DM files can make a failsafe.
 *
*/
/datum/map_adjustment
	/// key of map_adjustment. It is used to check if '/datum/map_config/var/map_file' is matched
	var/map_file_name // = "vanderlin.dmm"
	/// Jobs that this map won't use
	var/list/blacklist
	/// Jobs that have slots changed /datum/job = num
	var/list/slot_adjust
	/// Jobs that have species adjustments /datum/job = list("humen")
	var/list/species_adjust
	/// Jobs that have gender adjustments /datum/job = list(MALE, FEMALE)
	var/list/sexes_adjust
	/// Jobs that have age adjustments /datum/job = list(AGE_CHILD, AGE_ADULT, AGE_MIDDLEAGED, AGE_OLD, AGE_IMMORTAL)
	var/list/ages_adjust
	/// Migrant waves that are banned from spawning.
	/// This doesn't handle downgraded waves so if can_roll is true on one, it needs to be added.
	/// /datum/migrant_wave = list(/datum/migrant_wave/crusade)
	var/list/migrant_blacklist

/// called on map config is loaded.
/// You need to change things manually here.
/datum/map_adjustment/proc/on_mapping_init()
	return

/// called upon job datum creation. Override this proc to change.
/datum/map_adjustment/proc/job_change()
	if(islist(blacklist))
		var/blacklist_count = 0
		try
			blacklist_count = length(blacklist)
		catch
			blacklist_count = 0
		for(var/i in 1 to blacklist_count)
			var/job
			try
				job = blacklist[i]
				change_job_position(job, 0)
				var/datum/job/J = SSjob.GetJobType(job)
				J?.job_flags &= ~(JOB_NEW_PLAYER_JOINABLE)
			catch
				continue
	if(islist(slot_adjust))
		var/slot_adjust_count = 0
		try
			slot_adjust_count = length(slot_adjust)
		catch
			slot_adjust_count = 0
		for(var/i in 1 to slot_adjust_count)
			var/job
			try
				job = slot_adjust[i]
				change_job_position(job, slot_adjust[job])
			catch
				continue
	if(islist(species_adjust))
		var/species_adjust_count = 0
		try
			species_adjust_count = length(species_adjust)
		catch
			species_adjust_count = 0
		for(var/i in 1 to species_adjust_count)
			var/job
			try
				job = species_adjust[i]
				var/datum/job/J = SSjob.GetJobType(job)
				J?.allowed_races = species_adjust[job]
			catch
				continue
	if(islist(sexes_adjust))
		var/sexes_adjust_count = 0
		try
			sexes_adjust_count = length(sexes_adjust)
		catch
			sexes_adjust_count = 0
		for(var/i in 1 to sexes_adjust_count)
			var/job
			try
				job = sexes_adjust[i]
				var/datum/job/J = SSjob.GetJobType(job)
				J?.allowed_sexes = sexes_adjust[job]
			catch
				continue
	if(islist(ages_adjust))
		var/ages_adjust_count = 0
		try
			ages_adjust_count = length(ages_adjust)
		catch
			ages_adjust_count = 0
		for(var/i in 1 to ages_adjust_count)
			var/job
			try
				job = ages_adjust[i]
				var/datum/job/J = SSjob.GetJobType(job)
				J?.allowed_ages = ages_adjust[job]
			catch
				continue
	// Now migrants
	if(islist(migrant_blacklist))
		var/migrant_blacklist_count = 0
		try
			migrant_blacklist_count = length(migrant_blacklist)
		catch
			migrant_blacklist_count = 0
		for(var/i in 1 to migrant_blacklist_count)
			var/migrant
			try
				migrant = migrant_blacklist[i]
				var/datum/migrant_wave/W = MIGRANT_WAVE(migrant)
				W?.can_roll = FALSE
			catch
				continue

/**
 * job_type`</datum/job/J>`: Type of the job that's being adjusted \
 * spawn_positions`<number, null>`: Roundstart positions, if null will not be adjusted \
 * total_positions`<number, null>`: Latejoin positions, if null will use spawn_positions
 **/
/datum/map_adjustment/proc/change_job_position(job_type, spawn_positions = null, total_positions = null)
	SHOULD_NOT_OVERRIDE(TRUE) // no reason to override for a new behaviour
	PROTECTED_PROC(TRUE) // no reason to call this outside of /map_adjustment datum. (I didn't add _underbar_ to the proc name because you use this frequently)
	var/datum/job/adjusting_job = SSjob.GetJobType(job_type)
	if(!adjusting_job)
		log_world("Failed to adjust a job position: [job_type]")
		return
	if(isnull(spawn_positions) && isnull(total_positions))
		log_world("change_job_position called without any positions to set for [job_type]")
		return

	if(isnum(spawn_positions))
		adjusting_job.spawn_positions = spawn_positions

	if(isnull(total_positions)) //we can have spawn slots but no total slots, see lord
		total_positions = spawn_positions
	if(isnum(total_positions))
		adjusting_job.total_positions = total_positions
