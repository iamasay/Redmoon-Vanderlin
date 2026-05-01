/datum/interaction/lewd/slap
	description = "Попа. Шлёпнуть по заднице."
	simple_message = "USER с силой шлёпает задницу TARGET с громким звуком!"
	simple_style = "danger"
	interaction_sound = 'modular_redmoon/sound/interactions/slap.ogg'
	required_from_user = INTERACTION_REQUIRE_HANDS
	body_parts = list(BODY_PART_GROIN)

	write_log_user = "ass-slapped"
	write_log_target = "was ass-slapped by"

/datum/interaction/lewd/grope_ass
	description = "Попа. Полапать задницу."
	simple_message = "USER сжимает задницу TARGET!"
	simple_style = "danger"
	required_from_user = INTERACTION_REQUIRE_HANDS
	interaction_sound = 'modular_redmoon/sound/interactions/thudswoosh.ogg'
	write_log_user = "ass-gropped"
	write_log_target = "was ass-gropped by"
	body_parts = list(BODY_PART_GROIN)


/datum/interaction/lewd/slap_breasts
	description = "Грудь. Шлёпнуть по груди."
	simple_message = "USER с силой шлёпает груди TARGET с громким звуком!"
	simple_style = "danger"
	interaction_sound = 'modular_redmoon/sound/interactions/slap.ogg'
	required_from_user = INTERACTION_REQUIRE_HANDS
	required_from_target = INTERACTION_REQUIRE_BREASTS
