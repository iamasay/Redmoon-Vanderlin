/datum/customizer/organ/genital
	abstract_type = /datum/customizer/organ/genital
	name = "Genital"

/datum/customizer_entry/organ/genital
	var/genital_size
	var/show_size_dropdown = FALSE

/datum/customizer_choice/organ/genital
	abstract_type = /datum/customizer_choice/organ/genital
	customizer_entry_type = /datum/customizer_entry/organ/genital
	/// Display name -> value applied to the organ when this size is chosen.
	var/list/size_options_list
	var/default_genital_size
	/// Key for get_genital_size_options(); shape pickers use sprite_accessories / *_shapes_list.
	var/size_options_category

/datum/customizer_choice/organ/genital/New()
	. = ..()
	ensure_size_options_list()

/datum/customizer_choice/organ/genital/proc/ensure_size_options_list()
	if(length(size_options_list))
		return
	if(size_options_category)
		size_options_list = get_genital_size_options(size_options_category)

/datum/customizer_choice/organ/genital/make_default_customizer_entry(datum/preferences/prefs, customizer_type, changed_entry = TRUE)
	. = ..()
	var/datum/customizer_entry/organ/genital/genital_entry = .
	if(length(size_options_list) && !genital_entry.genital_size)
		genital_entry.genital_size = default_genital_size

/datum/customizer_choice/organ/genital/validate_entry(datum/preferences/prefs, datum/customizer_entry/entry)
	ensure_size_options_list()
	..()
	if(!length(size_options_list))
		return
	var/datum/customizer_entry/organ/genital/genital_entry = entry
	if(!(genital_entry.genital_size in size_options_list))
		genital_entry.genital_size = default_genital_size

/datum/customizer_choice/organ/genital/on_randomize_entry(datum/customizer_entry/entry, datum/preferences/prefs)
	if(length(size_options_list))
		var/datum/customizer_entry/organ/genital/genital_entry = entry
		var/list/size_names = list()
		for(var/size_name in size_options_list)
			size_names += size_name
		genital_entry.genital_size = pick(size_names)

/datum/customizer_choice/organ/genital/proc/apply_genital_colors_to_dna(mob/living/carbon/human/human, datum/customizer_entry/entry)
	if(!human?.dna || !entry?.accessory_type)
		return
	var/datum/sprite_accessory/bm/accessory = SPRITE_ACCESSORY(entry.accessory_type)
	if(!accessory?.color_src || !entry.accessory_colors)
		return
	var/list/color_list = color_string_to_list(entry.accessory_colors)
	if(!length(color_list))
		return
	human.dna.features[accessory.color_src] = copytext(color_list[1], 2)

/datum/customizer_choice/organ/genital/proc/apply_genital_colors_to_organ(obj/item/organ/genital/G, datum/customizer_entry/entry)
	if(!entry?.accessory_type || !entry.accessory_colors)
		return
	if(G.owner?.dna?.species?.use_skintones && G.owner.dna.features["genitals_use_skintone"])
		return
	var/list/color_list = color_string_to_list(entry.accessory_colors)
	if(!length(color_list))
		return
	G.color = color_list[1]

/datum/customizer_choice/organ/genital/customize_organ(obj/item/organ/organ, datum/customizer_entry/entry)
	if(entry?.accessory_type)
		organ.set_accessory_type(entry.accessory_type, entry.accessory_colors)
	if(!istype(organ, /obj/item/organ/genital))
		return
	var/obj/item/organ/genital/G = organ
	apply_genital_colors_to_organ(G, entry)
	apply_genital_size(G, entry)
	G.update()

/datum/customizer_choice/organ/genital/apply_customizer_to_character(mob/living/carbon/human/human, datum/preferences/prefs, datum/customizer_entry/entry)
	if(entry.disabled)
		var/obj/item/organ/genital/G = human.getorganslot(organ_slot)
		if(G)
			G.Remove(human, TRUE)
			qdel(G)
			human.update_genitals()
		return
	apply_genital_colors_to_dna(human, entry)
	var/obj/item/organ/genital/G = human.getorganslot(organ_slot)
	if(!G)
		G = new organ_type()
		customize_organ(G, entry)
		G.Insert(human, TRUE, FALSE)
		return
	customize_organ(G, entry)

/datum/customizer_choice/organ/genital/proc/apply_genital_size(obj/item/organ/genital/G, datum/customizer_entry/entry)
	var/datum/customizer_entry/organ/genital/genital_entry = entry
	if(!length(size_options_list) || !genital_entry?.genital_size)
		return
	if(!(genital_entry.genital_size in size_options_list))
		return
	apply_genital_size_value(G, size_options_list[genital_entry.genital_size])

/datum/customizer_choice/organ/genital/proc/apply_genital_size_value(obj/item/organ/genital/G, value)
	G.size = value
	G.update()

/datum/customizer_choice/organ/genital/generate_pref_choices(list/dat, datum/preferences/prefs, datum/customizer_entry/entry, customizer_type)
	ensure_size_options_list()
	if(length(sprite_accessories) > 1)
		dat += "<div style='text-align:center; margin:5px 0;'><b>Shape:</b></div>"
	..()
	if(!length(size_options_list))
		return
	generate_genital_size_pref_choices(dat, entry, customizer_type)

/datum/customizer_choice/organ/genital/proc/generate_genital_size_pref_choices(list/dat, datum/customizer_entry/entry, customizer_type)
	var/datum/customizer_entry/organ/genital/genital_entry = entry
	var/current_size = genital_entry.genital_size || default_genital_size
	var/size_link
	var/arrows_string
	var/dropdown_button

	if(length(size_options_list) > 1)
		size_link = "href='?_src_=prefs;task=change_customizer;customizer=[customizer_type];customizer_task=choose_size'"
		arrows_string = "<a href='?_src_=prefs;task=change_customizer;customizer=[customizer_type];customizer_task=rotate_size;rotate=prev' style='font-size:16px; padding:0 5px;'><</a><a href='?_src_=prefs;task=change_customizer;customizer=[customizer_type];customizer_task=rotate_size;rotate=next' style='font-size:16px; padding:0 5px;'>></a>"
		dropdown_button = "<a href='?_src_=prefs;task=change_customizer;customizer=[customizer_type];customizer_task=toggle_size_dropdown' style='font-size:12px; padding:0 5px;'>View All</a>"
	else
		size_link = "class='linkOff'"
		arrows_string = "<a class='linkOff' style='font-size:16px; padding:0 5px;'><</a><a class='linkOff' style='font-size:16px; padding:0 5px;'>></a>"
		dropdown_button = ""

	dat += "<div style='text-align:center; margin:10px 0;'>"
	dat += "<div style='background-color:#0a0a0a; padding:10px; border-radius:5px; display:inline-block;'>"
	dat += "<div style='margin:5px 0;'>"
	dat += "<b>Size:</b> [arrows_string] <a [size_link]>[current_size]</a> [dropdown_button]"
	dat += "</div>"
	dat += "</div>"
	dat += "</div>"

	if(genital_entry.show_size_dropdown && length(size_options_list) > 1)
		dat += "<div style='background-color:#1a1a1a; padding:10px; border-radius:5px; margin:10px 0;'>"
		dat += "<div style='display:grid; grid-template-columns:repeat(auto-fill, minmax(80px, 1fr)); gap:8px; max-height:300px; overflow-y:auto;'>"
		for(var/size_name in size_options_list)
			var/is_selected = (size_name == current_size)
			var/border_style = is_selected ? "border:2px solid #4a9eff;" : "border:1px solid #333;"
			dat += "<a href='?_src_=prefs;task=change_customizer;customizer=[customizer_type];customizer_task=select_size;size_name=[size_name]' style='text-decoration:none;'>"
			dat += "<div style='background-color:#0a0a0a; padding:8px; border-radius:3px; [border_style] text-align:center; cursor:pointer;'>"
			dat += "<div style='font-size:11px; color:[is_selected ? "#4a9eff" : "#ffffff"];'>[size_name]</div>"
			dat += "</div>"
			dat += "</a>"
		dat += "</div>"
		dat += "</div>"

/datum/customizer_choice/organ/genital/handle_topic(mob/user, list/href_list, datum/preferences/prefs, datum/customizer_entry/entry, customizer_type)
	ensure_size_options_list()
	..()
	if(!length(size_options_list))
		return
	var/datum/customizer_entry/organ/genital/genital_entry = entry
	switch(href_list["customizer_task"])
		if("toggle_size_dropdown")
			genital_entry.show_size_dropdown = !genital_entry.show_size_dropdown
		if("select_size")
			var/size_name = href_list["size_name"]
			if(!(size_name in size_options_list))
				return
			genital_entry.genital_size = size_name
			genital_entry.show_size_dropdown = FALSE
		if("choose_size")
			var/list/choice_list = list()
			for(var/size_name in size_options_list)
				choice_list[size_name] = size_name
			var/chosen_input = browser_input_list(user, "Choose your [lowertext(name)] size:", "Character Preference", choice_list)
			if(!chosen_input)
				return
			genital_entry.genital_size = chosen_input
		if("rotate_size")
			var/list/size_names = list()
			for(var/size_name in size_options_list)
				size_names += size_name
			var/current_index = size_names.Find(genital_entry.genital_size)
			if(!current_index)
				current_index = size_names.Find(default_genital_size)
			var/target_index = current_index
			switch(href_list["rotate"])
				if("next")
					target_index++
				if("prev")
					target_index--
			if(target_index > length(size_names))
				target_index = 1
			else if(target_index <= 0)
				target_index = length(size_names)
			genital_entry.genital_size = size_names[target_index]

/datum/customizer/organ/genital/penis
	name = "Penis"
	customizer_choices = list(/datum/customizer_choice/organ/genital/penis)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/penis
	name = "Penis"
	organ_type = /obj/item/organ/genital/penis
	organ_slot = ORGAN_SLOT_PENIS
	default_genital_size = "Medium"
	size_options_category = "penis"
	sprite_accessories = list(
		/datum/sprite_accessory/bm/penis/human,
		/datum/sprite_accessory/bm/penis/knotted,
		/datum/sprite_accessory/bm/penis/flared,
		/datum/sprite_accessory/bm/penis/tapered,
		/datum/sprite_accessory/bm/penis/tentacle,
		/datum/sprite_accessory/bm/penis/hemi,
		/datum/sprite_accessory/bm/penis/hemiknot,
		/datum/sprite_accessory/bm/penis/barbknot,
		/datum/sprite_accessory/bm/penis/thick,
	)

/datum/customizer_choice/organ/genital/penis/apply_genital_size_value(obj/item/organ/genital/G, value)
	var/obj/item/organ/genital/penis/P = G
	// value is the onmob sprite stage (1-5); length drives descriptions and update_size()
	switch(value)
		if(1)
			P.length = 6
		if(2)
			P.length = 18
		if(3)
			P.length = 30
		if(4)
			P.length = 60
		if(5)
			P.length = 100
	P.prev_length = P.length
	P.update()

/datum/customizer/organ/genital/testicles
	name = "Testicles"
	customizer_choices = list(/datum/customizer_choice/organ/genital/testicles)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/testicles
	name = "Balls"
	organ_type = /obj/item/organ/genital/testicles
	organ_slot = ORGAN_SLOT_TESTICLES
	default_genital_size = "Average"
	size_options_category = "testicles"
	sprite_accessories = list(
		/datum/sprite_accessory/bm/testicles/single,
		/datum/sprite_accessory/bm/testicles/hidden,
		/datum/sprite_accessory/bm/testicles/sheath,
	)

/datum/customizer/organ/genital/vagina
	name = "Vagina"
	customizer_choices = list(/datum/customizer_choice/organ/genital/vagina)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/vagina
	name = "Vagina"
	organ_type = /obj/item/organ/genital/vagina
	organ_slot = ORGAN_SLOT_VAGINA
	sprite_accessories = list(
		/datum/sprite_accessory/bm/vagina/human,
	)

/datum/customizer/organ/genital/breasts
	name = "Breasts"
	customizer_choices = list(/datum/customizer_choice/organ/genital/breasts)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/breasts
	name = "Breasts"
	organ_type = /obj/item/organ/genital/breasts
	organ_slot = ORGAN_SLOT_BREASTS
	default_genital_size = "C"
	size_options_category = "breasts"
	sprite_accessories = list(
		/datum/sprite_accessory/bm/breasts/pair,
		/datum/sprite_accessory/bm/breasts/quad,
		/datum/sprite_accessory/bm/breasts/sextuple,
	)

/datum/customizer_choice/organ/genital/breasts/apply_genital_size_value(obj/item/organ/genital/G, value)
	var/obj/item/organ/genital/breasts/B = G
	B.prev_size = B.size
	B.size = value
	B.update()

/datum/customizer/organ/genital/butt
	name = "Butt"
	customizer_choices = list(/datum/customizer_choice/organ/genital/butt)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/butt
	name = "Butt"
	organ_type = /obj/item/organ/genital/butt
	organ_slot = ORGAN_SLOT_BUTT
	default_genital_size = "Medium"
	size_options_category = "butt"
	sprite_accessories = list(
		/datum/sprite_accessory/bm/butt/pair,
	)

/datum/customizer_choice/organ/genital/butt/apply_genital_size_value(obj/item/organ/genital/G, value)
	var/obj/item/organ/genital/butt/B = G
	B.prev_size = B.size_cached
	B.size_cached = value
	B.size = round(B.size_cached)
	B.update()

/datum/customizer/organ/genital/belly
	name = "Belly"
	customizer_choices = list(/datum/customizer_choice/organ/genital/belly)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/belly
	name = "Belly"
	organ_type = /obj/item/organ/genital/belly
	organ_slot = ORGAN_SLOT_BELLY
	default_genital_size = "Medium"
	size_options_category = "belly"
	sprite_accessories = list(
		/datum/sprite_accessory/bm/belly/pair,
	)

/datum/customizer_choice/organ/genital/belly/apply_genital_size_value(obj/item/organ/genital/G, value)
	var/obj/item/organ/genital/belly/B = G
	B.prev_size = B.size_cached
	B.size_cached = value
	B.size = round(B.size_cached)
	B.update()

/datum/customizer/organ/genital/anus
	name = "Anus"
	customizer_choices = list(/datum/customizer_choice/organ/genital/anus)
	allows_disabling = TRUE
	default_disabled = TRUE

/datum/customizer_choice/organ/genital/anus
	name = "Anus"
	organ_type = /obj/item/organ/genital/anus
	organ_slot = ORGAN_SLOT_ANUS
	sprite_accessories = list(
		/datum/sprite_accessory/bm/anus/donut,
		/datum/sprite_accessory/bm/anus/squished,
	)
