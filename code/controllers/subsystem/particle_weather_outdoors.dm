/datum/time_of_day
	var/name = ""
	var/color = ""
	var/start = 6 HOURS // 6:00 am

/datum/time_of_day/dawn
	name = DAWN
	color = list("#394579", "#49385d", "#3a1537")
	start = 8 HOURS //8:00:00 AM

/datum/time_of_day/sunrise
	name = "Sunrise"
	color = "#F598AB"
	start = 9.5 HOURS  //9:30:00 AM

/datum/time_of_day/daytime
	name = "Daytime"
	color = list("#dbbfbf", "#ddd7bd", "#add1b0", "#a4c0ca", "#ae9dc6", "#d09fbf")
	start = 10 HOURS //10:00:00 AM

/datum/time_of_day/sunset
	name = "Sunset"
	color = "#ff8a63"
	start = 15 HOURS //3:00:00 PM

/datum/time_of_day/dusk
	name = DUSK
	color = list("#c26f56", "#c05271", "#b84933")
	start = 15.5 HOURS //3:30:00 PM

/datum/time_of_day/midnight
	name = "Midnight"
	color = list("#100a18", "#0c0412", "#0f0012")
	start = 16 HOURS //4:00:00 PM

GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_WORK)   /* turfs to be stateChecked */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_UPDATE) /* turfs to have their colors updated via corners (filter out the unroofed dudes) */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_CORNER) /* turfs to have their color/lights/etc updated */

#define SUNLIGHT_OVERLAY_CACHE_LIMIT 4096
#define SUNLIGHT_OVERLAY_QUANTIZATION 8

SUBSYSTEM_DEF(outdoor_effects)
	name = "Outdoor Weather Calc"
	wait = LIGHTING_INTERVAL
	flags = SS_TICKER
	init_order = INIT_ORDER_OUTDOOR_EFFECTS
	var/list/atom/movable/screen/plane_master/weather_effect/weather_planes_need_vis = list()

	var/list/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/sunlighting_planes = list()
	var/datum/time_of_day/current_step_datum
	var/datum/time_of_day/next_step_datum
	var/list/mutable_appearance/sunlight_overlays
	var/mutable_appearance/weather_overlay

	var/last_color = null
	var/picked_color
	//Ensure midnight is the liast step
	var/list/datum/time_of_day/time_cycle_steps = list(
		new /datum/time_of_day/dawn(),
		new /datum/time_of_day/sunrise(),
		new /datum/time_of_day/daytime(),
		new /datum/time_of_day/sunset(),
		new /datum/time_of_day/dusk(),
		new /datum/time_of_day/midnight()
	)
	var/alist/turf_weather_affectable_z_levels = alist()
	var/next_day = FALSE // Resets when station_time is less than the next start time.

/datum/controller/subsystem/outdoor_effects/Initialize(timeofday)
	#ifdef FORCE_RANDOM_WORLD_GEN
	return ..()
	#endif
	if(!initialized)
		for(var/zlevel in SSmapping.levels_by_trait(ZTRAIT_WEATHER_STUFF))
			if(SSmapping.level_trait(zlevel, ZTRAIT_IGNORE_WEATHER_TRAIT))
				continue
			turf_weather_affectable_z_levels[zlevel] = TRUE
		get_time_of_day()
		InitializeTurfs()
		initialized = TRUE
	fire(FALSE, TRUE)
	..()

/datum/controller/subsystem/outdoor_effects/stat_entry(msg)
	var/work_length = 0
	var/update_length = 0
	var/corner_length = 0
	try
		work_length = length(GLOB.SUNLIGHT_QUEUE_WORK)
	catch
		GLOB.SUNLIGHT_QUEUE_WORK = list()
	try
		update_length = length(GLOB.SUNLIGHT_QUEUE_UPDATE)
	catch
		GLOB.SUNLIGHT_QUEUE_UPDATE = list()
	try
		corner_length = length(GLOB.SUNLIGHT_QUEUE_CORNER)
	catch
		GLOB.SUNLIGHT_QUEUE_CORNER = list()
	msg = "W:[work_length]|U:[update_length]|C:[corner_length]"
	return ..()

/datum/controller/subsystem/outdoor_effects/proc/InitializeTurfs(list/targets)
	for(var/z in SSmapping.levels_by_trait(ZTRAIT_STATION))
		if(SSmapping.level_trait(z, ZTRAIT_IGNORE_WEATHER_TRAIT))
			continue
		try
			GLOB.SUNLIGHT_QUEUE_WORK += Z_TURFS(z)
		catch
			GLOB.SUNLIGHT_QUEUE_WORK = list()
			GLOB.SUNLIGHT_QUEUE_WORK += Z_TURFS(z)
	for(var/z in SSmapping.levels_by_trait(ZTRAIT_CENTCOM))
		if(SSmapping.level_trait(z, ZTRAIT_IGNORE_WEATHER_TRAIT))
			continue
		try
			GLOB.SUNLIGHT_QUEUE_WORK += Z_TURFS(z)
		catch
			GLOB.SUNLIGHT_QUEUE_WORK = list()
			GLOB.SUNLIGHT_QUEUE_WORK += Z_TURFS(z)

/datum/controller/subsystem/outdoor_effects/proc/check_cycle()
	if(!next_step_datum)
		get_time_of_day()
		return TRUE

	if(station_time() > next_step_datum.start)
		if(next_day)
			return FALSE
		get_time_of_day()
		return TRUE
	else if (next_day) // It is now the next morning, reset our next day
		next_day = FALSE

	return FALSE

/datum/controller/subsystem/outdoor_effects/proc/get_time_of_day()
	//Set our current color as last_color so newly initialized sunlight screens have a color
	if(current_step_datum)
		last_color = picked_color

	//Get the next time step (first time where NOW > START_TIME)
	//If we don't find one - grab the LAST time step (which should be midnight)
	var/time = station_time()
	var/datum/time_of_day/new_step = null

	for(var/i in 1 to length(time_cycle_steps))
		if(time >= time_cycle_steps[i].start)
			new_step = time_cycle_steps[i]
			next_step_datum = i == length(time_cycle_steps) ? time_cycle_steps[1] : time_cycle_steps[i + 1]

	//New time is the last time step in list (midnight) - next time will be the first step
	if(!new_step)
		new_step = time_cycle_steps[length(time_cycle_steps)]
		next_step_datum = time_cycle_steps[1]

	current_step_datum = new_step
	if(islist(current_step_datum.color))
		picked_color = pick(current_step_datum.color)
	else
		picked_color = current_step_datum.color

	// If the next start time is less than the current start time (i.e 10 PM vs 5 AM) then set our NextDay value
	if(next_step_datum.start <= current_step_datum.start)
		next_day = TRUE

	//If it is round-start, we wouldn't have had a current_step_datum, so set our last_color to the current one
	if(!last_color)
		last_color = picked_color

/* set sunlight color + add weather effect to clients */
/datum/controller/subsystem/outdoor_effects/fire(resumed, init_tick_checks)
	MC_SPLIT_TICK_INIT(3)
	if(!init_tick_checks)
		MC_SPLIT_TICK
	if(!islist(GLOB.SUNLIGHT_QUEUE_WORK))
		GLOB.SUNLIGHT_QUEUE_WORK = list()
	if(!islist(GLOB.SUNLIGHT_QUEUE_UPDATE))
		GLOB.SUNLIGHT_QUEUE_UPDATE = list()
	if(!islist(GLOB.SUNLIGHT_QUEUE_CORNER))
		GLOB.SUNLIGHT_QUEUE_CORNER = list()
	var/i = 0
	var/work_queue_length = 0
	var/update_queue_length = 0
	var/corner_queue_length = 0
	try
		work_queue_length = length(GLOB.SUNLIGHT_QUEUE_WORK)
	catch
		GLOB.SUNLIGHT_QUEUE_WORK = list()
	try
		update_queue_length = length(GLOB.SUNLIGHT_QUEUE_UPDATE)
	catch
		GLOB.SUNLIGHT_QUEUE_UPDATE = list()
	try
		corner_queue_length = length(GLOB.SUNLIGHT_QUEUE_CORNER)
	catch
		GLOB.SUNLIGHT_QUEUE_CORNER = list()

	//Add our weather particle obj to any new weather screens
	if(SSParticleWeather.initialized)
		var/weather_planes_length = 0
		try
			weather_planes_length = length(weather_planes_need_vis)
		catch
			weather_planes_need_vis = list()
		for(i in 1 to weather_planes_length)
			var/atom/movable/screen/plane_master/weather_effect/weather_plane
			try
				weather_plane = weather_planes_need_vis[i]
			catch
				weather_planes_need_vis = list()
				break
			if(weather_plane)
				weather_plane.vis_contents = list(SSParticleWeather.getweatherEffect())
			if(init_tick_checks)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				break
		if(i)
			try
				weather_planes_need_vis.Cut(1, i+1)
			catch
				weather_planes_need_vis = list()
			i = 0

	for(i in 1 to work_queue_length)
		var/turf/work_turf
		try
			work_turf = GLOB.SUNLIGHT_QUEUE_WORK[i]
		catch
			GLOB.SUNLIGHT_QUEUE_WORK = list()
			break
		if(!isturf(work_turf))
			continue
		work_turf.update_sky_and_weather_states()
		if(istype(work_turf.outdoor_effect))
			try
				if(!(work_turf.outdoor_effect in GLOB.SUNLIGHT_QUEUE_UPDATE))
					GLOB.SUNLIGHT_QUEUE_UPDATE += work_turf.outdoor_effect
			catch
				GLOB.SUNLIGHT_QUEUE_UPDATE = list(work_turf.outdoor_effect)

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if(i)
		try
			GLOB.SUNLIGHT_QUEUE_WORK.Cut(1, i+1)
		catch
			GLOB.SUNLIGHT_QUEUE_WORK = list()
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	for (i in 1 to update_queue_length)
		var/atom/movable/outdoor_effect/update_effect
		try
			update_effect = GLOB.SUNLIGHT_QUEUE_UPDATE[i]
		catch
			GLOB.SUNLIGHT_QUEUE_UPDATE = list()
			break
		if(!istype(update_effect))
			continue
		update_effect.process_state()
		update_outdoor_effect_overlays(update_effect)

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		try
			GLOB.SUNLIGHT_QUEUE_UPDATE.Cut(1, i+1)
		catch
			GLOB.SUNLIGHT_QUEUE_UPDATE = list()
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK

	// this list can get REALLY LONG so we do this to avoid list copies
	for (i in 1 to corner_queue_length)
		var/turf/corner_turf
		try
			corner_turf = GLOB.SUNLIGHT_QUEUE_CORNER[i]
		catch
			GLOB.SUNLIGHT_QUEUE_CORNER = list()
			break
		if(!isturf(corner_turf))
			continue
		corner_turf.turf_flags &= ~TURF_SUNLIGHT_QUEUED
		var/atom/movable/outdoor_effect/corner_effect = corner_turf.outdoor_effect

		/* if we haven't initialized but we are affected, create new and check state */
		if(!istype(corner_effect))
			corner_turf.outdoor_effect = new /atom/movable/outdoor_effect(corner_turf)
			corner_turf.update_sky_and_weather_states()
			corner_effect = corner_turf.outdoor_effect

			/* in case we aren't indoor somehow, wack us into the proc queue, we will be skipped on next indoor check */
			if(istype(corner_effect) && corner_effect.state != SKY_BLOCKED)
				try
					if(!(corner_effect in GLOB.SUNLIGHT_QUEUE_UPDATE))
						GLOB.SUNLIGHT_QUEUE_UPDATE += corner_effect
				catch
					GLOB.SUNLIGHT_QUEUE_UPDATE = list(corner_effect)

		if(!istype(corner_effect) || corner_effect.state != SKY_BLOCKED)
			continue

		//This might need to be run more liberally
		update_outdoor_effect_overlays(corner_effect)

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break

	if (i)
		try
			GLOB.SUNLIGHT_QUEUE_CORNER.Cut(1, i+1)
		catch
			GLOB.SUNLIGHT_QUEUE_CORNER = list()
		i = 0

	if(check_cycle())
		for (var/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/SP in sunlighting_planes)
			transition_sunlight_color(SP)

//Transition from our last color to our current color (i.e if it is going from daylight (white) to sunset (red), we transition to red in the first hour of sunset)
/datum/controller/subsystem/outdoor_effects/proc/transition_sunlight_color(atom/movable/screen/fullscreen/lighting_backdrop/sunlight/SP)
	/* transistion in an hour or time diff from now to our next step, whichever is smaller */
	if(!next_step_datum)
		get_time_of_day()
	var/timeDiff = min((1 HOURS / SSticker.station_time_rate_multiplier), daytimeDiff(station_time(), next_step_datum.start))
	animate(SP, color = picked_color, time = timeDiff)

// Updates overlays and vis_contents for outdoor effects
/datum/controller/subsystem/outdoor_effects/proc/update_outdoor_effect_overlays(atom/movable/outdoor_effect/OE)
	if(!istype(OE) || !OE.source_turf)
		return
	var/mutable_appearance/MA
	if ((OE.state != SKY_BLOCKED) || istype(OE.source_turf, /turf/closed/sea_fog))
		MA = get_sunlight_overlay(1, 1, 1, 1) /* fully lit */
	else //Indoor - do proper corner checks
		/* check if we are globally affected or not */
		var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new

		var/list/corners = OE.source_turf.corners
		if(!islist(corners) || !length(corners))
			OE.source_turf.generate_missing_corners()
			corners = OE.source_turf.corners
		if(!islist(corners) || !length(corners))
			MA = get_sunlight_overlay(0, 0, 0, 0)
			if(!MA)
				return
			OE.sunlight_overlay = MA
			OE.overlays = OE.weatherproof ? list(OE.sunlight_overlay) : list(OE.sunlight_overlay, get_weather_overlay())
			OE.luminosity = MA.luminosity
			return
		var/datum/lighting_corner/cr = dummy_lighting_corner
		var/datum/lighting_corner/cg = dummy_lighting_corner
		var/datum/lighting_corner/cb = dummy_lighting_corner
		var/datum/lighting_corner/ca = dummy_lighting_corner
		try
			cr = corners[3] || dummy_lighting_corner
			cg = corners[2] || dummy_lighting_corner
			cb = corners[4] || dummy_lighting_corner
			ca = corners[1] || dummy_lighting_corner
		catch
			MA = get_sunlight_overlay(0, 0, 0, 0)

		var/fr = cr.sunFalloff
		var/fg = cg.sunFalloff
		var/fb = cb.sunFalloff
		var/fa = ca.sunFalloff

		if(!MA)
			MA = get_sunlight_overlay(fr, fg, fb, fa)

	if(!MA)
		return
	OE.sunlight_overlay = MA
	//Get weather overlay if not weatherproof
	OE.overlays = OE.weatherproof ? list(OE.sunlight_overlay) : list(OE.sunlight_overlay, get_weather_overlay())
	OE.luminosity = MA.luminosity

//Retrieve an overlay from the list - create if necessary
/datum/controller/subsystem/outdoor_effects/proc/get_sunlight_overlay(fr = 0, fg = 0, fb = 0, fa = 0)
	var/qfr = round(CLAMP01(fr) * SUNLIGHT_OVERLAY_QUANTIZATION)
	var/qfg = round(CLAMP01(fg) * SUNLIGHT_OVERLAY_QUANTIZATION)
	var/qfb = round(CLAMP01(fb) * SUNLIGHT_OVERLAY_QUANTIZATION)
	var/qfa = round(CLAMP01(fa) * SUNLIGHT_OVERLAY_QUANTIZATION)
	var/index = "[qfr]|[qfg]|[qfb]|[qfa]"
	if(!islist(sunlight_overlays))
		sunlight_overlays = list()
	else
		try
			if(length(sunlight_overlays) > SUNLIGHT_OVERLAY_CACHE_LIMIT)
				sunlight_overlays.Cut()
		catch
			sunlight_overlays = list()
	var/mutable_appearance/overlay
	try
		overlay = sunlight_overlays[index]
	catch
		sunlight_overlays = list()
	if(!overlay)
		overlay = create_sunlight_overlay(qfr / SUNLIGHT_OVERLAY_QUANTIZATION, qfg / SUNLIGHT_OVERLAY_QUANTIZATION, qfb / SUNLIGHT_OVERLAY_QUANTIZATION, qfa / SUNLIGHT_OVERLAY_QUANTIZATION)
		try
			sunlight_overlays[index] = overlay
		catch
			sunlight_overlays = list()
	return overlay

//get our weather overlay
/datum/controller/subsystem/outdoor_effects/proc/get_weather_overlay() //TODO VANDERLIN: Restore this to 32x48 for some extra
	if(weather_overlay)
		return weather_overlay
	weather_overlay = new /mutable_appearance()
	weather_overlay.icon = 'icons/effects/weather_overlay.dmi'
	weather_overlay.icon_state = "weather_overlay"
	weather_overlay.plane = WEATHER_OVERLAY_PLANE
	weather_overlay.blend_mode = BLEND_OVERLAY
	weather_overlay.invisibility = INVISIBILITY_LIGHTING
	return weather_overlay

//Create an overlay appearance from corner values
/datum/controller/subsystem/outdoor_effects/proc/create_sunlight_overlay(fr, fg, fb, fa)
	var/mutable_appearance/MA = new /mutable_appearance()
	MA.icon = LIGHTING_ICON
	MA.icon_state = null
	MA.plane = SUNLIGHTING_PLANE /* we put this on a lower level than lighting so we dont multiply anything */
	MA.blend_mode = BLEND_OVERLAY
	MA.invisibility = INVISIBILITY_LIGHTING

	//MA gets applied as an overlay, but we pull luminosity out to set our outdoor_effect object's lum
#if LIGHTING_SOFT_THRESHOLD != 0
	MA.luminosity = max(fr, fg, fb, fa) > LIGHTING_SOFT_THRESHOLD
#else
	MA.luminosity = max(fr, fg, fb, fa) > 1e-6
#endif

	if(fr == 1 && fg == 1 && fb == 1 && fa == 1)
		MA.color = LIGHTING_BASE_MATRIX
	else if(!MA.luminosity)
		MA.color = SUNLIGHT_DARK_MATRIX
	else
		MA.color = list(
			fr, fr, fr, 00,
			fg, fg, fg, 00,
			fb, fb, fb, 00,
			fa, fa, fa, 00,
			00, 00, 00, 01
		)
	return MA

#undef SUNLIGHT_OVERLAY_CACHE_LIMIT
#undef SUNLIGHT_OVERLAY_QUANTIZATION
