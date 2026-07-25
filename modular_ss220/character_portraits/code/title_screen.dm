/datum/title_screen/get_additional_menu_buttons(client/viewer, mob/new_player/player)
	. = ..()
	. += "<a class='menu_button' href='byond://?src=[player.UID()];character_portraits=1'>Портреты персонажей</a>"

