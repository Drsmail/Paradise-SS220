/**
 * Player panel for uploading and viewing the current ckey's portraits.
 */
/datum/character_portrait_panel/player
	interface_name = "CharacterPortraits"
	var/mob/owner
	var/owner_ckey
	var/upload_in_progress = FALSE

/datum/character_portrait_panel/player/New(mob/user)
	. = ..()
	owner = user
	owner_ckey = user?.ckey

/datum/character_portrait_panel/player/Destroy()
	owner = null
	return ..()

/datum/character_portrait_panel/player/ui_data(mob/user)
	. = ..()
	.["upload_in_progress"] = upload_in_progress

/datum/character_portrait_panel/player/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return TRUE
	if(action == "upload")
		begin_upload(ui.user)
		return TRUE

/datum/character_portrait_panel/player/get_list_url()
	return "[get_service_url()]/internal/v1/images?uploader_ckey=[url_encode(owner_ckey)]"

/datum/character_portrait_panel/player/proc/begin_upload(mob/user)
	if(upload_in_progress)
		return
	if(!get_service_url())
		set_upload_error("Сервис портретов не настроен.")
		return

	upload_in_progress = TRUE
	status_message = ""
	status_is_error = FALSE
	SStgui.update_uis(src)

	var/uploaded_file = input(user, "Выберите изображение", "Портрет") as null|file
	if(QDELETED(src) || !owner?.client)
		return
	if(!uploaded_file)
		upload_in_progress = FALSE
		SStgui.update_uis(src)
		return

	var/filename = extract_filename("[uploaded_file]")
	if(!filename || length_char(filename) > 255)
		set_upload_error("Некорректное имя файла.")
		return

	var/static/regex/png_extension = regex(@{"\.png$"}, "i")
	if(!png_extension.Find(filename))
		set_upload_error("Для прототипа разрешены только PNG-файлы.")
		return

	var/file_size = length(uploaded_file)
	if(file_size <= 0)
		set_upload_error("Выбранный файл пуст.")
		return
	if(file_size > (10 * 1024 * 1024))
		set_upload_error("Размер PNG не должен превышать 10 MiB.")
		return

	status_message = "Подготовка изображения..."
	SStgui.update_uis(src)

	var/icon/uploaded_icon
	try
		uploaded_icon = icon(uploaded_file)
	catch(var/exception/error)
		log_debug("Failed to decode character portrait uploaded by [owner_ckey]: [error]")
		set_upload_error("Файл не удалось прочитать как изображение.")
		return
	if(!isicon(uploaded_icon))
		set_upload_error("Файл не удалось прочитать как изображение.")
		return

	var/base64_body = icon2base64(uploaded_icon)
	uploaded_icon = null
	uploaded_file = null
	if(!istext(base64_body) || !length(base64_body))
		set_upload_error("Не удалось подготовить изображение к отправке.")
		return

	status_message = "Отправка изображения..."
	SStgui.update_uis(src)

	var/request_url = "[get_service_url()]/internal/v1/images?uploader_ckey=[url_encode(owner_ckey)]&filename=[url_encode(filename)]"
	SShttp.create_async_request(
		RUSTLIBS_HTTP_METHOD_POST,
		request_url,
		base64_body,
		list("Content-Type" = "text/plain; charset=us-ascii"),
		CALLBACK(src, PROC_REF(handle_upload_response)),
	)

/datum/character_portrait_panel/player/proc/set_upload_error(message)
	upload_in_progress = FALSE
	status_message = message
	status_is_error = TRUE
	SStgui.update_uis(src)

/datum/character_portrait_panel/player/proc/handle_upload_response(datum/http_response/response)
	upload_in_progress = FALSE
	if(response.errored)
		status_message = "Сервис портретов недоступен."
		status_is_error = TRUE
	else if(response.status_code == 201)
		status_message = "Изображение принято и ожидает модерации."
		status_is_error = FALSE
	else
		var/service_detail = upload_error_detail(response.body)
		status_message = service_detail ? service_detail : "Сервис вернул ошибку HTTP [response.status_code]."
		status_is_error = TRUE

	SStgui.update_uis(src)
	if(response.status_code == 201 && !response.errored)
		refresh_images()

/datum/character_portrait_panel/player/proc/upload_error_detail(response_body)
	if(!istext(response_body) || !length(response_body) || length(response_body) > 8192)
		return null

	var/list/payload
	try
		payload = json_decode(response_body)
	catch(var/exception/error)
		return null
	if(!islist(payload) || !istext(payload["detail"]))
		return null

	return copytext_char(payload["detail"], 1, 501)

/datum/character_portrait_panel/player/proc/extract_filename(filename)
	var/static/regex/path_prefix = regex(@{"^.*[\\/]"})
	filename = path_prefix.Replace(filename, "")
	filename = trim(filename)
	if(!length(filename) || filename == "." || filename == "..")
		return null
	return filename
