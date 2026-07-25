#define CHARACTER_PORTRAIT_MAX_LIST_RESPONSE_SIZE (1 * 1024 * 1024)
#define CHARACTER_PORTRAIT_MAX_PREVIEW_RESPONSE_SIZE (2 * 1024 * 1024)

#define CHARACTER_PORTRAIT_LIST_IDLE "idle"
#define CHARACTER_PORTRAIT_LIST_LOADING "loading"
#define CHARACTER_PORTRAIT_LIST_LOADED "loaded"
#define CHARACTER_PORTRAIT_LIST_UNAVAILABLE "unavailable"

/**
 * Shared list, preview and TGUI plumbing for portrait panels.
 */
/datum/character_portrait_panel
	var/interface_name
	var/list/images = list()
	var/selected_image_key
	var/selected_image_data
	var/list_state = CHARACTER_PORTRAIT_LIST_IDLE
	var/status_message = ""
	var/status_is_error = FALSE
	var/list_request_in_progress = FALSE
	var/preview_request_in_progress = FALSE

/datum/character_portrait_panel/Destroy()
	images = null
	selected_image_data = null
	return ..()

/datum/character_portrait_panel/ui_state(mob/user)
	return GLOB.always_state

/datum/character_portrait_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, interface_name)
		ui.open()

	if(list_state == CHARACTER_PORTRAIT_LIST_IDLE)
		refresh_images()

/datum/character_portrait_panel/ui_data(mob/user)
	return list(
		"images" = images,
		"selected_image_key" = selected_image_key,
		"selected_image_data" = selected_image_data,
		"list_state" = list_state,
		"status_message" = status_message,
		"status_is_error" = status_is_error,
		"service_configured" = !isnull(get_service_url()),
	)

/datum/character_portrait_panel/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return TRUE

	switch(action)
		if("refresh")
			refresh_images()
			return TRUE
		if("select")
			select_image(params["key"])
			return TRUE

/datum/character_portrait_panel/proc/get_service_url()
	var/service_url = GLOB.configuration.ss220_misc.character_portrait_service_url
	if(!length(service_url))
		return null
	while(copytext_char(service_url, -1) == "/")
		service_url = copytext_char(service_url, 1, -1)
	return service_url

/datum/character_portrait_panel/proc/get_list_url()
	return "[get_service_url()]/internal/v1/images"

/datum/character_portrait_panel/proc/refresh_images()
	if(list_request_in_progress)
		return
	if(!get_service_url())
		list_state = CHARACTER_PORTRAIT_LIST_UNAVAILABLE
		status_message = "Сервис портретов не настроен."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return

	list_request_in_progress = TRUE
	list_state = CHARACTER_PORTRAIT_LIST_LOADING
	SStgui.update_uis(src)

	SShttp.create_async_request(
		RUSTLIBS_HTTP_METHOD_GET,
		get_list_url(),
		proc_callback = CALLBACK(src, PROC_REF(handle_list_response)),
	)

/datum/character_portrait_panel/proc/handle_list_response(datum/http_response/response)
	list_request_in_progress = FALSE
	if(response.errored || response.status_code != 200)
		list_state = CHARACTER_PORTRAIT_LIST_UNAVAILABLE
		status_message = response.errored \
			? "Не удалось подключиться к сервису портретов." \
			: "Не удалось получить список изображений: HTTP [response.status_code]."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return
	if(length(response.body) > CHARACTER_PORTRAIT_MAX_LIST_RESPONSE_SIZE)
		list_state = CHARACTER_PORTRAIT_LIST_UNAVAILABLE
		status_message = "Ответ со списком изображений слишком большой."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return

	var/list/payload
	try
		payload = json_decode(response.body)
	catch(var/exception/error)
		log_debug("Failed to decode character portrait list: [error]")
		list_state = CHARACTER_PORTRAIT_LIST_UNAVAILABLE
		status_message = "Сервис вернул повреждённый список изображений."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return
	if(!islist(payload) || !islist(payload["images"]))
		list_state = CHARACTER_PORTRAIT_LIST_UNAVAILABLE
		status_message = "Сервис вернул список неизвестного формата."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return

	var/list/new_images = list()
	for(var/list/entry as anything in payload["images"])
		var/list/sanitized_entry = sanitize_image_entry(entry)
		if(sanitized_entry)
			new_images += list(sanitized_entry)
	images = new_images
	list_state = CHARACTER_PORTRAIT_LIST_LOADED
	status_message = ""
	status_is_error = FALSE

	if(!image_key_exists(selected_image_key))
		selected_image_key = length(images) ? images[1]["key"] : null
		selected_image_data = null
	if(selected_image_key)
		request_selected_preview()
	SStgui.update_uis(src)

/datum/character_portrait_panel/proc/sanitize_image_entry(list/entry)
	if(!islist(entry))
		return null
	var/filename = "[entry["filename"]]"
	var/uploader_ckey = "[entry["uploader_ckey"]]"
	var/status = "[entry["status"]]"
	var/image_key = "[entry["key"]]"
	var/reviewer_ckey = entry["reviewer_ckey"]
	if(!length(filename) || length_char(filename) > 255)
		return null
	if(!length(uploader_ckey) || length_char(uploader_ckey) > 32)
		return null
	if(image_key != "[uploader_ckey]/[filename]")
		return null
	if(!(status in list("pending", "approved", "rejected", "deleted")))
		return null
	if(!isnull(reviewer_ckey))
		reviewer_ckey = "[reviewer_ckey]"
		if(length_char(reviewer_ckey) > 32)
			return null
	return list(
		"key" = image_key,
		"filename" = filename,
		"uploader_ckey" = uploader_ckey,
		"status" = status,
		"reviewer_ckey" = reviewer_ckey,
	)

/datum/character_portrait_panel/proc/select_image(image_key)
	if(!istext(image_key) || !image_key_exists(image_key))
		return
	if(image_key == selected_image_key)
		return
	selected_image_key = image_key
	selected_image_data = null
	request_selected_preview()
	SStgui.update_uis(src)

/datum/character_portrait_panel/proc/image_key_exists(image_key)
	if(isnull(image_key))
		return FALSE
	for(var/list/image as anything in images)
		if(image["key"] == image_key)
			return TRUE
	return FALSE

/datum/character_portrait_panel/proc/selected_image()
	for(var/list/image as anything in images)
		if(image["key"] == selected_image_key)
			return image
	return null

/datum/character_portrait_panel/proc/request_selected_preview()
	if(preview_request_in_progress)
		return
	var/list/image = selected_image()
	var/service_url = get_service_url()
	if(!image || !service_url || image["status"] in list("rejected", "deleted"))
		return
	preview_request_in_progress = TRUE
	var/request_url = "[service_url]/internal/v1/images/content?uploader_ckey=[url_encode(image["uploader_ckey"])]&filename=[url_encode(image["filename"])]"
	SShttp.create_async_request(
		RUSTLIBS_HTTP_METHOD_GET,
		request_url,
		proc_callback = CALLBACK(src, PROC_REF(handle_preview_response), image["key"]),
	)

/datum/character_portrait_panel/proc/handle_preview_response(image_key, datum/http_response/response)
	preview_request_in_progress = FALSE
	if(image_key == selected_image_key && !response.errored && response.status_code == 200 && length(response.body) <= CHARACTER_PORTRAIT_MAX_PREVIEW_RESPONSE_SIZE)
		selected_image_data = response.body
	else if(image_key != selected_image_key)
		request_selected_preview()
	SStgui.update_uis(src)

#undef CHARACTER_PORTRAIT_MAX_LIST_RESPONSE_SIZE
#undef CHARACTER_PORTRAIT_MAX_PREVIEW_RESPONSE_SIZE

#undef CHARACTER_PORTRAIT_LIST_IDLE
#undef CHARACTER_PORTRAIT_LIST_LOADING
#undef CHARACTER_PORTRAIT_LIST_LOADED
#undef CHARACTER_PORTRAIT_LIST_UNAVAILABLE
