/mob/new_player
	/// Lobby-only character portrait upload and browser interface.
	var/datum/character_portrait_panel/player/character_portraits

/mob/new_player/Destroy()
	QDEL_NULL(character_portraits)
	return ..()

/mob/new_player/Topic(href, href_list)
	. = ..()
	if(!href_list["character_portraits"])
		return

	if(!character_portraits)
		character_portraits = new(src)
	character_portraits.ui_interact(src)
	return TRUE
