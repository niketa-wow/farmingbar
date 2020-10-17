local addonName, addon = ...
local FarmingBar = LibStub("AceAddon-3.0"):GetAddon("FarmingBar")
local L = LibStub("AceLocale-3.0"):GetLocale("FarmingBar", true)
local AceGUI = LibStub("AceGUI-3.0", true)

local tinsert, pairs, wipe = table.insert, pairs, table.wipe
local strfind, strupper = string.find, string.upper

--*------------------------------------------------------------------------

local function ObjectiveButton_OnClick(objectiveTitle)
    addon:ObjectiveBuilder_DrawTabs()
    addon.ObjectiveBuilder.mainContent:SelectObjective(objectiveTitle)
end

--*------------------------------------------------------------------------

local function GetObjectiveContextMenu()
    local selected = addon.ObjectiveBuilder.status.selected
    local multiSelected = #selected > 1

    local menu = {
        {
            text = multiSelected and L["Duplicate All"] or L["Duplicate"],
            notCheckable = true,
            func = function(self)
                for key, objective in pairs(selected) do
                    local objectiveTitle = objective:GetObjectiveTitle()
                    addon:CreateObjective(objectiveTitle, addon:GetObjectiveInfo(objectiveTitle), multiSelected and true, multiSelected and key == #selected)
                end
            end,
        },
        {text = "", notCheckable = true, notClickable = true},
        {
            text = multiSelected and L["Delete All"] or L["Delete"],
            notCheckable = true,
            func = function() addon:DeleteSelectedObjectives() end,
        },
        {text = "", notCheckable = true, notClickable = true},
        {
            text = L["Close"],
            notCheckable = true,
        }
    }

    if not multiSelected then
        tinsert(menu, 1, {
            text = L["Rename"],
            notCheckable = true,
            func = function(self) selected[1]:RenameObjective() end,
        })
        tinsert(menu, 3, {
            text = L["Export"],
            disabled = true,
            notCheckable = true,
            func = function() end,
        })
    end

    return menu
end

--*------------------------------------------------------------------------

local methods = {
    ["GetSelectedObjective"] = function(self)
        return self.status.objectiveTitle
    end,

    ["GetSelectedTracker"] = function(self)
        return self.status.tracker
    end,

    ["GetObjectiveButtonByTitle"] = function(self, objectiveTitle)
        for key, objective in pairs(self.status.children) do
            if objective.objectiveTitle == objectiveTitle then
                return objective.button
            end
        end
    end,

    ["Load"] = function(self)
        self:Show()
        self:LoadObjectives()
    end,

    ["LoadObjectives"] = function(self, objectiveTitle)
        local sideContent, mainPanel, mainContent = self.sideContent, self.mainPanel, self.mainContent
        sideContent:ReleaseChildren()
        wipe(self.status.selected)
        wipe(self.status.children)

        local filter = self.objectiveSearchBox:GetText()
        for objectiveTitle, objective in addon.pairs(FarmingBar.db.global.objectives) do
            if not filter or strfind(strupper(objectiveTitle), strupper(filter)) then
                local button = AceGUI:Create("FB30_ObjectiveButton")
                button:SetFullWidth(true)
                button:SetText(objectiveTitle)
                button:SetIcon(addon:GetObjectiveIcon(objectiveTitle))
                button:SetStatus(self.status)
                button:SetMenuFunc(GetObjectiveContextMenu)
                sideContent:AddChild(button)
                tinsert(self.status.children, {objectiveTitle = objectiveTitle, button = button})

                ------------------------------------------------------------

                button:SetCallback("OnClick", function(self, event, ...) ObjectiveButton_OnClick(objectiveTitle) end)
                button:SetCallback("OnDragStart", function(self, event, ...) addon.DragFrame:Load(objectiveTitle) end)
                button:SetCallback("OnDragStop", function(self, event, ...) addon.DragFrame:Clear() end)
            end
        end

        if objectiveTitle then
            local button = addon.ObjectiveBuilder:GetObjectiveButtonByTitle(objectiveTitle)
            if button then
                button.frame:Click()
            end
        else
            mainPanel:ReleaseChildren()
        end
    end,

    ["Release"] = function(self)
        AceGUI:Release(self)
    end,

    ["UpdateObjectiveIcon"] = function(self, objectiveTitle)
        self:GetObjectiveButtonByTitle(objectiveTitle):SetIcon(addon:GetObjectiveIcon(objectiveTitle))
    end,

    ["UpdateTrackerButton"] = function(self)
        local tracker = self:GetSelectedTracker()
        local trackerInfo = addon:GetTrackerInfo(self:GetSelectedObjective(), tracker)
        -- !Try to remove this if I can set up a coroutine to handle item caching.
        addon:GetObjectiveDataTable(trackerInfo.trackerType, trackerInfo.trackerID, function(data)
            local button = addon.ObjectiveBuilder.trackerList.status.children[tracker].button
            button:SetText(data.name == "" and L["Invalid Tracker"] or data.name)
            button:SetIcon(data.icon)
        end)
        -- !
    end,
}

------------------------------------------------------------

function addon:Initialize_ObjectiveBuilder()
    local ObjectiveBuilder = AceGUI:Create("FB30_Window")
    ObjectiveBuilder:SetTitle("Farming Bar "..L["Objective Builder"])
    ObjectiveBuilder:SetSize(700, 500)
    ObjectiveBuilder:SetLayout("FB30_2RowSplitBottom")
    ObjectiveBuilder:Hide()
    self.ObjectiveBuilder = ObjectiveBuilder
    ObjectiveBuilder.status = {children = {}, selected = {}}

    for method, func in pairs(methods) do
        ObjectiveBuilder[method] = func
    end

    ------------------------------------------------------------

    local topContent = AceGUI:Create("SimpleGroup")
    topContent:SetFullWidth(true)
    topContent:SetHeight(20)
    topContent:SetLayout("Flow")
    topContent:SetAutoAdjustHeight(false)
    ObjectiveBuilder:AddChild(topContent)
    ObjectiveBuilder.topContent = topContent

    ------------------------------------------------------------

    local newObjectiveButton = AceGUI:Create("FB30_InteractiveLabel")
    newObjectiveButton:SetText(L["New Objective"])
    newObjectiveButton:SetWidth(newObjectiveButton.label:GetStringWidth() + newObjectiveButton.image:GetWidth())
    newObjectiveButton:SetImageSize(newObjectiveButton.label:GetHeight(), newObjectiveButton.label:GetHeight())
    newObjectiveButton:SetImage(514607)
    topContent:AddChild(newObjectiveButton)

    newObjectiveButton:SetCallback("OnClick", function() addon:CreateObjective(_, _, _, _, true) end)
    newObjectiveButton:SetCallback("OnReceiveDrag", function() addon:CreateObjective(_, _, _, _, true) end)

    ------------------------------------------------------------

    local importObjectiveButton = AceGUI:Create("FB30_InteractiveLabel")
    importObjectiveButton:SetText(L["Import Objective"])
    importObjectiveButton:SetWidth(importObjectiveButton.label:GetStringWidth() + importObjectiveButton.image:GetWidth())
    importObjectiveButton:SetImageSize(importObjectiveButton.label:GetHeight(), importObjectiveButton.label:GetHeight())
    importObjectiveButton:SetImage(131906, 1, 0, 0, 1)
    importObjectiveButton:SetDisabled(true)
    topContent:AddChild(importObjectiveButton)

    -- importObjectiveButton:SetCallback("OnClick", function() ????? end) -- TODO: implement import/export

    ------------------------------------------------------------

    local sidePanel = AceGUI:Create("SimpleGroup")
    sidePanel:SetRelativeWidth(1/4)
    sidePanel:SetFullHeight(true)
    sidePanel:SetLayout("FB30_2RowFill")
    ObjectiveBuilder:AddChild(sidePanel)

    ------------------------------------------------------------

    local objectiveSearchBox = AceGUI:Create("FB30_SearchEditBox")
    objectiveSearchBox:SetFullWidth(true)
    sidePanel:AddChild(objectiveSearchBox)
    ObjectiveBuilder.objectiveSearchBox = objectiveSearchBox

    objectiveSearchBox:SetCallback("OnTextChanged", function(self) ObjectiveBuilder:LoadObjectives(self:GetText()) end)
    objectiveSearchBox:SetCallback("OnEnterPressed", function(self) self:ClearFocus() end)

    ------------------------------------------------------------

    local sideContent = AceGUI:Create("ScrollFrame")
    sideContent:SetLayout("List")
    sidePanel:AddChild(sideContent)
    ObjectiveBuilder.sideContent = sideContent

    ------------------------------------------------------------

    local mainPanel = AceGUI:Create("SimpleGroup")
    mainPanel:SetRelativeWidth(3/4)
    mainPanel:SetFullHeight(true)
    mainPanel:SetLayout("Fill")
    ObjectiveBuilder:AddChild(mainPanel)
    ObjectiveBuilder.mainPanel = mainPanel

    ------------------------------------------------------------

    self:Initialize_DragFrame()

    ------------------------------------------------------------
    --Debug-----------------------------------------------------
    ------------------------------------------------------------
    if FarmingBar.db.global.debug.ObjectiveBuilder then
        C_Timer.After(1, function()
            ObjectiveBuilder:Load()

            for _, objective in pairs(addon.ObjectiveBuilder.status.children) do
                objective.button.frame:Click()
                addon.ObjectiveBuilder.mainContent:SelectTab("trackersTab")
                break
            end

            if FarmingBar.db.global.debug.ObjectiveBuilderTrackers then
                for _, tracker in pairs(ObjectiveBuilder.trackerList.status.children) do
                    tracker.button.frame:Click()
                    break
                end
            end
        end)
    end
    ------------------------------------------------------------
    ------------------------------------------------------------
end