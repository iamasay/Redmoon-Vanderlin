#define INIT_ORDER_INTERACTIONS		-150

PROCESSING_SUBSYSTEM_DEF(interactions)
	name = "Interactions"
	wait = 0.5 SECONDS
	init_order = INIT_ORDER_INTERACTIONS
	flags = SS_BACKGROUND|SS_POST_FIRE_TIMING
	VAR_PROTECTED/list/blacklisted_mobs = list(
		/mob/dead,
		/mob/dview,
		/mob/camera,
		/mob/living/simple_animal,
	)
	VAR_PROTECTED/initialized_blacklist
	var/list/interactions = list()

/datum/controller/subsystem/processing/interactions/Initialize(timeofday)
	prepare_interactions()
	prepare_blacklisted_mobs()
	. = ..()
	log_world("Loaded [LAZYLEN(interactions)] interactions!")

/datum/controller/subsystem/processing/interactions/stat_entry(msg)
	msg += "|🖐:[LAZYLEN(interactions)]|"
	msg += "🚫👨:[LAZYLEN(blacklisted_mobs)]"
	return ..()

/// Makes the interactions, they're also a global list because having it as a list and just hanging around there is stupid
/datum/controller/subsystem/processing/interactions/proc/prepare_interactions()
	var/list/old_interactions = interactions
	interactions = list()
	if(islist(old_interactions))
		try
			for(var/interaction_key in old_interactions)
				var/datum/interaction/old_interaction = old_interactions[interaction_key]
				if(old_interaction)
					qdel(old_interaction)
		catch
			EMPTY_BLOCK_GUARD
	for(var/datum/interaction/interaction_type as anything in subtypesof(/datum/interaction))
		var/interaction_description
		try
			interaction_description = initial(interaction_type.description)
		catch
			continue
		if(!interaction_description)
			continue
		var/datum/interaction/interaction
		try
			interaction = new interaction_type()
		catch
			continue
		if(interaction)
			interactions["[interaction.type]"] = interaction

/// Blacklisting!
/datum/controller/subsystem/processing/interactions/proc/prepare_blacklisted_mobs()
	if(initialized_blacklist && islist(blacklisted_mobs))
		return
	blacklisted_mobs = typecacheof(list(
		/mob/dead,
		/mob/dview,
		/mob/camera,
		/mob/living/simple_animal,
	))
	initialized_blacklist = TRUE

/*
 * Lewd interactions have a blacklist for certain mobs. When we evalute the user and target, both of
 * their requirements must be satisfied, and the mob must not be of a blacklisted type.
*/
/datum/controller/subsystem/processing/interactions/proc/is_blacklisted(mob/living/creature)
	if(!creature || !initialized_blacklist)
		return TRUE
	if(is_type_in_typecache(creature, blacklisted_mobs))
		return TRUE
