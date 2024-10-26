
/datum/chameleon_system

	// var/mob/???/owner
	var/mob/living/carbon/human/system_owner

	var/datum/action/item_action/chameleon_system/scan_action/scan

	var/datum/action/item_action/chameleon_system/change_one_action/change_one

	var/datum/action/item_action/chameleon_system/change_all_action/change_all

	static/datum/chameleom_memory

// /datum/chameleon_system/initial(Var)
// 	. = ..()



//////////////////////////////
// MARK: scan_action
//////////////////////////////

/datum/action/item_action/chameleon_system/scan
	name = "Copy Outfit"
	var/list/chameleon_blacklist = list() //This is a typecache
	var/list/chameleon_list = list()
	var/chameleon_type = null
	var/chameleon_name = "Item"
	var/ready_to_scan = TRUE

	var/emp_timer
	var/datum/middleClickOverride/callback_invoker/click_override

/datum/action/item_action/chameleon_system/scan/New(Target)
	. = ..()
	click_override = new(CALLBACK(src, PROC_REF(try_to_scan)))

/datum/action/item_action/chameleon_system/scan/Destroy()
	if (ready_to_scan == FALSE) // Check if the user has ended the scan mode before unequipping the glasses."
		end_scan_mode()

	. = ..()

/datum/action/item_action/chameleon_system/scan/Trigger(left_click)
	if (ready_to_scan)
		enter_scan_mode() // Продолжим сделаем красота!
	else
		end_scan_mode()

/datum/action/item_action/chameleon_system/scan/proc/enter_scan_mode()
	var/mob/living/user = owner
	ready_to_scan = FALSE
	to_chat(user, "<span class='warning'>You activate scan module on your glasses, use alt+click or middle mouse button on a target to scan their outfit.</span>")
	user.middleClickOverride = click_override


/datum/action/item_action/chameleon_system/scan/proc/end_scan_mode()
	var/mob/living/user = owner
	ready_to_scan = TRUE
	to_chat(user, "<span class='warning'>You deactivate scan module.</span>")
	user.middleClickOverride = null


/datum/action/item_action/chameleon_system/scan/proc/try_to_scan(mob/user, mob/target)
	user.changeNext_click(5)
	if(ishuman(target)) // can scan only crew // TODO FIX
		start_scan_body(user, target)
		to_chat(user, "<span class='warning'>You have scaned [target.name].</span>")


/datum/action/item_action/chameleon_system/scan/proc/start_scan_body(mob/user, mob/target)
	// TODO ACTIAL CODE
	return TRUE

//////////////////////////////
// MARK: change_one_action
//////////////////////////////

/datum/action/item_action/chameleon_system/change_one
	name = "Change Any Chameleon Part"
	button_overlay_icon_state = "chameleon_outfit"

	var/list/chameleon_blacklist = list() //This is a typecache
	var/list/chameleon_list = list()
	var/chameleon_type = null
	var/chameleon_name = "Item"

	var/emp_timer


/datum/action/item_action/chameleon_system/change_one/New(Target)
	. = ..()

/datum/action/item_action/chameleon_system/change_one/Trigger(left_click)
	var/list/chameleon_items_on_user = get_all_chameleon_items_on_user(owner)
	if (isnull(chameleon_items_on_user)) // Can't be null because we have Action
		return
	var/obj/item/tranform_from = tgui_input_list(owner, "Select what item you wanna change", "Chameleon Change", chameleon_items_on_user) // custom TGUI
	if (isnull(tranform_from))
		return
	var/obj/item/tranform_to = select_appereance(tranform_from) // custom TGUI
	if (isnull(tranform_to))
		return
	change_appereance_to(tranform_from, tranform_to)


/datum/action/item_action/chameleon_system/change_one/proc/get_all_chameleon_items_on_user(mob/user)
	// TODO
	return list()


/datum/action/item_action/chameleon_system/change_one/proc/select_appereance(mob/user)
	var/obj/item/picked_item
	var/picked_name
	picked_name = tgui_input_list(user, "Select [chameleon_name] to change into", "Chameleon [chameleon_name]", chameleon_list)
	if(!picked_name)
		return
	picked_item = chameleon_list[picked_name]
	if(!picked_item)
		return
	return picked_item

/datum/action/item_action/chameleon_system/change_one/proc/change_appereance_to(/obj/item/picked_item)
	if(isliving(owner))
		var/mob/living/C = owner
		if(C.stat != CONSCIOUS)
			return

		update_item(picked_item)
		var/obj/item/thing = target
		thing.update_slot_icon()

	// UpdateButtons()

/datum/action/item_action/chameleon_system/change_one/proc/update_item(obj/item/picked_item)
	target.name = initial(picked_item.name)
	target.desc = initial(picked_item.desc)
	target.icon_state = initial(picked_item.icon_state)

	if(isitem(target))
		var/obj/item/I = target

		I.item_state = initial(picked_item.item_state)
		I.item_color = initial(picked_item.item_color)
		I.color = initial(picked_item.color)

		I.icon_override = initial(picked_item.icon_override)
		if(initial(picked_item.sprite_sheets))
			// Species-related variables are lists, which can not be retrieved using initial(). As such, we need to instantiate the picked item.
			var/obj/item/P = new picked_item(null)
			I.sprite_sheets = P.sprite_sheets
			qdel(P)

		if(isclothing(I) && isclothing(picked_item))
			var/obj/item/clothing/CL = I
			var/obj/item/clothing/PCL = picked_item
			CL.flags_cover = initial(PCL.flags_cover)
		I.update_appearance()

	target.icon = initial(picked_item.icon)



//////////////////////////////
// MARK: change_all_action
//////////////////////////////

/datum/action/chameleon_system/change_all_action/
	name = "Select Chameleon Outfit"
	button_overlay_icon_state = "chameleon_outfit"
	//By default, this list is shared between all instances.
	//It is not static because if it were, subtypes would not be able to have their own. If you ever want to edit it, copy it first.
	var/list/outfit_options

/datum/action/chameleon_system/change_all_action/New()
	..()

/datum/action/chameleon_system/change_all_action/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/datum/action/chameleon_system/change_all_action/proc/initialize_outfits()
	var/static/list/standard_outfit_options
	if(!standard_outfit_options)
		standard_outfit_options = list()
		for(var/path in subtypesof(/datum/outfit/job))
			var/datum/outfit/O = path
			if(initial(O.can_be_admin_equipped))
				standard_outfit_options[initial(O.name)] = path
		sortTim(standard_outfit_options, GLOBAL_PROC_REF(cmp_text_asc))

	// TODO ADD 3 CUSTOM SLOTS HERE
	outfit_options = standard_outfit_options

/datum/action/chameleon_system/change_all_action/Trigger(left_click)
	return select_outfit(owner)

/datum/action/chameleon_system/change_all_action/proc/select_outfit(mob/user)
	// TODO Actial code
	return TRUE


//////////////////////////////
// MARK: Item Test
//////////////////////////////

/obj/item/clothing/glasses/test_chameleon
	name = "optical meson scanner"
	desc = "Used by engineering and mining staff to see basic structural and terrain layouts through walls, regardless of lighting condition."
	icon_state = "meson"
	item_state = "meson"
	resistance_flags = NONE
	prescription_upgradable = TRUE
	armor = list(MELEE = 5, BULLET = 5, LASER = 5, ENERGY = 0, BOMB = 0, RAD = 0, FIRE = 50, ACID = 50)

	sprite_sheets = list(
		"Vox" = 'icons/mob/clothing/species/vox/eyes.dmi',
		"Drask" = 'icons/mob/clothing/species/drask/eyes.dmi',
		"Grey" = 'icons/mob/clothing/species/grey/eyes.dmi'
	)

	// var/datum/action/item_action/chameleon/change/chameleon_action
	var/datum/action/item_action/chameleon_system/scan/scan_action
	var/datum/action/item_action/chameleon_system/change_one/change_one_action

/obj/item/clothing/glasses/test_chameleon/item_action_slot_check(slot, mob/user)
	if (slot == SLOT_HUD_GLASSES)
		return TRUE
	return FALSE

/obj/item/clothing/glasses/test_chameleon/Initialize(mapload)
	. = ..()
	scan_action = new(src)
	change_one_action = new(src)

/obj/item/clothing/glasses/test_chameleon/Destroy()
	// QDEL_NULL(chameleon_action)
	return ..()
