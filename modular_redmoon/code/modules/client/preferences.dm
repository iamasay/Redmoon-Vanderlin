/datum/preferences
	/// My favorites! they show up in their own tab inside the ui.
	var/list/favorite_interactions

	/// Enable the 'arousal_multiplier' to be applied to lust amount
	var/use_arousal_multiplier = FALSE
	/// A separate arousal multiplier that the user has control of (although we could just tap into lust or replace it.)
	var/arousal_multiplier = 100
	/// Enable the 'moaning_multiplier' to be used as a % chance of moaning instead of default calculation.
	var/use_moaning_multiplier = FALSE
	/// Chance of moaning during an interaction
	var/moaning_multiplier = 65

	var/datum/character_offer_instance/offer
	var/vore_flags = 0
	var/list/belly_prefs = list()
	var/vore_taste = "nothing in particular"
	var/vore_smell = null
	var/toggleeatingnoise = TRUE
	var/toggledigestionnoise = TRUE
	var/hound_sleeper = TRUE
	var/cit_toggles = TOGGLES_CITADEL
	var/erppref = "Ask"
	var/nonconpref = "Ask"
	var/vorepref = "Ask"
	var/mobsexpref = "No" 					//Added by Gardelin0 - Sex(mostly non-con) with hostile mobs(tentacles)
	var/hornyantagspref = "No" 				//Added by Gardelin0 - Interactions(mostly non-con) with horny antags(Qareen)
	var/tattoopref = "Ask"					//BLUEMOON ADD - Tattoo consent preference
	var/extremepref = "No" 					//This is for extreme shit, maybe even literal shit, better to keep it on no by default
	var/extremeharm = "No"
	var/unholypref = "No"
	var/list/gfluid_blacklist = list()

	/// How long the character can stay aroused before climax (25–200). Applied to DNA on spawn.
	var/lust_tolerance = 100
	/// Orgasm limit per encounter; -1 disables impotency. Applied to DNA on spawn.
	var/sexual_potency = 15
