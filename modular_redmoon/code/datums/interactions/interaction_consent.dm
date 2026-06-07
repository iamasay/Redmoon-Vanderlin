/// Consent pref helpers for the ERP interaction panel (ported from BlueMoon MobInteraction).

/proc/pref_to_num(pref)
	switch(pref)
		if("Yes")
			return 1
		if("Ask")
			return 2
		else
			return 0

/proc/get_interaction_content_type(datum/interaction/I)
	if(!I)
		return INTERACTION_NORMAL
	if(istype(I, /datum/interaction/lewd))
		if(I.interaction_flags & INTERACTION_FLAG_EXTREME_CONTENT)
			return INTERACTION_EXTREME
		if(I.interaction_flags & INTERACTION_FLAG_UNHOLY_CONTENT)
			return INTERACTION_UNHOLY
		return INTERACTION_LEWD
	return INTERACTION_NORMAL

/proc/is_favorite_interaction(list/favorites, interaction_type)
	if(!length(favorites))
		return FALSE
	if(interaction_type in favorites)
		return TRUE
	return "[interaction_type]" in favorites

/proc/interaction_passes_user_prefs(datum/interaction/I, datum/preferences/prefs)
	var/content_type = get_interaction_content_type(I)
	if(content_type == INTERACTION_NORMAL)
		return TRUE
	if(!prefs || !(prefs.toggles & VERB_CONSENT))
		return FALSE
	switch(content_type)
		if(INTERACTION_LEWD)
			return TRUE
		if(INTERACTION_UNHOLY)
			return pref_to_num(prefs.unholypref)
		if(INTERACTION_EXTREME)
			return pref_to_num(prefs.extremepref)
	return TRUE

/proc/interaction_passes_target_prefs(datum/interaction/I, mob/living/user, mob/living/target)
	if(user == target)
		return interaction_passes_user_prefs(I, user.client?.prefs)

	var/content_type = get_interaction_content_type(I)
	if(content_type == INTERACTION_NORMAL)
		return TRUE

	if(!target?.ckey)
		return TRUE

	if(!target.client)
		if(content_type != INTERACTION_NORMAL && (I.interaction_flags & INTERACTION_FLAG_OOC_CONSENT))
			return FALSE
		return TRUE

	var/datum/preferences/prefs = target.client.prefs
	if(content_type == INTERACTION_LEWD)
		return !!(prefs.toggles & VERB_CONSENT)
	if(content_type == INTERACTION_UNHOLY)
		return (prefs.toggles & VERB_CONSENT) && pref_to_num(prefs.unholypref)
	if(content_type == INTERACTION_EXTREME)
		return (prefs.toggles & VERB_CONSENT) && pref_to_num(prefs.extremepref)
	return TRUE

/proc/interaction_passes_ranged_prefs(datum/interaction/I, mob/living/user, mob/living/target)
	if(!(I.interaction_flags & INTERACTION_FLAG_RANGED_CONSENT))
		return TRUE
	var/datum/preferences/user_prefs = user.client?.prefs
	if(!user_prefs || !(user_prefs.toggles & RANGED_VERBS_CONSENT))
		return FALSE
	if(user == target || !target?.client)
		return TRUE
	return !!(target.client.prefs.toggles & RANGED_VERBS_CONSENT)

/proc/interaction_passes_self_target_flag(datum/interaction/I, mob/living/user, mob/living/target)
	if(user == target)
		return !!(I.interaction_flags & INTERACTION_FLAG_USER_IS_TARGET)
	return !(I.interaction_flags & INTERACTION_FLAG_USER_IS_TARGET)

/proc/interaction_visible_in_panel(datum/interaction/I, mob/living/user, mob/living/target)
	if(!I || !user || !target)
		return FALSE
	if(I.interaction_flags & INTERACTION_FLAG_HIDE_IN_PANEL)
		return FALSE
	if(!interaction_passes_self_target_flag(I, user, target))
		return FALSE
	if(!interaction_passes_user_prefs(I, user.client?.prefs))
		return FALSE
	if(!interaction_passes_target_prefs(I, user, target))
		return FALSE
	if(!interaction_passes_ranged_prefs(I, user, target))
		return FALSE
	return TRUE

/proc/cmp_interaction_action(list/a, list/b)
	var/fav_a = a["is_favorite"] ? 1 : 0
	var/fav_b = b["is_favorite"] ? 1 : 0
	if(fav_a != fav_b)
		return fav_b - fav_a
	var/type_a = a["type"]
	var/type_b = b["type"]
	if(type_a != type_b)
		return type_a - type_b
	return sorttext(ckey(a["name"]), ckey(b["name"]))

/proc/sort_interaction_actions(list/actions)
	if(!length(actions))
		return list()
	var/list/sorted = actions.Copy()
	sortTim(sorted, GLOBAL_PROC_REF(cmp_interaction_action))
	return sorted
