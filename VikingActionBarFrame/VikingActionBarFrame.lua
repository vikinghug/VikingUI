-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingActionBarFrame
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GameLib"
require "Spell"
require "Unit"
require "Item"
require "PlayerPathLib"
require "AbilityBook"
require "ActionSetLib"
require "AttributeMilestonesLib"
require "Tooltip"
require "HousingLib"


local VikingActionBarFrame = {}
local VikingTooltipCursor = false

function VikingActionBarFrame:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function VikingActionBarFrame:Init()
  local tDependencies = { "VikingLibrary" }
  Apollo.RegisterAddon(self, false, "", tDependencies)
end

function VikingActionBarFrame:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingActionBarFrame.xml")

  -- Load our sprites
end

function VikingActionBarFrame:GetAsyncLoadStatus()
  if not (self.xmlDoc and self.xmlDoc:IsLoaded()) then
    return Apollo.AddonLoadStatus.Loading
  end

  if not self.unitPlayer then
    self.unitPlayer = GameLib.GetPlayerUnit()

    if not self.unitPlayer then
      return Apollo.AddonLoadStatus.Loading
    end
  end

  if not (Tooltip and Tooltip.GetSpellTooltipForm) then
    return Apollo.AddonLoadStatus.Loading
  end

  self:Setup()

  return Apollo.AddonLoadStatus.Loaded
end

function VikingActionBarFrame:Setup()
  g_ActionBarLoaded = false

  Apollo.RegisterEventHandler("UnitEnteredCombat",            "OnUnitEnteredCombat", self)
  Apollo.RegisterEventHandler("PlayerChanged",              "InitializeBars", self)
  Apollo.RegisterEventHandler("WindowSizeChanged",            "InitializeBars", self)
  Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences",      "InitializeBars", self)
  Apollo.RegisterEventHandler("PlayerLevelChange",            "InitializeBars", self)

  Apollo.RegisterEventHandler("AbilityBookChange",      "OnAbilityBookChange", self)
  Apollo.RegisterEventHandler("GuildResult",          "OnGuildResult", self)
  Apollo.RegisterEventHandler("StanceChanged",              "RedrawStances", self)

  Apollo.RegisterEventHandler("ShowActionBarShortcut",          "OnShowActionBarShortcut", self)
  Apollo.RegisterEventHandler("ShowActionBarShortcutDocked",        "OnShowActionBarShortcutDocked", self)
  Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor",         "OnTutorial_RequestUIAnchor", self)
  Apollo.RegisterEventHandler("Options_UpdateActionBarTooltipLocation",   "OnUpdateActionBarTooltipLocation", self)
  Apollo.RegisterEventHandler("ActionBarNonSpellShortcutAddFailed",     "OnActionBarNonSpellShortcutAddFailed", self)
  Apollo.RegisterEventHandler("UpdateInventory",              "OnUpdateInventory", self)
  Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor",   "OnTutorial_RequestUIAnchor", self)

	--Test solution tooltip with slashcommand
  Apollo.RegisterSlashCommand("vui", "OnVikingUISlashCommand", self)

  self.wndBar2 = Apollo.LoadForm(self.xmlDoc, "Bar2ButtonContainer", "FixedHudStratum", self)
  self.wndBar3 = Apollo.LoadForm(self.xmlDoc, "Bar3ButtonContainer", "FixedHudStratum", self)

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "ActionBarFrameForm", "FixedHudStratum", self)
  self.wndBar1 = self.wndMain:FindChild("Bar1ButtonContainer")

  self.wndStanceFlyout = self:CreateFlyout(self.wndMain:FindChild("StanceContainer"), "GCBar", 2)
  self.wndMountFlyout = self:CreateFlyout(self.wndMain:FindChild("MountContainer"), "GCBar", 26)
  self.wndPotionFlyout = self:CreateFlyout(self.wndMain:FindChild("PotionContainer"), "GCBar", 27)
  self.wndRecallFlyout = self:CreateFlyout(self.wndMain:FindChild("RecallContainer"), "GCBar", 18)
  self.wndPathFlyout = self:CreateFlyout(self.wndMain:FindChild("PathContainer"), "LASBar", 9)

  Apollo.RegisterTimerHandler("RedrawRecallTimer", "RedrawRecalls", self)
  Apollo.RegisterTimerHandler("CloseRecallTimer", "CloseRecallFlyout", self)

  g_wndActionBarResources = Apollo.LoadForm(self.xmlDoc, "Resources", "FixedHudStratumLow", self) -- Do not rename. This is global and used by other forms as a parent.

  self.wndMain:Show(false)

  g_ActionBarLoaded = true
  Event_FireGenericEvent("ActionBarLoaded")
  Event_FireGenericEvent("ActionBarReady", self.wndMain)

  self:InitializeBars()

  if self.tCurrentVehicleInfo and unitPlayer:IsInVehicle() then
    self:OnShowActionBarShortcut(self.tCurrentVehicleInfo.nBar, true, self.tCurrentVehicleInfo.nNumShortcuts)
  else
    self.tCurrentVehicleInfo = nil
  end
end

function VikingActionBarFrame:OnSave(eType)
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return
  end

  local tSavedData =
  {
    nSelectedMount = self.nSelectedMount,
    nSelectedPotion = self.nSelectedPotion,
    tVehicleBar = self.tCurrentVehicleInfo
  }

  return tSavedData
end

function VikingActionBarFrame:OnRestore(eType, tSavedData)
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return
  end

  if tSavedData.nSelectedMount then
    self.nSelectedMount = tSavedData.nSelectedMount
  end

  if tSavedData.nSelectedPotion then
    self.nSelectedPotion = tSavedData.nSelectedPotion
  end

  if tSavedData.tVehicleBar then
    self.tCurrentVehicleInfo = tSavedData.tVehicleBar
  end
end

function VikingActionBarFrame:OnPlayerEquippedItemChanged()
  local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
  if (nVisibility == nil or nVisibility < 1) and self:IsWeaponEquipped() then
    Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "skillsBarDisplay")
  end
end

function VikingActionBarFrame:IsWeaponEquipped()
  local unitPlayer = GameLib.GetPlayerUnit()

  local tEquipment = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetEquippedItems() or {}
  for idx, tItemData in pairs(tEquipment) do
    if tItemData:GetSlot() == 16 then
      return true
    end
  end

  return false
end

function VikingActionBarFrame:OnUnitEnteredCombat(unit)
  if unit ~= GameLib.GetPlayerUnit() then
    return
  end

  self:RedrawBarVisibility()
end

function VikingActionBarFrame:InitializeBars()
  self:RedrawStances()
  self:RedrawMounts()
  self:RedrawPotions()
  self:RedrawRecalls()
  self:RedrawPath()

  local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")

  if nVisibility == nil or nVisibility < 1 then
    local bHasWeaponEquipped = self:IsWeaponEquipped()

    if bHasWeaponEquipped then
      -- This isn't a new character, set the preference to always display.
      Apollo.SetConsoleVariable("hud.skillsBarDisplay", 1)
    else
      -- Wait for the player to equip their first item
      Apollo.RegisterEventHandler("PlayerEquippedItemChanged",  "OnPlayerEquippedItemChanged", self)
    end
  end

  self.wndMain:Show(true)
  self.wndBar1:DestroyChildren()
  self.wndBar2:DestroyChildren()
  self.wndBar3:DestroyChildren()

  -- All the buttons
  self.arBarButtons = {}
  self.arBarButtons[0] = self.wndStanceFlyout:FindChild("ActionBarBtn")

  for idx = 1, 34 do
    local wndCurr = nil
    local wndActionBarBtn = nil

    if idx < 9 then
      wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemBig", self.wndBar1, self)
      wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
      wndActionBarBtn:SetContentId(idx - 1)

      if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
        wndCurr:FindChild("LockSprite"):Show(true)
        wndCurr:FindChild("Cover"):Show(false)
      else
        wndCurr:FindChild("LockSprite"):Show(false)
        wndCurr:FindChild("Cover"):Show(true)
      end
    elseif idx < 11 then -- 9 to 10
      -- we'll skip 10 since it has been promoted to a flyout
      if idx == 9 then
        wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemBig", self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons"), self)
        wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
        wndActionBarBtn:SetContentId(idx - 1)

        wndCurr:FindChild("LockSprite"):Show(false)
        wndCurr:FindChild("Cover"):Show(true)

        if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
          wndCurr:SetTooltip(Apollo.GetString("ActionBarFrame_LockedGadgetSlot"))
        end
      end
    elseif idx < 23 then -- 11 to 22
      if Apollo.GetConsoleVariable("hud.secondaryLeftBarDisplay") then
        wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar2, self)
        wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
        wndActionBarBtn:SetContentId(idx + 1)

        --hide bars we can't draw due to screen size
        if (idx - 10) * wndCurr:GetWidth() > self.wndBar2:GetWidth() and self.wndBar2:GetWidth() > 0 then
          wndCurr:Show(false)
        end
      end
    else -- 23 to 34
      if Apollo.GetConsoleVariable("hud.secondaryRightBarDisplay") then
        wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar3, self)
        wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
        wndActionBarBtn:SetContentId(idx + 1)

        --hide bars we can't draw due to screen size
        if (idx - 22) * wndCurr:GetWidth() > self.wndBar3:GetWidth() and self.wndBar3:GetWidth() > 0 then
          wndCurr:Show(false)
        end
      end
    end
    self.arBarButtons[idx] = wndActionBarBtn
  end

  self.wndBar1:ArrangeChildrenHorz(0)
  self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons"):ArrangeChildrenHorz(0)
  self.wndBar2:ArrangeChildrenHorz(0)
  self.wndBar3:ArrangeChildrenHorz(0)
  self:OnUpdateActionBarTooltipLocation()

  self:RedrawBarVisibility()
end

function VikingActionBarFrame:RedrawBarVisibility()
  local unitPlayer = GameLib.GetPlayerUnit()
  local bActionBarShown = self.wndMain:IsShown()

  --Toggle Visibility based on ui preference
  local nSkillsVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
  local nLeftVisibility = Apollo.GetConsoleVariable("hud.secondaryLeftBarDisplay")
  local nRightVisibility = Apollo.GetConsoleVariable("hud.secondaryRightBarDisplay")
  local nResourceVisibility = Apollo.GetConsoleVariable("hud.resourceBarDisplay")
  local nMountVisibility = Apollo.GetConsoleVariable("hud.mountButtonDisplay")

  if nSkillsVisibility == 1 then --always on
    self.wndMain:Show(true)
  elseif nSkillsVisibility == 2 then --always off
    self.wndMain:Show(false)
  elseif nSkillsVisibility == 3 then --on in combat
    self.wndMain:Show(unitPlayer and unitPlayer:IsInCombat())
  elseif nSkillsVisibility == 4 then --on out of combat
    self.wndMain:Show(unitPlayer and not unitPlayer:IsInCombat())
  else
    self.wndMain:Show(false)
  end

  if nResourceVisibility == nil or nResourceVisibility < 1 then
    g_wndActionBarResources:Show(bActionBarShown)
  else
    g_wndActionBarResources:Show(true)
  end

  if nLeftVisibility == 1 then --always on
    self.wndBar2:Show(true)
  elseif nLeftVisibility == 2 then --always off
    self.wndBar2:Show(false)
  elseif nLeftVisibility == 3 then --on in combat
    self.wndBar2:Show(unitPlayer and unitPlayer:IsInCombat())
  elseif nLeftVisibility == 4 then --on out of combat
    self.wndBar2:Show(unitPlayer and not unitPlayer:IsInCombat())
  else
    --NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
    if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
      --Trigger a HUD Tutorial
      Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryLeftBarDisplay")
    end

    self.wndBar2:Show(false)
  end

  if nRightVisibility == 1 then --always on
    self.wndBar3:Show(true)
  elseif nRightVisibility == 2 then --always off
    self.wndBar3:Show(false)
  elseif nRightVisibility == 3 then --on in combat
    self.wndBar3:Show(unitPlayer and unitPlayer:IsInCombat())
  elseif nRightVisibility == 4 then --on out of combat
    self.wndBar3:Show(unitPlayer and not unitPlayer:IsInCombat())
  else
    --NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
    if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
      --Trigger a HUD Tutorial
      Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryRightBarDisplay")
    end

    self.wndBar3:Show(false)
  end


  -- Why draw the mount button if we don't have a mount?
  local tMountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}

  if #tMountList == 0 then
    self.wndMountFlyout:Show(false)
  elseif next(self.wndMountFlyout:FindChild("PopoutList"):GetChildren()) ~= nil then
    if nMountVisibility == 2 then --always off
      self.wndMountFlyout:Show(false)
    elseif nMountVisibility == 3 then --on in combat
      self.wndMountFlyout:Show(unitPlayer and unitPlayer:IsInCombat())
    elseif nMountVisibility == 4 then --on out of combat
      self.wndMountFlyout:Show(unitPlayer and not unitPlayer:IsInCombat())
    else
      self.wndMountFlyout:Show(true)
    end
  else
    self.wndMountFlyout:Show(true)
  end

  local bActionBarShown = self.wndMain:IsShown()

  self.wndPotionFlyout:Show(unitPlayer ~= nil and not unitPlayer:IsInVehicle())

  local nLeft, nTop, nRight, nBottom = g_wndActionBarResources:GetAnchorOffsets()

  if bActionBarShown then
    local nOffset = bFloatingActionBarShown and -173 or -103

    g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, nOffset)
  else
    g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, -19)
  end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw
-----------------------------------------------------------------------------------------------
function VikingActionBarFrame:RedrawStances()
  local nCountSkippingTwo = 0
  local tStanceList = {}

  for idx, spellObject in pairs(GameLib.GetClassInnateAbilitySpells().tSpells) do
    if idx % 2 == 1 then
      nCountSkippingTwo = nCountSkippingTwo + 1
      tStanceList[nCountSkippingTwo] = spellObject
    end
  end

  self:RepopulateFlyout(self.wndStanceFlyout, tStanceList, "Stance")
end

function VikingActionBarFrame:OnStanceBtn(wndHandler, wndControl)
  self.wndStanceFlyout:FindChild("PopoutFrame"):Show(false)
  GameLib.SetCurrentClassInnateAbilityIndex(wndHandler:GetData())
end

function VikingActionBarFrame:RedrawPath()
  local tPathAbilities = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Path) or {}
  local tPathList = {}

  for idx, tBaseAbility in pairs(tPathAbilities) do
    if tBaseAbility.bIsActive then
      tPathList[idx] = tBaseAbility.tTiers[tBaseAbility.nCurrentTier].splObject
    end
  end

  self:RepopulateFlyout(self.wndPathFlyout, tPathList, "Path")
end

function VikingActionBarFrame:OnPathBtn( wndHandler, wndControl, eMouseButton )
  local tActionSet = ActionSetLib.GetCurrentActionSet()

  if tActionSet then
    tActionSet[10] = wndControl:GetData():GetBaseSpellId()
    ActionSetLib.RequestActionSetChanges(tActionSet)
  end

  self.wndPathFlyout:FindChild("PopoutFrame"):Show(false)
end

function VikingActionBarFrame:RedrawMounts()
  local tMounts = CollectiblesLib.GetMountList()
  local tMountList = {}
  local tSelectedSpellObj = nil

  for idx, tMountData  in pairs(tMounts) do
    if tMountData.bIsKnown then
      local tSpellObject = tMountData.splObject
      tMountList[idx] = tSpellObject

      if tSpellObject:GetId() == self.nSelectedMount then
        tSelectedSpellObj = tSpellObject
      end
    end
  end

  if tSelectedSpellObj == nil and #tMountList > 0 then
    tSelectedSpellObj = tMountList[1]
  end

  if tSelectedSpellObj ~= nil then
    GameLib.SetShortcutMount(tSelectedSpellObj:GetId())
  end

  self:RepopulateFlyout(self.wndMountFlyout, tMountList, "Mount")
end

function VikingActionBarFrame:OnMountBtn(wndHandler, wndControl)
  self.nSelectedMount = wndControl:GetData():GetId()
  GameLib.SetShortcutMount(self.nSelectedMount)

  self.wndMountFlyout:FindChild("PopoutFrame"):Show(false)
end

function VikingActionBarFrame:RedrawPotions()
  local unitPlayer = GameLib.GetPlayerUnit()

  local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
  local tSelectedPotion = nil;
  local tFirstPotion = nil
  local tPotionList = { }

  for idx, tItemData in pairs(tItemList) do
    if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then
      local tItem = tItemData.itemInBag

      if tFirstPotion == nil then
        tFirstPotion = tItem
      end

      if tItem:GetItemId() == self.nSelectedPotion then
        tSelectedPotion = tItem
      end

      tPotionList[tItem:GetItemId()] = tItem
    end
  end

  if tSelectedPotion == nil and tFirstPotion ~= nil then
    tSelectedPotion = tFirstPotion
  end

  if tSelectedPotion ~= nil then
    GameLib.SetShortcutPotion(tSelectedPotion:GetItemId())
  end

  self:RepopulateFlyout(self.wndPotionFlyout, tPotionList, "Potion")
end

function VikingActionBarFrame:OnPotionBtn(wndHandler, wndControl)
  self.nSelectedPotion = wndControl:GetData():GetItemId()

  self.wndPotionFlyout:FindChild("PopoutFrame"):Show(false)
  self:RedrawPotions()
end

function VikingActionBarFrame:OnShowActionBarShortcut(nWhichBar, bIsVisible, nNumShortcuts)
  if nWhichBar == 0 and self.wndMain and self.wndMain:IsValid() then
    if self.arBarButtons then
      for idx, wndBtn in pairs(self.arBarButtons) do
        wndBtn:Enable(not bIsVisible) -- Turn on or off all buttons
      end
    end

    self:ShowVehicleBar(nWhichBar, bIsVisible, nNumShortcuts) -- show/hide vehicle bar if nWhichBar matches
  end
end

function VikingActionBarFrame:OnShowActionBarShortcutDocked(bVisible)
  self:RedrawBarVisibility()
end

function VikingActionBarFrame:ShowVehicleBar(nWhichBar, bIsVisible, nNumShortcuts)
  if nWhichBar ~= 0 or not self.wndMain or not self.wndMain:IsValid() then
    return
  end

  local wndVehicleBar = self.wndMain:FindChild("VehicleBarMain")
  wndVehicleBar:Show(bIsVisible)

  self.wndStanceFlyout:Show(not bIsVisible)
  self.wndMain:FindChild("Bar1ButtonSmallContainer"):Show(not bIsVisible)

  self.wndBar1:Show(not bIsVisible)

  self.tCurrentVehicleInfo = nil

  if bIsVisible then
    for idx = 1, 6 do -- TODO hardcoded formatting
      wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(false)
    end

    if nNumShortcuts then
      for idx = 1, math.max(2, nNumShortcuts) do -- Art width does not support just 1
        wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(true)
        wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):FindChild("ActionBarShortcut." .. idx):Enable(true)
      end

      local nLeft, nTop ,nRight, nBottom = wndVehicleBar:FindChild("VehicleBarFrame"):GetAnchorOffsets() -- TODO SUPER HARDCODED FORMATTING
      wndVehicleBar:FindChild("VehicleBarFrame"):SetAnchorOffsets(nLeft, nTop, nLeft + (58 * nNumShortcuts) + 66, nBottom)
    end

    wndVehicleBar:ArrangeChildrenHorz(1)

    self.tCurrentVehicleInfo =
    {
      nBar = nWhichBar,
      nNumShortcuts = nNumShortcuts,
    }
  end
end

-- Solution for tooltip at cursor option
-- on SlashCommand "/VTooltip"

function VikingActionBarFrame:OnVikingUISlashCommand(strCmd, strParam)
  if string.find(strParam, "actiontooltip") == 1 then
    if string.find(strParam, "1") == 15 then
      VikingTooltipCursor = true
      Print("ActionBar ToolTips will show at Cursor")
    elseif string.find(strParam, "0") == 15 then
      VikingTooltipCursor = false
      Print("ActionBar ToolTips will not show at Cursor")
    end
  end
Event_FireGenericEvent("Options_UpdateActionBarTooltipLocation")
end

function VikingActionBarFrame:OnUpdateActionBarTooltipLocation()
  for idx = 0, 9 do
    self:HelperSetTooltipType(self.arBarButtons[idx])
  end
end

function VikingActionBarFrame:HelperSetTooltipType(wnd)
  if VikingTooltipCursor == true then
    wnd:SetTooltipType(Window.TPT_OnCursor)
  else
    wnd:SetTooltipType(Window.TPT_DynamicFloater)
  end
end


function VikingActionBarFrame:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
  if eAnchor == GameLib.CodeEnumTutorialAnchor.AbilityBar or eAnchor == GameLib.CodeEnumTutorialAnchor.InnateAbility then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  end
end

function VikingActionBarFrame:OnUpdateInventory()
  local unitPlayer = GameLib.GetPlayerUnit()

  if self.nPotionCount == nil then
    self.nPotionCount = 0
  end

  local nLastPotionCount = self.nPotionCount
  local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
  local tPotions = { }

  for idx, tItemData in pairs(tItemList) do
    if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then--and tItemData.itemInBag:GetConsumable() == "Consumable" then
      local tItem = tItemData.itemInBag

      if tPotions[tItem:GetItemId()] == nil then
        tPotions[tItem:GetItemId()] = {}
        tPotions[tItem:GetItemId()].nCount=tItem:GetStackCount()
      else
        tPotions[tItem:GetItemId()].nCount = tPotions[tItem:GetItemId()].nCount + tItem:GetStackCount()
      end
    end
  end

  self.nPotionCount = 0
  for idx, tItemData in pairs(tPotions) do
    self.nPotionCount = self.nPotionCount + 1
  end

  if self.nPotionCount ~= nLastPotionCount then
    self:RedrawPotions()
  end
end

function VikingActionBarFrame:OnGenerateTooltip(wndControl, wndHandler, eType, arg1, arg2)
  local xml = nil
  if eType == Tooltip.TooltipGenerateType_ItemInstance then -- Doesn't need to compare to item equipped
    Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
  elseif eType == Tooltip.TooltipGenerateType_ItemData then -- Doesn't need to compare to item equipped
    Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
  elseif eType == Tooltip.TooltipGenerateType_GameCommand then
    xml = XmlDoc.new()
    xml:AddLine(arg2)
    wndControl:SetTooltipDoc(xml)
  elseif eType == Tooltip.TooltipGenerateType_Macro then
    xml = XmlDoc.new()
    xml:AddLine(arg1)
    wndControl:SetTooltipDoc(xml)
  elseif eType == Tooltip.TooltipGenerateType_Spell then
    if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
      Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
    end
  elseif eType == Tooltip.TooltipGenerateType_PetCommand then
    xml = XmlDoc.new()
    xml:AddLine(arg2)
    wndControl:SetTooltipDoc(xml)
  end
end

function VikingActionBarFrame:OnActionBarNonSpellShortcutAddFailed()
  --TODO: Print("You can not add that to your Limited Action Set bar.")
end

function VikingActionBarFrame:CreateFlyout(wndContainer, strContentType, nContentID)
  -- to circumvent an API limitation an actionbarbutton template should be made for each different content type
  -- templates should follow the recipe: "FlyoutBtn_ContentType" eg. "FlyoutBtn_LASBar"

  local wndFlyout = Apollo.LoadForm(self.xmlDoc, "Flyout", wndContainer, self)
  wndFlyout:SetAnchorPoints(0, 0, 1, 1)
  wndFlyout:SetAnchorOffsets(0, 0, 0, 0)

  local wndActionBarBtn = Apollo.LoadForm(self.xmlDoc, "FlyoutBtn_" .. strContentType, wndFlyout, self)
  wndActionBarBtn:SetName("ActionBarBtn")
  wndActionBarBtn:SetContentId(nContentID)

  wndFlyout:FindChild("PopoutBtn"):AttachWindow(wndFlyout:FindChild("PopoutFrame"))

  return wndFlyout
end

function VikingActionBarFrame:RepopulateFlyout(wndFlyout, tList, strType)
  -- tList contains either spellObject or itemObject

  local wndPopoutList = wndFlyout:FindChild("PopoutFrame:PopoutList")

  wndPopoutList:DestroyChildren()

  for idx, tObject in pairs(tList) do
    local wndCurr = Apollo.LoadForm(self.xmlDoc, strType .. "Btn", wndPopoutList, self)

    wndCurr:FindChild(strType .. "BtnIcon"):SetSprite(tObject:GetIcon())

    if strType == "Potion" then
      local nCount = tObject:GetBackpackCount()
      if nCount > 1 then wndCurr:FindChild("PotionBtnStackCount"):SetText(nCount) end
    elseif strType == "Stance" then
      local strKeyBinding = GameLib.GetKeyBinding("SetStance"..idx)
      wndCurr:FindChild("StanceBtnKeyBind"):SetText(strKeyBinding == "<Unbound>" and "" or strKeyBinding)
    end

    wndCurr:SetData(strType == "Stance" and idx or tObject)

    if Tooltip then
      wndCurr:SetTooltipDoc(nil)

      if strType == "Potion" then
        Tooltip.GetItemTooltipForm(self, wndCurr, tObject, {})
      else
        Tooltip.GetSpellTooltipForm(self, wndCurr, tObject, {})
      end
    end
  end

  self:UpdateFlyoutSize(wndFlyout)
end

function VikingActionBarFrame:UpdateFlyoutSize(wndFlyout)
  local wndPopoutFrame = wndFlyout:FindChild("PopoutFrame")
  local wndPopoutList = wndPopoutFrame:FindChild("PopoutList")

  local nCount = #wndPopoutList:GetChildren()
  if nCount > 0 then
    local nMax = 7
    local nMaxHeight = (wndPopoutList:ArrangeChildrenVert(0) / nCount) * nMax
    local nHeight = wndPopoutList:ArrangeChildrenVert(0)
    nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight

    local nLeft, nTop, nRight, nBottom = wndPopoutFrame:GetAnchorOffsets()

    if nCount > nMax then
      local nButtonWidth = wndPopoutList:GetChildren()[1]:GetWidth()
      local nFlyoutWidth = wndFlyout:GetWidth()
      local nScrollWidth = 13 -- scrollbar seems to be somewhere between 12 and 13 px
      nRight = nButtonWidth + nScrollWidth - nFlyoutWidth
      wndPopoutList:AddStyle("VScroll")
    else
      wndPopoutList:RemoveStyle("VScroll")
    end
    wndPopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight, nRight, nBottom)
    --wndPopoutList:ArrangeChildrenTiles()
  end

  wndFlyout:GetParent():Show(nCount > 0)
end

function VikingActionBarFrame:RedrawRecalls()
  local wndPopoutList = self.wndRecallFlyout:FindChild("PopoutFrame:PopoutList")

  local tBindList = self:GetBindList()

  wndPopoutList:DestroyChildren()

  for idx, nRecallCommand in pairs(tBindList) do
    local wndRecallEntry = Apollo.LoadForm(self.xmlDoc, "RecallEntry", wndPopoutList, self)
    wndRecallEntry:FindChild("RecallEntryBtn"):SetContentId(nRecallCommand)
  end

  self:UpdateFlyoutSize(self.wndRecallFlyout)

  GameLib.SetDefaultRecallCommand(tBindList[0] or GameLib.CodeEnumRecallCommand.BindPoint)
  self.wndRecallFlyout:FindChild("ActionBarBtn"):SetContentId(GameLib.GetDefaultRecallCommand())
end

function VikingActionBarFrame:OnRecallBtn(wndHandler, wndControl)
  Apollo.CreateTimer("CloseRecallTimer", 0.001, false)
end

function VikingActionBarFrame:CloseRecallFlyout()
  self.wndRecallFlyout:FindChild("PopoutFrame"):Show(false)
end

function VikingActionBarFrame:GetBindList()
  local tBinds = {}

  if GameLib.HasBindPoint() == true then
    table.insert(tBinds, GameLib.CodeEnumRecallCommand.BindPoint)
  end

  if HousingLib.IsResidenceOwner() == true then
    table.insert(tBinds, GameLib.CodeEnumRecallCommand.House)
  end

  for key, guildCurr in pairs(GuildLib.GetGuilds()) do
    if guildCurr:GetType() == GuildLib.GuildType_WarParty then
      table.insert(tBinds, GameLib.CodeEnumRecallCommand.Warplot)
      break
    end
  end

  for idx, tSpell in pairs(AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Misc) or {}) do
    if tSpell.bIsActive then
      if tSpell.nId == GameLib.GetTeleportIlliumSpell():GetBaseSpellId() then
        table.insert(tBinds, GameLib.CodeEnumRecallCommand.Illium)
      elseif tSpell.nId == GameLib.GetTeleportThaydSpell():GetBaseSpellId() then
        table.insert(tBinds, GameLib.CodeEnumRecallCommand.Thayd)
      end
    end
  end

  return tBinds
end

function VikingActionBarFrame:OnGuildResult(guildCurr, strName, nRank, eResult)
  local tResults = {
    [GuildLib.GuildResult_GuildDisbanded] = 0,
    [GuildLib.GuildResult_KickedYou] = 1,
    [GuildLib.GuildResult_YouQuit] = 2,
    [GuildLib.GuildResult_YouJoined] = 3,
    [GuildLib.GuildResult_YouCreated] = 4
  }

  if tResults[eResult] ~= nil then
    Apollo.CreateTimer("RedrawRecallTimer", 0.001, false)
  end
end

function VikingActionBarFrame:OnAbilityBookChange()
  self:RedrawMounts()
  self:RedrawRecalls()
  self:RedrawPath()
end

function VikingActionBarFrame:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
  if eAnchor == GameLib.CodeEnumTutorialAnchor.Recall then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndRecallFlyout:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  end
end

local VikingActionBarFrameInst = VikingActionBarFrame:new()
VikingActionBarFrameInst:Init()
