require "Window"
require "ApolloTimer"
local VikingLib
local VikingClassResources = {
  _VERSION = 'VikingClassResources.lua 0.2.0',
  _URL     = 'https://github.com/vikinghug/VikingClassResources',
  _DESCRIPTION = '',
  _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2014 Kevin Altman

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

-- GameLib.CodeEnumClass.Warrior      = 1
-- GameLib.CodeEnumClass.Engineer     = 2
-- GameLib.CodeEnumClass.Esper        = 3
-- GameLib.CodeEnumClass.Medic        = 4
-- GameLib.CodeEnumClass.Stalker      = 5
-- GameLib.CodeEnumClass.Spellslinger = 7

 local tClassName = {
  [GameLib.CodeEnumClass.Warrior]      = "Warrior",
  [GameLib.CodeEnumClass.Engineer]     = "Engineer",
  [GameLib.CodeEnumClass.Esper]        = "Esper",
  [GameLib.CodeEnumClass.Medic]        = "Medic",
  [GameLib.CodeEnumClass.Stalker]      = "Stalker",
  [GameLib.CodeEnumClass.Spellslinger] = "Spellslinger"
}

local tShowNodes = {
  [GameLib.CodeEnumClass.Warrior]      = false,
  [GameLib.CodeEnumClass.Engineer]     = false,
  [GameLib.CodeEnumClass.Esper]        = true,
  [GameLib.CodeEnumClass.Medic]        = true,
  [GameLib.CodeEnumClass.Stalker]      = true,
  [GameLib.CodeEnumClass.Spellslinger] = true
}

local tResourceType = {
  [GameLib.CodeEnumClass.Warrior]      = 1,
  [GameLib.CodeEnumClass.Engineer]     = 1,
  [GameLib.CodeEnumClass.Esper]        = 1,
  [GameLib.CodeEnumClass.Medic]        = 1,
  [GameLib.CodeEnumClass.Stalker]      = 3,
  [GameLib.CodeEnumClass.Spellslinger] = 4
}

local tInnateTime = {
  [GameLib.CodeEnumClass.Warrior]      = 8,
  [GameLib.CodeEnumClass.Engineer]     = 10.5,
  [GameLib.CodeEnumClass.Esper]        = 0,
  [GameLib.CodeEnumClass.Medic]        = 0,
  [GameLib.CodeEnumClass.Stalker]      = 0,
  [GameLib.CodeEnumClass.Spellslinger] = 0
}

local tVikingModeType = {
  [GameLib.CodeEnumClass.Warrior]      = "Hardcore",
  [GameLib.CodeEnumClass.Engineer]     = "Hardcore",
  [GameLib.CodeEnumClass.Esper]        = "Hardcore",
  [GameLib.CodeEnumClass.Medic]        = "Hardcore",
  [GameLib.CodeEnumClass.Stalker]      = "Stealth",
  [GameLib.CodeEnumClass.Spellslinger] = "Hardcore"
}

function VikingClassResources:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function VikingClassResources:Init()
  Apollo.RegisterAddon(self, nil, nil, {"VikingActionBarFrame","VikingLibrary"})
end

function VikingClassResources:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingClassResources.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
  Apollo.RegisterEventHandler("WindowManagementReady"      , "OnWindowManagementReady"      , self)
  Apollo.RegisterEventHandler("WindowManagementUpdate"     , "OnWindowManagementUpdate"     , self)

  Apollo.LoadSprites("VikingClassResourcesSprites.xml")
end

function VikingClassResources:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end

  self.bDocLoaded = true
  self:OnRequiredFlagsChanged()
end

function VikingClassResources:OnRequiredFlagsChanged()
  if g_wndActionBarResources and self.bDocLoaded then
    if GameLib.GetPlayerUnit() then
      self:OnCharacterCreated()
    else
      Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
    end
  end
end

function VikingClassResources:GetDefaults()

  return {
    char = {
    VikingMode = {
      VikingModeShow = false,
    },   
    textStyle = {
      ResourceTextPercent = false,
      ResourceTextValue   = false,
      OutlineFont         = false,
    }
  }
}
end

function VikingClassResources:OnCharacterCreated()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer then
    return
  end
  self.eClassID =  unitPlayer:GetClassId()

  self:CreateClassResources()

  if VikingLib == nil then
    VikingLib = Apollo.GetAddon("VikingLibrary")
  end

  if VikingLib ~= nil then
    self.db = VikingLib.Settings.RegisterSettings(self, "VikingClassResources", self:GetDefaults(), "Class Resources")
  end
end

function VikingClassResources:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = "Viking Class Resources"} )
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndPet,  strName = "Viking Pet Resource"} )
end

function VikingClassResources:OnWindowManagementUpdate(tWindow)
  if tWindow and tWindow.wnd and tWindow.wnd == self.wndMain then
    local bMoveable = tWindow.wnd:IsStyleOn("Moveable")

    tWindow.wnd:SetStyle("RequireMetaKeyToMove", bMoveable)
    tWindow.wnd:SetStyle("IgnoreMouse", not bMoveable)
  end
end


function VikingClassResources:CreateClassResources()

  Apollo.RegisterEventHandler("VarChange_FrameCount",     "OnUpdateTimer", self)
  Apollo.RegisterEventHandler("UnitEnteredCombat",        "OnEnteredCombat", self)
  Apollo.RegisterTimerHandler("OutOfCombatFade",          "OnOutOfCombatFade", self)


  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingClassResourceForm", FixedHudStratumLow, self)
  self.wndMain:ToFront()

  if self.eClassID == GameLib.CodeEnumClass.Engineer then
    self.wndPet = Apollo.LoadForm(self.xmlDoc, "PetBarContainer", FixedHudStratumLow, self)
    Apollo.RegisterEventHandler("ShowActionBarShortcut", "OnShowActionBarShortcut", self)
    self.wndPet:FindChild("StanceMenuOpenerBtn"):AttachWindow(self.wndPet:FindChild("StanceMenuBG"))
    self.wndPet:ToFront()

    self.wndMain:FindChild("PrimaryProgress:EngineerGuide"):Show(true)

    for idx = 1, 5 do
      self.wndPet:FindChild("Stance"..idx):SetData(idx)
    end

  end
  self.wndMain:FindChild("Nodes"):Show(tShowNodes[self.eClassID])
end


function VikingClassResources:ResizeResourceNodes(nResourceMax)
  local nOffsets = {}
  nOffsets.nOL, nOffsets.nOT, nOffsets.nOR, nOffsets.nOB = self.wndMain:GetAnchorOffsets()

  local nWidth = (nOffsets.nOR - nOffsets.nOL) / nResourceMax

  for i = 1, nResourceMax do
    local p       = i-1
    local wndNode = self.wndMain:FindChild("Node" .. i)
    wndNode:SetAnchorPoints(0, 0, 0, 1)
    wndNode:SetAnchorOffsets(nWidth * p, 0, nWidth * i, 0)
  end

end

function VikingClassResources:OnUpdateTimer()
  local unitPlayer = GameLib.GetPlayerUnit()
  local className  = tClassName[self.eClassID]
  local resourceID = tResourceType[self.eClassID]


  local nResourceMax     = unitPlayer:GetMaxResource(resourceID)
  local nResourceCurrent = unitPlayer:GetResource(resourceID)
  self["Update" .. className .. "Resources"](self, unitPlayer, nResourceMax, nResourceCurrent)

end


function VikingClassResources:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  local wndPrimaryProgress = self.wndMain:FindChild("PrimaryProgressBar")
  local nProgressCurrent   = nResourceCurrent and nResourceCurrent or math.floor(unitPlayer:GetMana())
  local nProgressMax       = nResourceMax and nResourceMax or math.floor(unitPlayer:GetMaxMana())
  local className          = tClassName[self.eClassID]

  wndPrimaryProgress:SetMax(nProgressMax)
  wndPrimaryProgress:SetProgress(nProgressCurrent)
  wndPrimaryProgress:SetTooltip(String_GetWeaselString(Apollo.GetString( className .. "Resource_FocusTooltip" ), nProgressCurrent, nProgressMax))



  --Primary Text Style

  local wndResourceText      = self.wndMain:FindChild("PrimaryProgress:PrimaryProgressText")
  local bResourceTextPercent = self.db.char.textStyle["ResourceTextPercent"]
  local bResourceTextValue   = self.db.char.textStyle["ResourceTextValue"]

  if bResourceTextPercent and not bResourceTextValue then
    wndResourceText:SetText(math.floor(nProgressCurrent  / nProgressMax * 100) .. "%")
  elseif bResourceTextValue and not bResourceTextPercent then
    wndResourceText:SetText(nProgressCurrent .. "/" .. nProgressMax)
  elseif bResourceTextPercent and bResourceTextValue then
    wndResourceText:SetText(string.format("%d/%d (%d%%)", nProgressCurrent, nProgressMax, math.floor(nProgressCurrent  / nProgressMax * 100)))
  end

  if self.eClassID == GameLib.CodeEnumClass.Engineer then
    wndResourceText:Show(bResourceTextPercent or bResourceTextValue)
  else
    wndResourceText:Show(not self.bInnateActive and (bResourceTextPercent or bResourceTextValue))
  end
  
  if self.db.char.textStyle["OutlineFont"] then
        wndResourceText:SetFont("CRB_InterfaceSmall_O")
  else
        wndResourceText:SetFont("Default")
  end
end


--
-- WARRIOR


function VikingClassResources:UpdateWarriorResources(unitPlayer, nResourceMax, nResourceCurrent)
  local bInnate              = GameLib.IsOverdriveActive()
  local wndPrimaryProgress   = self.wndMain:FindChild("PrimaryProgressBar")
  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")
  local unitPlayer           = GameLib.GetPlayerUnit()

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  wndPrimaryProgress:Show(not self.bInnateActive)

  -- Innate Bar
  wndSecondaryProgress:Show(self.bInnateActive)
  self:UpdateInnateProgress(bInnate)

  -- Innate State Indicator
  self:ShowInnateIndicator()
end

--
-- ENGINEER

function VikingClassResources:UpdateEngineerResources(unitPlayer, nResourceMax, nResourceCurrent)
  local bInnate              = GameLib.IsCurrentInnateAbilityActive()
  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")
  local wndProgressBar       = self.wndMain:FindChild("PrimaryProgressBar")
  local wndGuide             = self.wndMain:FindChild("PrimaryProgress:EngineerGuide")

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)

  if nResourceCurrent >= 30 and nResourceCurrent <= 70 then
    -- wndProgressBar
    wndGuide:SetBGColor('aa' .. tColors.red)
  else
    wndGuide:SetBGColor('99' .. tColors.lightPurple)
  end

  -- Innate Bar
  self:UpdateInnateProgress(bInnate)

  -- Innate State Indicator
  self:ShowInnateIndicator()
end

--
-- ESPER

function VikingClassResources:UpdateEsperResources(unitPlayer, nResourceMax, nResourceCurrent)

  -- Primary Resource (Psi Points)
  self:ResizeResourceNodes(nResourceMax)

  for i = 1, nResourceMax do
    local nShow = nResourceCurrent >= i and 1 or 0

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nShow)
    wndNodeProgress:SetProgress(nShow)
  end


  -- Secondary Resource (Focus)
  self:UpdateProgressBar(unitPlayer)


  -- Innate State Indicator
  self:ShowInnateIndicator()
end


--
-- MEDIC

function VikingClassResources:UpdateMedicResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nPartialMax   = 3
  local unitPlayer    = GameLib.GetPlayerUnit()
  local nPartialCount = 0

  --
  -- Primary Resource
  self:UpdateProgressBar(unitPlayer)

  -- Primary / Partial Resource
  --   This is a bit tricky, a buff is used to show partial fill on the primary resource
  tBuffs = unitPlayer:GetBuffs()

  for idx, tCurrBuffData in pairs(tBuffs.arBeneficial or {}) do
    if tCurrBuffData.splEffect:GetId() == 42569 then
      nPartialCount = tCurrBuffData.nCount
      break
    end
  end

  for i = 1, nResourceMax do
    local nProgress = nPartialMax
    if i-1 < nResourceCurrent then
      nProgress = nPartialMax
    elseif i-1 == nResourceCurrent then
      nProgress = nPartialCount
    else
      nProgress = 0
    end

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nPartialMax)
    wndNodeProgress:SetProgress(nProgress)
  end

  -- Innate State Indicator
  self:ShowInnateIndicator()
end



--
-- STALKER

function VikingClassResources:UpdateStalkerResources(unitPlayer, nResourceMax, nResourceCurrent)

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)

  -- Innate State Indicator
  self:ShowInnateIndicator()
end



--
-- SPELLSLINGER

function VikingClassResources:UpdateSpellslingerResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nNodes            = 4
  local unitPlayer        = GameLib.GetPlayerUnit()
  local nNodeProgressSize = nResourceMax / nNodes


  -- Primary Resource
  self:UpdateProgressBar(unitPlayer)

  -- Innate State Indicator
  self:ShowInnateIndicator()

  for i = 1, nNodes do
    local nPartialProgress = nResourceCurrent - (nNodeProgressSize * (i - 1))
    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nNodeProgressSize)
    wndNodeProgress:SetProgress(nPartialProgress, nResourceMax)
  end
end


function VikingClassResources:OnEnteredCombat()
end


function VikingClassResources:OnOutOfCombatFade()
end


function VikingClassResources:OnEngineerPetBtnMouseEnter(wndHandler, wndControl)

  wndHandler:SetBGColor("white")

  local strHover = ""
  local strWindowName = wndHandler:GetName()


  if strWindowName == "ActionBarShortcut.12" then
    strHover = Apollo.GetString("ClassResources_Engineer_PetAttack")
  elseif strWindowName == "ActionBarShortcut.13" then
    strHover = Apollo.GetString("CRB_Stop")
  elseif strWindowName == "ActionBarShortcut.15" then
    strHover = Apollo.GetString("ClassResources_Engineer_GoTo")
  end

  self.wndPet:FindChild("PetText"):SetText(strHover)
end

function VikingClassResources:OnEngineerPetBtnMouseExit(wndHandler, wndControl)

  local strPetText = self.wndPet:FindChild("PetText"):GetData() or ""

  wndHandler:SetBGColor("UI_AlphaPercent50")

  self.wndPet:FindChild("PetText"):SetText(strPetText)
end

function VikingClassResources:OnPetBtn(wndHandler, wndControl)

  local bPetShow = self.wndPet:FindChild("PetBar"):IsShown()

  self.wndPet:FindChild("PetBar"):Show(not bPetShow)
end

function VikingClassResources:OnStanceBtn(wndHandler, wndControl)

  Pet_SetStance(0, tonumber(wndHandler:GetData())) -- First arg is for the pet ID, 0 means all engineer pets

  self.wndPet:FindChild("StanceMenuOpenerBtn"):SetCheck(false)
  self.wndPet:FindChild("PetText"):SetText(wndHandler:GetText())
  self.wndPet:FindChild("PetText"):SetData(wndHandler:GetText())
end

function VikingClassResources:OnShowActionBarShortcut(nWhichBar, bIsVisible, nNumShortcuts)

  if nWhichBar ~= 1 or not self.wndPet or not self.wndPet:IsValid() then -- 1 is hardcoded to be the engineer pet bar
    return
  end

  self.wndPet:FindChild("PetBtn"):Show(bIsVisible)
  self.wndPet:FindChild("PetBar"):Show(bIsVisible)
end


-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

--
-- UpdateInnateProgress
--
-- Innates that have timers use this method to indicate their decay progress

function VikingClassResources:UpdateInnateProgress(bInnate)

  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")

  if bInnate then
    if not self.bInnateActive then

      self.bInnateActive = true

      local nProgressMax = tInnateTime[self.eClassID] * 10

      wndSecondaryProgress:Show(true)
      wndSecondaryProgress:SetMax(nProgressMax)
      wndSecondaryProgress:SetProgress(nProgressMax)

      self.InnateTimerTick = ApolloTimer.Create(0.01, true, "OnInnateTimerTick", self)
      self.InnateTimerDone = ApolloTimer.Create(tInnateTime[self.eClassID], false, "OnInnateTimerDone", self)
    end
  else
    if self.InnateTimerTick ~= nil then
      self.InnateTimerTick:Stop()
    end

    self.bInnateActive = false
    wndSecondaryProgress:Show(false)
  end
end

function VikingClassResources:OnInnateTimerTick()
  self.wndMain:FindChild("SecondaryProgressBar"):SetProgress(0, 10)
end

function VikingClassResources:OnInnateTimerDone()
  self.bInnateActive = false
  self.InnateTimerTick:Stop()
  self.wndMain:FindChild("SecondaryProgressBar"):Show(false)
end

--
-- ShowInnateIndicator
--
--   The animated sprite shown when your Innate is active

function VikingClassResources:ShowInnateIndicator()
  local bInnate       = GameLib.IsCurrentInnateAbilityActive()
  local wndVikingMode = self.wndMain:FindChild("Innate" .. tVikingModeType[self.eClassID])
  local wndInnateGlow = self.wndMain:FindChild("InnateGlow")
  local bVikingMode   = self.db.char.VikingMode["VikingModeShow"]

  if bVikingMode then
    -- Viking Mode
    wndVikingMode:Show(bInnate)
    wndInnateGlow:Show(false)
  else
    -- Normal Innate
    wndInnateGlow:Show(bInnate)
    wndVikingMode:Show(false)
  end
end

--
--
--
--
function VikingClassResources:HelperToggleVisibiltyPreferences(wndParent, unitPlayer)
  -- TODO: REFACTOR: Only need to update this on Combat Enter/Exit
  -- Toggle Visibility based on ui preference
  local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

  if nVisibility == 2 then --always off
    wndParent:Show(false)
  elseif nVisibility == 3 then --on in combat
    wndParent:Show(unitPlayer:IsInCombat())
  elseif nVisibility == 4 then --on out of combat
    wndParent:Show(not unitPlayer:IsInCombat())
  else
    wndParent:Show(true)
  end
end

function VikingClassResources:OnGeneratePetCommandTooltip(wndControl, wndHandler, eType, arg1, arg2)
  local xml = nil
  if eType == Tooltip.TooltipGenerateType_PetCommand then
    xml = XmlDoc.new()
    xml:AddLine(arg2)
    wndControl:SetTooltipDoc(xml)
  elseif eType == Tooltip.TooltipGenerateType_Spell then
    xml = XmlDoc.new()
    if arg1 ~= nil then
      xml:AddLine(arg1:GetFlavor())
    end
    wndControl:SetTooltipDoc(xml)
  end
end

---------------------------------------------------------------------------------------------------
-- VikingSettings Functions
---------------------------------------------------------------------------------------------------

function VikingClassResources:OnSettingsTextStyle( wndHandler, wndControl, eMouseButton )
  self.db.char.textStyle[wndControl:GetName()] = wndControl:IsChecked()
end

function VikingClassResources:OnSettingsVikingMode( wndHandler, wndControl, eMouseButton )
  self.db.char.VikingMode[wndControl:GetName()] = wndControl:IsChecked()
end

-- Called when the settings form needs to be updated so it visually reflects the options
function VikingClassResources:UpdateSettingsForm(wndContainer)
  --VikingMode
  wndContainer:FindChild("VikingMode:Content:VikingModeShow"):SetCheck(self.db.char.VikingMode["VikingModeShow"])

  --Text Styles
  wndContainer:FindChild("ResourceText:Content:ResourceTextPercent"):SetCheck(self.db.char.textStyle["ResourceTextPercent"])
  wndContainer:FindChild("ResourceText:Content:ResourceTextValue"):SetCheck(self.db.char.textStyle["ResourceTextValue"])
  wndContainer:FindChild("ResourceText:Content:OutlineFont"):SetCheck(self.db.char.textStyle["OutlineFont"])
  
end

local VikingClassResourcesInst = VikingClassResources:new()
VikingClassResourcesInst:Init()



