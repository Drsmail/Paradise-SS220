/datum/admins
	var/datum/character_portrait_panel/moderation/character_portrait_moderation

USER_VERB(character_portrait_moderation, R_ADMIN, "Character Portrait Moderation", "Review uploaded character portraits.", VERB_CATEGORY_ADMIN)
	if(!client.holder.character_portrait_moderation)
		client.holder.character_portrait_moderation = new /datum/character_portrait_panel/moderation
	client.holder.character_portrait_moderation.ui_interact(client.mob)
