/// Base browse_rsc asset transport
/datum/asset_transport
	var/name = "Simple browse_rsc asset transport"
	var/static/list/preload
	/// Don't mutate the filename of assets when sending via browse_rsc.
	/// This is to make it easier to debug issues with assets, and allow server operators to bypass issues that make it to production.
	/// If turning this on fixes asset issues, something isn't using get_asset_url and the asset isn't marked legacy, fix one of those.
	var/dont_mutate_filenames = FALSE

/// Called when the transport is loaded by the config controller, not called on the default transport unless it gets loaded by a config change.
/datum/asset_transport/proc/Load()
	if (CONFIG_GET(flag/asset_simple_preload))
		if(!islist(GLOB.clients))
			GLOB.clients = list()
		var/client_count = 0
		try
			client_count = length(GLOB.clients)
		catch
			GLOB.clients = list()
		for(var/client_index in 1 to client_count)
			var/client/C
			try
				C = GLOB.clients[client_index]
				if(C)
					addtimer(CALLBACK(src, PROC_REF(send_assets_slow), C, preload), 1 SECONDS)
			catch
				continue

/// Initialize - Called when SSassets initializes.
/datum/asset_transport/proc/Initialize(list/assets)
	try
		preload = islist(assets) ? assets.Copy() : list()
	catch
		preload = list()
	if (!CONFIG_GET(flag/asset_simple_preload))
		return
	if(!islist(GLOB.clients))
		GLOB.clients = list()
	var/client_count = 0
	try
		client_count = length(GLOB.clients)
	catch
		GLOB.clients = list()
	for(var/client_index in 1 to client_count)
		var/client/C
		try
			C = GLOB.clients[client_index]
			if(C)
				addtimer(CALLBACK(src, PROC_REF(send_assets_slow), C, preload), 1 SECONDS)
		catch
			continue

/**
 * Register a browser asset with the asset cache system.
 * returns a /datum/asset_cache_item.
 * mutiple calls to register the same asset under the same asset_name return the same datum.
 *
 * Arguments:
 * * asset_name - the identifier of the asset.
 * * asset - the actual asset file (or an asset_cache_item datum).
 * * file_hash - optional, a hash of the contents of the asset files contents. used so asset_cache_item doesnt have to hash it again
 * * dmi_file_path - optional, means that the given asset is from the rsc and thus we dont need to do some expensive operations
 */
/datum/asset_transport/proc/register_asset(asset_name, asset, file_hash, dmi_file_path)
	if(!islist(SSassets.cache))
		SSassets.cache = list()
	var/datum/asset_cache_item/ACI = asset
	if (!istype(ACI))
		ACI = new(asset_name, asset, file_hash, dmi_file_path)
		if (!ACI || !ACI.hash)
			log_asset("ERROR: Invalid asset: [asset_name]:[asset]:[ACI]")
			return null
	var/datum/asset_cache_item/OACI
	try
		OACI = SSassets.cache[asset_name]
	catch
		SSassets.cache = list()
		OACI = null
	if (OACI)
		try
			OACI.legacy = ACI.legacy = (ACI.legacy|OACI.legacy)
			OACI.namespace_parent = ACI.namespace_parent = (ACI.namespace_parent | OACI.namespace_parent)
			OACI.namespace = OACI.namespace || ACI.namespace
			if (OACI.hash != ACI.hash)
				var/error_msg = "ERROR: new asset added to the asset cache with the same name as another asset: [asset_name] existing asset hash: [OACI.hash] new asset hash:[ACI.hash]"
				stack_trace(error_msg)
				log_asset(error_msg)
			else
				if (length(ACI.namespace))
					return ACI
				return OACI
		catch
			EMPTY_BLOCK_GUARD

	try
		SSassets.cache[asset_name] = ACI
	catch
		SSassets.cache = list()
		SSassets.cache[asset_name] = ACI
	return ACI

/// Immediately removes an asset from the asset cache.
/datum/asset_transport/proc/unregister_asset(asset_name)
	try
		if(!islist(SSassets.cache))
			SSassets.cache = list()
		SSassets.cache[asset_name] = null
		SSassets.cache.Remove(null)
	catch
		SSassets.cache = list()

/// Returns a url for a given asset.
/// asset_name - Name of the asset.
/// asset_cache_item - asset cache item datum for the asset, optional, overrides asset_name
/datum/asset_transport/proc/get_asset_url(asset_name, datum/asset_cache_item/asset_cache_item)
	if(!islist(SSassets.cache))
		SSassets.cache = list()
	if (!istype(asset_cache_item))
		try
			asset_cache_item = SSassets.cache[asset_name]
		catch
			asset_cache_item = null
	if(!istype(asset_cache_item))
		return url_encode("[asset_name]")
	// To ensure code that breaks on cdns breaks in local testing, we only
	// use the normal filename on legacy assets and name space assets.
	var/keep_local_name = dont_mutate_filenames \
		|| asset_cache_item.legacy \
		|| asset_cache_item.keep_local_name \
		|| (asset_cache_item.namespace && !asset_cache_item.namespace_parent)
	if (keep_local_name)
		return url_encode(asset_cache_item.name)
	return url_encode("asset.[asset_cache_item.hash][asset_cache_item.ext]")


/// Sends a list of browser assets to a client
/// client - a client or mob
/// asset_list - A list of asset filenames to be sent to the client. Can optionally be assoicated with the asset's asset_cache_item datum.
/// Returns TRUE if any assets were sent.
/datum/asset_transport/proc/send_assets(client/client, list/asset_list)
#if defined(UNIT_TESTS)
	return
#endif

	if (!istype(client))
		if (ismob(client))
			var/mob/our_mob = client
			if (our_mob.client)
				client = our_mob.client
			else //no stacktrace because this will mainly happen because the client went away
				return
		else
			CRASH("Invalid argument: client: `[client]`")
	if (!islist(asset_list))
		asset_list = list(asset_list)
	if(!islist(SSassets.cache))
		SSassets.cache = list()
	if(!islist(client.sent_assets))
		client.sent_assets = list()
	var/list/unreceived = list()

	var/asset_count = 0
	try
		asset_count = length(asset_list)
	catch
		return FALSE
	for(var/asset_index in 1 to asset_count)
		var/asset_name
		var/datum/asset_cache_item/ACI
		try
			asset_name = asset_list[asset_index]
			ACI = asset_list[asset_name]
			if (!istype(ACI))
				ACI = SSassets.cache[asset_name]
		catch
			continue
		if (!istype(ACI))
			log_asset("ERROR: can't send asset `[asset_name]`: unregistered or invalid state: `[ACI]`")
			continue
		var/asset_file = ACI.resource
		if (!asset_file)
			log_asset("ERROR: can't send asset `[asset_name]`: invalid registered resource: `[ACI.resource]`")
			continue

		var/asset_hash = ACI.hash
		var/new_asset_name = asset_name
		var/keep_local_name = dont_mutate_filenames \
			|| ACI.legacy \
			|| ACI.keep_local_name \
			|| (ACI.namespace && !ACI.namespace_parent)
		if (!keep_local_name)
			new_asset_name = "asset.[ACI.hash][ACI.ext]"
		var/already_sent = FALSE
		try
			already_sent = client.sent_assets[new_asset_name] == asset_hash
		catch
			client.sent_assets = list()
			already_sent = FALSE
		if (already_sent)
			if (GLOB.Debug2)
				log_asset("DEBUG: Skipping send of `[asset_name]` (as `[new_asset_name]`) for `[client]` because it already exists in the client's sent_assets list")
			continue
		unreceived[asset_name] = ACI

	if (unreceived.len)
		if (unreceived.len >= ASSET_CACHE_TELL_CLIENT_AMOUNT)
			to_chat(client, span_info("Sending Resources..."))

		var/unreceived_count = 0
		try
			unreceived_count = length(unreceived)
		catch
			unreceived_count = 0
		for(var/unreceived_index in 1 to unreceived_count)
			var/asset_name
			var/new_asset_name
			var/datum/asset_cache_item/ACI
			try
				asset_name = unreceived[unreceived_index]
				new_asset_name = asset_name
				ACI = unreceived[asset_name]
			catch
				continue
			var/keep_local_name = dont_mutate_filenames \
				|| ACI.legacy \
				|| ACI.keep_local_name \
				|| (ACI.namespace && !ACI.namespace_parent)
			if (!keep_local_name)
				new_asset_name = "asset.[ACI.hash][ACI.ext]"
			log_asset("Sending asset `[asset_name]` to client `[client]` as `[new_asset_name]`")
			try
				client << browse_rsc(ACI.resource, new_asset_name)
			catch
				continue

			try
				client.sent_assets[new_asset_name] = ACI.hash
			catch
				client.sent_assets = list()
				client.sent_assets[new_asset_name] = ACI.hash

		try
			addtimer(CALLBACK(client, TYPE_PROC_REF(/client, asset_cache_update_json)), 1 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)
		catch
			EMPTY_BLOCK_GUARD
		return TRUE
	return FALSE

/// Precache files without clogging up the browse() queue, used for passively sending files on connection start.
/datum/asset_transport/proc/send_assets_slow(client/client, list/files, filerate = SLOW_ASSET_SEND_RATE)
	var/startingfilerate = filerate
	if(!islist(files))
		files = list(files)
	var/file_count = 0
	try
		file_count = length(files)
	catch
		file_count = 0
	for(var/file_index in 1 to file_count)
		var/file
		try
			file = files[file_index]
		catch
			continue
		if (!client)
			break
		if (send_assets(client, file))
			if (!(--filerate))
				filerate = startingfilerate
				try
					client.browse_queue_flush()
				catch
					EMPTY_BLOCK_GUARD
			stoplag(0) //queuing calls like this too quickly can cause issues in some client versions

/// Check the config is valid to load this transport
/// Returns TRUE or FALSE
/datum/asset_transport/proc/validate_config(log = TRUE)
	return TRUE
