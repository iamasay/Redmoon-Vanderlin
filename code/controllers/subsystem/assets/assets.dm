SUBSYSTEM_DEF(assets)
	name = "Assets"
	lazy_load = FALSE
	init_order = INIT_ORDER_ASSETS
	flags = SS_NO_FIRE
	var/list/datum/asset_cache_item/cache = list()
	var/list/preload = list()
	var/datum/asset_transport/transport = new()

/datum/controller/subsystem/assets/OnConfigLoad()
	var/newtransporttype = /datum/asset_transport
	switch (CONFIG_GET(string/asset_transport))
		if ("webroot")
			newtransporttype = /datum/asset_transport/webroot

	if (newtransporttype == transport.type)
		return

	var/datum/asset_transport/newtransport = new newtransporttype ()
	if (newtransport.validate_config())
		transport = newtransport
	try
		transport.Load()
	catch
		transport = new /datum/asset_transport

/datum/controller/subsystem/assets/Initialize(timeofday)
	if(!islist(cache))
		cache = list()
	var/list/asset_types = typesof(/datum/asset)
	var/asset_type_count = 0
	try
		asset_type_count = length(asset_types)
	catch
		asset_type_count = 0
	for(var/asset_index in 1 to asset_type_count)
		var/datum/asset/asset
		try
			asset = asset_types[asset_index]
			if(!IS_ABSTRACT(asset))
				load_asset_datum(asset)
		catch
			continue

	try
		transport.Initialize(cache)
	catch
		transport = new /datum/asset_transport
		transport.Initialize(cache)
	return ..()
