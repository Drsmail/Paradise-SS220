/datum/configuration_section/ss220_misc_configuration
	/// Loopback HTTP service used to store and moderate character portraits.
	var/character_portrait_service_url

/datum/configuration_section/ss220_misc_configuration/load_data(list/data)
	. = ..()
	CONFIG_LOAD_STR(character_portrait_service_url, data["character_portrait_service_url"])

