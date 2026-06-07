/// Consent and lewd preference UI for the character editor (Customization window).

#define CONSENT_YES_ASK_NO list("Yes", "Ask", "No")
#define CONSENT_YES_NO list("Yes", "No")

/proc/cycle_consent_yes_ask_no(current)
	switch(current)
		if("Yes")
			return "Ask"
		if("Ask")
			return "No"
		else
			return "Yes"

/proc/cycle_consent_yes_no(current)
	return current == "Yes" ? "No" : "Yes"

/proc/sanitize_consent_yes_ask_no(value, default = "Ask")
	if(value in CONSENT_YES_ASK_NO)
		return value
	return default

/proc/sanitize_consent_yes_no(value, default = "No")
	if(value in CONSENT_YES_NO)
		return value
	return default

/datum/preferences/proc/sanitize_consent_preferences()
	erppref = sanitize_consent_yes_ask_no(erppref)
	nonconpref = sanitize_consent_yes_ask_no(nonconpref)
	vorepref = sanitize_consent_yes_ask_no(vorepref)
	tattoopref = sanitize_consent_yes_ask_no(tattoopref)
	extremepref = sanitize_consent_yes_ask_no(extremepref, "No")
	unholypref = sanitize_consent_yes_ask_no(unholypref, "No")
	mobsexpref = sanitize_consent_yes_no(mobsexpref)
	hornyantagspref = sanitize_consent_yes_no(hornyantagspref)
	extremeharm = sanitize_consent_yes_no(extremeharm)
	if(extremepref == "No")
		extremeharm = "No"
	lust_tolerance = clamp(lust_tolerance, 25, 200)
	sexual_potency = clamp(sexual_potency, -1, 25)
	if(!islist(favorite_interactions))
		favorite_interactions = list()

/datum/preferences/proc/consent_pref_link(pref_id, label, value)
	return "<b>[label]:</b> <a href='byond://?_src_=prefs;preference=[pref_id]'>[value]</a><br>"

/datum/preferences/proc/consent_toggle_link(pref_id, label, enabled)
	var/state = enabled ? "Enabled" : "Disabled"
	return "<b>[label]:</b> <a href='byond://?_src_=prefs;preference=[pref_id]'>[state]</a><br>"

/datum/preferences/proc/build_consent_preferences_html()
	var/list/dat = list()
	dat += "<table width='100%' style='background-color:#1a1212; padding:8px; border-radius:4px;'>"
	dat += "<tr><td colspan='2'><h3 style='margin:0 0 8px 0;'>Consent Preferences</h3></td></tr>"
	dat += "<tr><td width='50%' valign='top'>"
	dat += consent_pref_link("erp_pref", "ERP", erppref)
	dat += consent_pref_link("noncon_pref", "Non-Con", nonconpref)
	dat += consent_pref_link("vore_pref", "Vore", vorepref)
	dat += consent_pref_link("unholypref", "Unholy", unholypref)
	dat += consent_pref_link("tattoo_pref", "Tattoos", tattoopref)
	dat += "</td><td width='50%' valign='top'>"
	dat += consent_pref_link("extremepref", "Extreme", extremepref)
	if(extremepref != "No")
		dat += consent_pref_link("extremeharm", "Extreme Harm", extremeharm)
	dat += consent_pref_link("mobsex_pref", "Mob Non-Con Sex", mobsexpref)
	dat += consent_pref_link("hornyantags_pref", "Horny Antags", hornyantagspref)
	dat += "</td></tr>"

	dat += "<tr><td colspan='2'><h3 style='margin:12px 0 8px 0;'>Arousal Preferences</h3></td></tr>"
	dat += "<tr><td width='50%' valign='top'>"
	dat += consent_toggle_link("arousable", "Arousal", arousable)
	dat += consent_toggle_link("verb_consent", "ERP Interactions", toggles & VERB_CONSENT)
	dat += consent_toggle_link("ranged_verbs_consent", "Ranged ERP", toggles & RANGED_VERBS_CONSENT)
	dat += consent_toggle_link("lewd_verb_sounds", "ERP Sounds", toggles & LEWD_VERB_SOUNDS)
	dat += "</td><td width='50%' valign='top'>"
	dat += "<b>Lust Tolerance:</b> <a href='byond://?_src_=prefs;preference=lust_tolerance;task=input'>[lust_tolerance]</a> <span style='color:#888;'>(25-200)</span><br>"
	dat += "<b>Sexual Potency:</b> <a href='byond://?_src_=prefs;preference=sexual_potency;task=input'>[sexual_potency]</a> <span style='color:#888;'>(-1 = no limit)</span><br>"
	dat += consent_toggle_link("use_arousal_multiplier", "Arousal Multiplier", use_arousal_multiplier)
	if(use_arousal_multiplier)
		dat += "<b>Multiplier Value:</b> <a href='byond://?_src_=prefs;preference=arousal_multiplier;task=input'>[arousal_multiplier]%</a><br>"
	dat += consent_toggle_link("use_moaning_multiplier", "Moaning Chance", use_moaning_multiplier)
	if(use_moaning_multiplier)
		dat += "<b>Moaning Chance:</b> <a href='byond://?_src_=prefs;preference=moaning_multiplier;task=input'>[moaning_multiplier]%</a><br>"
	dat += "</td></tr>"
	dat += "</table>"
	return dat.Join()

/datum/preferences/proc/notify_noncon_pref_change(mob/user, old_pref, new_pref)
	if(!user?.mind?.current || !isliving(user.mind.current))
		return
	var/mob/living/living_mob = user.mind.current
	message_admins("[user.ckey]/[living_mob.real_name] [ADMIN_FLW(living_mob)][living_mob.stat == DEAD ? " (DEAD)" : ""] changed Non-Con from [old_pref] to [new_pref].")
	log_admin("[user.ckey]/[living_mob.real_name][living_mob.stat == DEAD ? " (DEAD)" : ""] changed Non-Con from [old_pref] to [new_pref].")
	living_mob.balloon_alert_to_viewers("Changed Non-Con from [old_pref] to [new_pref].")

/// Handles one-click consent preference cycling. Returns TRUE if handled.
/datum/preferences/proc/handle_consent_preference_cycle(mob/user, preference)
	if(preference == "erp_pref")
		erppref = cycle_consent_yes_ask_no(erppref)
	else if(preference == "noncon_pref")
		var/old_pref = nonconpref
		nonconpref = cycle_consent_yes_ask_no(nonconpref)
		if(old_pref != nonconpref)
			notify_noncon_pref_change(user, old_pref, nonconpref)
	else if(preference == "vore_pref")
		vorepref = cycle_consent_yes_ask_no(vorepref)
	else if(preference == "unholypref")
		unholypref = cycle_consent_yes_ask_no(unholypref)
	else if(preference == "tattoo_pref")
		tattoopref = cycle_consent_yes_ask_no(tattoopref)
	else if(preference == "extremepref")
		extremepref = cycle_consent_yes_ask_no(extremepref)
		if(extremepref == "No")
			extremeharm = "No"
	else if(preference == "extremeharm")
		extremeharm = cycle_consent_yes_no(extremeharm)
		if(extremepref == "No")
			extremeharm = "No"
	else if(preference == "mobsex_pref")
		mobsexpref = cycle_consent_yes_no(mobsexpref)
	else if(preference == "hornyantags_pref")
		hornyantagspref = cycle_consent_yes_no(hornyantagspref)
	else if(preference == "arousable")
		arousable = !arousable
	else if(preference == "verb_consent")
		toggles ^= VERB_CONSENT
	else if(preference == "ranged_verbs_consent")
		toggles ^= RANGED_VERBS_CONSENT
	else if(preference == "lewd_verb_sounds")
		toggles ^= LEWD_VERB_SOUNDS
	else if(preference == "use_arousal_multiplier")
		use_arousal_multiplier = !use_arousal_multiplier
	else if(preference == "use_moaning_multiplier")
		use_moaning_multiplier = !use_moaning_multiplier
	else
		return FALSE
	sanitize_consent_preferences()
	return TRUE

/// Handles numeric consent preference inputs. Returns TRUE if handled.
/datum/preferences/proc/handle_consent_preference_input(mob/user, preference)
	if(preference == "lust_tolerance")
		var/new_value = input(user, "How long you can stay aroused before climaxing.\n25 = minimum, 200 = maximum.", "Lust Tolerance", lust_tolerance) as num|null
		if(isnull(new_value))
			return TRUE
		lust_tolerance = clamp(round(new_value), 25, 200)
	else if(preference == "sexual_potency")
		var/new_value = input(user, "Orgasms before impotency in one scene.\n-1 disables the limit, maximum is 25.", "Sexual Potency", sexual_potency) as num|null
		if(isnull(new_value))
			return TRUE
		sexual_potency = clamp(round(new_value), -1, 25)
	else if(preference == "arousal_multiplier")
		var/new_value = input(user, "Arousal gain multiplier in percent (1-500).", "Arousal Multiplier", arousal_multiplier) as num|null
		if(isnull(new_value))
			return TRUE
		arousal_multiplier = clamp(round(new_value), 1, 500)
	else if(preference == "moaning_multiplier")
		var/new_value = input(user, "Chance to moan during interactions in percent (0-100).", "Moaning Chance", moaning_multiplier) as num|null
		if(isnull(new_value))
			return TRUE
		moaning_multiplier = clamp(round(new_value), 0, 100)
	else
		return FALSE
	sanitize_consent_preferences()
	return TRUE

/datum/preferences/proc/refresh_consent_preferences_ui(mob/user)
	if(winexists(user, "customization"))
		ShowCustomizers(user)
		return
	update_menu_data(user)
	build_and_show_menu(user)

/datum/preferences/proc/apply_consent_prefs_to(mob/living/carbon/human/character)
	if(QDELETED(character) || !ishuman(character))
		return
	character.dna.features["lust_tolerance"] = lust_tolerance
	character.dna.features["sexual_potency"] = sexual_potency
	character.lust_tolerance = lust_tolerance
	character.sexual_potency = sexual_potency
