local addonName, addon = ...
local FarmingBar = LibStub("AceAddon-3.0"):NewAddon("FarmingBar", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("FarmingBar", true)
local LSM = LibStub("LibSharedMedia-3.0")
LibStub("LibAddonUtils-1.0"):Embed(addon)

local pairs, wipe = pairs, table.wipe
local strupper = string.upper

--*------------------------------------------------------------------------

function FarmingBar:OnInitialize()
    addon.bars = {}

    addon.maxButtons = 108
    addon.maxButtonPadding = 20
    addon.maxButtonSize = 60
    addon.maxFontSize = 32
    addon.maxScale = 5
    addon.minButtonPadding = -3
    addon.minButtonSize = 15
    addon.minFontSize = 4
    addon.minScale = .25
    addon.moveDelay = .4
    addon.OffsetX = 10
    addon.OffsetY = 10

    addon.tooltip_description = {1, 1, 1, 1, 1, 1, 1}
    addon.tooltip_keyvalue = {1, .82, 0, 1, 1, 1, 1}

    addon.barProgress = "%B progress: %progressColor%%c/%t%color%%if(%p>0, (%p%%),)if%"
    addon.withObjective = "%if(%p>=100 and %C<%o,Objective complete!,Farming update:)if% %t %progressColor%%c/%o%color% (%if(%O>1,x%O ,)if%%diffColor%%d%color%)"
    addon.withoutObjective = "Farming update: %t x%c (%diffColor%%d%color%)"

    ------------------------------------------------------------

    --@retail@
    LSM:Register("sound", L["Auction Open"], 567482) -- id:5274
    LSM:Register("sound", L["Auction Close"], 567499) -- id:5275
    LSM:Register("sound", L["Loot Coin"], 567428) -- id:120
    LSM:Register("sound", L["Quest Activate"], 567400) -- id:618
    LSM:Register("sound", L["Quest Complete"], 567439) -- id:878
    LSM:Register("sound", L["Quest Failed"], 567459) -- id:846
    --@end-retail@

    --[===[@non-retail@
    LSM:Register("sound", L["Auction Open"], "sound/interface/auctionwindowopen.ogg") -- id:5274
    LSM:Register("sound", L["Auction Close"], "sound/interface/auctionwindowclose.ogg") -- id:5275
    LSM:Register("sound", L["Loot Coin"], "sound/interface/lootcoinsmall.ogg") -- id:120
    LSM:Register("sound", L["Quest Activate"], "sound/interface/iquestactivate.ogg") -- id:618
    LSM:Register("sound", L["Quest Complete"], "sound/interface/iquestcomplete.ogg") -- id:878
    LSM:Register("sound", L["Quest Failed"], "sound/interface/igquestfailed.ogg") -- id:846
    --@end-non-retail@]===]

    ------------------------------------------------------------

    addon:Initialize_DB()
    addon:RegisterSlashCommands()
end

function FarmingBar:OnEnable()
    addon:Initialize_ObjectiveBuilder()
    addon:Initialize_Masque()
    addon:Initialize_Bars()
    addon:InitializeConfig()
    addon:InitializeOptions()
    addon:ClearDeletedObjectives()
    -- TODO: addon:Initialize_Options()
end

function FarmingBar:OnDisable()
    addon.ObjectiveBuilder:Release()
    -- TODO: addon:ReleaseBars()
    -- TODO: addon.Options:Release()
end

--*------------------------------------------------------------------------

function addon:RegisterSlashCommands()
    for command, enabled in pairs(FarmingBar.db.global.commands) do
        if enabled then
            FarmingBar:RegisterChatCommand(command, "SlashCommandFunc")
        else
            FarmingBar:UnregisterChatCommand(command)
        end
    end
end

------------------------------------------------------------

function FarmingBar:SlashCommandFunc(input)
    local cmd, arg, arg2 = strsplit(" ", strupper(input))
    if cmd == "BUILD" then
        addon.ObjectiveBuilder:Load()
    elseif cmd == "BAR" then
        if arg == "ADD" then
            addon:CreateBar()
        elseif arg == "REMOVE" then
            local arg2 = tonumber(arg2)
            if addon.bars[arg2] then
                addon:RemoveBar(arg2)
            end
        end
    elseif cmd == "CONFIG" then
        addon.Config:Load()
    else
        LibStub("AceConfigDialog-3.0"):Open(addonName)
        self:Print([[Currently available commands: "build", "bar add", "bar remove barID", "config"]])
    end
end

--*------------------------------------------------------------------------

function addon:ReportError(error)
    PlaySound(846) -- "sound/interface/igquestfailed.ogg" classic?
    FarmingBar:Print(string.format("%s %s", self.ColorFontString(L["Error"], "red"), error))
end

------------------------------------------------------------

local missing = {}
function addon:IsDataStoreLoaded()
    wipe(missing)

    if not IsAddOnLoaded("DataStore") then
        tinsert(missing, "DataStore")
    end

    if not IsAddOnLoaded("DataStore_Auctions") then
        tinsert(missing, "DataStore_Auctions")
    end

    if not IsAddOnLoaded("DataStore_Containers") then
        tinsert(missing, "DataStore_Containers")
    end

    if not IsAddOnLoaded("DataStore_Inventory") then
        tinsert(missing, "DataStore_Inventory")
    end

    if not IsAddOnLoaded("DataStore_Mails") then
        tinsert(missing, "DataStore_Mails")
    end

    return missing
end

------------------------------------------------------------

function addon:GetAltoholicCount(itemID, includeBank)
    if #self:IsDataStoreLoaded() > 0 then return end

    local count = 0
    for k, character in pairs(DataStore:GetCharacters(GetRealmName(), "Default")) do
        local bags, bank = DataStore:GetContainerItemCount(character, itemID)
        local mail = DataStore:GetMailItemCount(character, itemID) or 0
        local auction = DataStore:GetAuctionHouseItemCount(character, itemID) or 0
        local inventory = DataStore:GetInventoryItemCount(character, itemID) or 0
        count = count + bags + (includeBank and bank or 0) + mail + auction + inventory
    end

    return count
end