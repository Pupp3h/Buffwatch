std = "lua51"
max_line_length = false
exclude_files = {
	".luacheckrc"
}
ignore = {
	"11./SLASH_.*", -- Setting an undefined (Slash handler) global variable
	"11./BuffwatchFrame.*",
	"11./Buffwatch_Options_.*",
	"11./Buffwatch_HelpFrameText",
}

globals = {
	-- Buffwatch
	"BUFFWATCHADDON_G",
	"BuffwatchConfig",
	"BuffwatchPlayerConfig",
	"BuffwatchSaveBuffs",
	"BuffwatchSaveTempEnch",

	-- 3rd Party
	"LibStub",

	-- FrameXML
	"DEFAULT_CHAT_FRAME",
	"GameTooltip",
	"InterfaceOptions_AddCategory",
	"InterfaceOptionsFrame_OpenToCategory",
	"SlashCmdList",
	"UIDropDownMenu_AddButton",
	"UIDropDownMenu_Initialize",
	"UIDropDownMenu_SetAnchor",
	"UIDropDownMenu_SetSelectedID",
	"UIDropDownMenu_SetSelectedValue",
	"UIDropDownMenu_SetText",
	"UIDropDownMenu_SetWidth",
	"UIParent",

	-- Constants
	"GRAY_FONT_COLOR",
	"NORMAL_FONT_COLOR",
	"RAID_CLASS_COLORS",

	-- API
	"CopyTable",
	"CreateFrame",
	"GetChatWindowInfo",
	"GetInventoryItemTexture",
	"GetLocale",
	"GetNumGroupMembers",
	"GetRaidRosterInfo",
	"GetSpellSubtext",
	"GetWeaponEnchantInfo",
	"InCombatLockdown",
	"IsAltKeyDown",
	"table.wipe",
	"tinsert",
	"tremove",
	"ToggleDropDownMenu",
	"UnitAura",
	"UnitBuff",
	"UnitClass",
	"UnitIsConnected",
	"UnitIsDeadOrGhost",
	"UnitIsUnit",
	"UnitName",
}