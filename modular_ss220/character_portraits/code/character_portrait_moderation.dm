/**
 * Admin panel for reviewing every player's pending portraits.
 */
/datum/character_portrait_panel/moderation
	interface_name = "CharacterPortraitModeration"

/datum/character_portrait_panel/moderation/ui_state(mob/user)
	return GLOB.admin_state

/datum/character_portrait_panel/moderation/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return TRUE

	switch(action)
		if("approve")
			moderate_selected("approved", ui.user.ckey)
			return TRUE
		if("reject")
			moderate_selected("rejected", ui.user.ckey)
			return TRUE

/datum/character_portrait_panel/moderation/proc/moderate_selected(decision, reviewer_ckey)
	var/list/image = selected_image()
	var/service_url = get_service_url()
	if(!image || !service_url)
		return

	status_message = decision == "approved" ? "Одобрение изображения..." : "Отклонение изображения..."
	status_is_error = FALSE
	SStgui.update_uis(src)
	var/request_url = "[service_url]/internal/v1/images/moderate?uploader_ckey=[url_encode(image["uploader_ckey"])]&filename=[url_encode(image["filename"])]&decision=[decision]&reviewer_ckey=[url_encode(reviewer_ckey)]"
	SShttp.create_async_request(
		RUSTLIBS_HTTP_METHOD_POST,
		request_url,
		"",
		list("Content-Type" = "text/plain"),
		CALLBACK(src, PROC_REF(handle_moderation_response)),
	)

/datum/character_portrait_panel/moderation/proc/handle_moderation_response(datum/http_response/response)
	if(response.errored || response.status_code != 200)
		status_message = response.errored ? "Сервис портретов недоступен." : "Модерация не выполнена: HTTP [response.status_code]."
		status_is_error = TRUE
		SStgui.update_uis(src)
		return
	refresh_images()
