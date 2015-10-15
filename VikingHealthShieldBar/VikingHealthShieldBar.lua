-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingHealthShieldBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Apollo"
require "GameLib"
require "Spell"
require "Unit"
require "Item"

local VikingHealthShieldBar = {}

function VikingHealthShieldBar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function VikingHealthShieldBar:Init()
  local tDependencies = { "VikingLibrary" }
  Apollo.RegisterAddon(self, false, "", tDependencies)
end

-- let's create some member variables
local tColors = {
  black       = ApolloColor.new("ff201e2d"),
  white       = ApolloColor.new("ffffffff"),
  lightGrey   = ApolloColor.new("ffbcb7da"),
  green       = ApolloColor.new("cc06ff5e"),
  yellow      = ApolloColor.new("ffffd161"),
  lightPurple = ApolloColor.new("ff645f7e"),
  purple      = ApolloColor.new("ff28253a"),
  red         = ApolloColor.new("ffe05757"),
  blue        = ApolloColor.new("cc49e8ee")
}

local knEvadeResource = 7 -- the resource hooked to dodges (TODO replace with enum)

local eEnduranceFlash =
{
  EnduranceFlashZero = 1,
  EnduranceFlashOne = 2,
  EnduranceFlashTwo = 3,
  EnduranceFlashThree = 4,
}

function VikingHealthShieldBar:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
  self.xmlDoc = XmlDoc.CreateFromFile("VikingHealthShieldBar.xml")
  Apollo.RegisterEventHandler("InterfaceOptionsLoaded", "OnDocumentReady", self)
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  Apollo.RegisterEventHandler("WindowManagementReady"      , "OnWindowManagementReady"      , self)
  Apollo.RegisterEventHandler("WindowManagementUpdate"     , "OnWindowManagementUpdate"     , self)
end

function VikingHealthShieldBar:OnDocumentReady()
  if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() or not g_InterfaceOptionsLoaded or self.wndMain then
    return
  end
  Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor",       "OnTutorial_RequestUIAnchor", self)
  Apollo.RegisterEventHandler("UnitEnteredCombat",          "OnEnteredCombat", self)
  Apollo.RegisterEventHandler("RefreshVikingHealthShieldBar",         "OnFrameUpdate", self)

  Apollo.RegisterTimerHandler("HealthShieldBarTimer",         "OnFrameUpdate", self)
  Apollo.RegisterTimerHandler("EnduranceDisplayTimer",        "OnEnduranceDisplayTimer", self)

  Apollo.CreateTimer("HealthShieldBarTimer", 0.5, true)
  --Apollo.CreateTimer("EnduranceDisplayTimer", 30, false) --TODO: Fix(?) This is perma-killing the display when DT dashing is disabled via the toggle



  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingHealthShieldBarForm", "FixedHudStratum", self)

  self.wndEndurance = self.wndMain:FindChild("EnduranceContainer")

  self.bInCombat = false
  self.eEnduranceState = eEnduranceFlash.EnduranceFlashZero
  self.bEnduranceFadeTimer = false

  -- For flashes
  self.nLastEnduranceValue = 0

  -- todo: make this selective
  self.wndEndurance:Show(false, true)

  self.xmlDoc = nil
  self:OnFrameUpdate()
end

function VikingHealthShieldBar:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = "Viking DashBar"} )
end

function VikingHealthShieldBar:OnWindowManagementUpdate(tWindow)
  if tWindow and tWindow.wnd and tWindow.wnd == self.wndMain then
    local bMoveable = tWindow.wnd:IsStyleOn("Moveable")

    tWindow.wnd:SetStyle("RequireMetaKeyToMove", bMoveable)
    tWindow.wnd:SetStyle("IgnoreMouse", not bMoveable)
  end
end


function VikingHealthShieldBar:OnFrameUpdate()
  local unitPlayer = GameLib.GetPlayerUnit()
  if unitPlayer == nil then
    return
  end

  -- Evades
  local nEvadeCurr = unitPlayer:GetResource(knEvadeResource)
  local nEvadeMax = unitPlayer:GetMaxResource(knEvadeResource)
  self:UpdateEvades(nEvadeCurr, nEvadeMax)

  -- Evade Blocker
  -- TODO: Store this and only update when needed
  local bShowDoubleTapToDash = Apollo.GetConsoleVariable("player.showDoubleTapToDash")
  local bSettingDoubleTapToDash = Apollo.GetConsoleVariable("player.doubleTapToDash")

  -- Show/Hide EnduranceEvade UI
  if self.bInCombat or nRunCurr ~= nRunMax or nEvadeCurr ~= nEvadeMax or bShowDoubleTapToDash then
    Apollo.StopTimer("EnduranceDisplayTimer")
    self.bEnduranceFadeTimer = false
    self.wndEndurance:Show(true, true)
  elseif not self.bEnduranceFadeTimer then
    Apollo.StopTimer("EnduranceDisplayTimer")
    Apollo.StartTimer("EnduranceDisplayTimer")
    self.bEnduranceFadeTimer = true
  end

  --Toggle Visibility based on ui preference
  local unitPlayer = GameLib.GetPlayerUnit()
  local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")

  if nVisibility == 1 then --always on
    self.wndMain:Show(true)
  elseif nVisibility == 2 then --always off
    self.wndMain:Show(false)
  elseif nVisibility == 3 then --on in combat
    self.wndMain:Show(unitPlayer:IsInCombat())
  elseif nVisibility == 4 then --on out of combat
    self.wndMain:Show(not unitPlayer:IsInCombat())
  else
    self.wndMain:Show(false)
  end

  --hide evade UI while in a vehicle.
  if unitPlayer:IsInVehicle() then
    self.wndMain:Show(false)
  end
end

function VikingHealthShieldBar:UpdateEvades(nEvadeValue, nEvadeMax)
  local nTickValue = nEvadeValue % 100

  local n = 2

  if nEvadeValue >= 200 then
    n = 0
  elseif nEvadeValue >= 100 then
    n = 1
  end

  for i = 1, 2 do
    wndMarker         = self.wndEndurance:FindChild("Marker" .. i)
    wndMarkerProgress = wndMarker:FindChild('EvadeProgress')
    wndMarkerProgress:Show(i == n)
    wndMarker:Show(true)

    if i > n then
      wndMarker:SetBGColor(tColors.yellow)
    else
      wndMarker:SetBGColor(99141122)
    end

    if i == n then
      wndMarkerProgress:SetMax(100)
      wndMarkerProgress:SetProgress(nTickValue)
    end

  end

  local strEvadeTooltip = Apollo.GetString(Apollo.GetConsoleVariable("player.doubleTapToDash") and "HealthBar_EvadeDoubleTapTooltip" or "HealthBar_EvadeKeyTooltip")
  local strDisplayTooltip = String_GetWeaselString(strEvadeTooltip, math.floor(nEvadeValue / 100), math.floor(nEvadeMax / 100))

  self.nLastEnduranceValue = nEvadeValue
end

function VikingHealthShieldBar:OnEnteredCombat(unit, bInCombat)
  if unit == GameLib.GetPlayerUnit() then
    self.bInCombat = bInCombat
  end
end

function VikingHealthShieldBar:OnEnduranceDisplayTimer()
  self.bEnduranceFadeTimer = false
  self.wndEndurance:Show(false)
end

function VikingHealthShieldBar:OnMouseButtonDown(wnd, wndControl, iButton, nX, nY, bDouble)
  if iButton == 0 then -- Left Click
    GameLib.SetTargetUnit(GameLib.GetPlayerUnit())
  end
  return true -- stop propogation
end

function VikingHealthShieldBar:OnDisableDashToggle(wndHandler, wndControl)
  Apollo.SetConsoleVariable("player.doubleTapToDash", not wndControl:IsChecked())
  self.wndEndurance:FindChild("EvadeProgress"):Show(not wndControl:IsChecked())
  self:OnFrameUpdate()
end

function VikingHealthShieldBar:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
  if eAnchor == GameLib.CodeEnumTutorialAnchor.DashMeter then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  elseif eAnchor == GameLib.CodeEnumTutorialAnchor.ClassResource then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  elseif eAnchor == GameLib.CodeEnumTutorialAnchor.HealthBar then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  elseif eAnchor == GameLib.CodeEnumTutorialAnchor.ShieldBar then
    local tRect = {}
    tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
    Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  end
end

local VikingHealthShieldBarInst = VikingHealthShieldBar:new()
VikingHealthShieldBarInst:Init()
