function BW_Options_OnLoad()
    
    -- Add BW_Options to the UIPanelWindows list
    UIPanelWindows["BW_Options"] = {area = "center", pushable = 0}

end

function BW_Options_Init()
    BW_Options_ShowOnStartup:SetChecked(BuffWatchConfig.show_on_startup)
    BW_Options_ShowPets:SetChecked(BuffWatchConfig.ShowPets)
    BW_Options_ShowDebuffs:SetChecked(BuffWatchConfig.ShowDebuffs)
    BW_Options_Alpha:SetValue(BuffWatchConfig.alpha)
    BW_Options_AlignBuffs:SetChecked(BuffWatchConfig.AlignBuffs)
    BW_Options_ShowExpiredWarning:SetChecked(BuffWatchConfig.ExpiredWarning)
end

function BW_Options_SortOrder_OnClick()
    i = this:GetID()
    UIDropDownMenu_SetSelectedID(BW_Options_SortOrder, i)
    BuffWatchConfig.SortOrder = BW_SORTORDER_DROPDOWN_LIST[i]
    BW_GetAllBuffs()
    BW_UpdateBuffStatus()
    BW_ResizeWindow()   
end

function BW_Options_SortOrder_Initialize()
    local info
    for i = 1, getn(BW_SORTORDER_DROPDOWN_LIST) do
        info = {
            text = BW_SORTORDER_DROPDOWN_LIST[i],
            func = BW_Options_SortOrder_OnClick
        }
        UIDropDownMenu_AddButton(info)
    end
end

function BW_Options_SortOrder_OnLoad()
   UIDropDownMenu_Initialize(this, BW_Options_SortOrder_Initialize)
   UIDropDownMenu_SetText(BuffWatchConfig.SortOrder, this)
   UIDropDownMenu_SetWidth(90, BW_Options_SortOrder)
end