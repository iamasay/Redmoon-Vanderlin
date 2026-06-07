/proc/setup_cargo_boat()
	if(!islist(GLOB.lifts))
		return
	var/list/lifts = GLOB.lifts
	var/lift_count = 0
	try
		lift_count = length(lifts)
	catch
		return
	for(var/i in 1 to lift_count)
		var/obj/structure/industrial_lift/tram/master
		try
			master = lifts[i]
		catch
			return
		if(!istype(master))
			continue
		var/datum/lift_master/tram/master_datum = master.lift_master_datum
		if(!master_datum)
			continue
		var/obj/effect/landmark/tram/queued_path/cargo_map_enter/located_enter = master_datum.idle_platform
		if(!istype(located_enter))
			continue
		SSmerchant.cargo_boat = master.lift_master_datum
		SSmerchant.cargo_boat.hide_tram()
		break

