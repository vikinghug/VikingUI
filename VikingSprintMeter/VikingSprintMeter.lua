-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingSprintMeter
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "GameLib"
require "Apollo"

local VikingLib
local VikingSprintMeter = {}

function VikingSprintMeter:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function VikingSprintMeter:Init()
  local tDependencies = { "VikingLibrary" }
  Apollo.RegisterAddon(self, false, "", tDependencies)
end

function VikingSprintMeter:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingSprintMeter.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
  Apollo.RegisterEventHandler("WindowManagementReady"      , "OnWindowManagementReady"      , self)
  Apollo.RegisterEventHandler("WindowManagementUpdate"     , "OnWindowManagementUpdate"     , self)
end

function VikingSprintMeter:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
  Apollo.RegisterTimerHandler("SprintMeterGracePeriod"   , "OnSprintMeterGracePeriod"    , self)
  Apollo.RegisterEventHandler("VarChange_FrameCount"     , "OnFrame"                     , self)
  Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor" , "OnTutorial_RequestUIAnchor" , self)

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingSprintMeterForm", "FixedHudStratum", self)
  self.wndMain:Show(false, true)
  --self.wndMain:SetUnit(GameLib.GetPlayerUnit(), 40) -- 1 or 9 are also good

  self.bJustFilled = false
  self.nLastSprintValue = 0

  --Settings
  if VikingLib == nil then
    VikingLib = Apollo.GetAddon("VikingLibrary")
  end

  if VikingLib ~= nil then
    self.db = VikingLib.Settings.RegisterSettings(self, "VikingSprintMeter", self:GetDefaults(), "Sprint Meter")
  end
end

function VikingSprintMeter:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = "Viking SprintBar"} )
end

function VikingSprintMeter:OnWindowManagementUpdate(tWindow)
  if tWindow and tWindow.wnd and tWindow.wnd == self.wndMain then
    local bMoveable = tWindow.wnd:IsStyleOn("Moveable")

    tWindow.wnd:SetStyle("RequireMetaKeyToMove", bMoveable)
    tWindow.wnd:SetStyle("IgnoreMouse", not bMoveable)
  end
end

function VikingSprintMeter:GetDefaults()
  return {
    char = {
      SprintMeterShow = false
    }  
  }
end

function VikingSprintMeter:OnFrame()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer then
    return
  end

  local bWndVisible = self.wndMain:IsVisible()
  local nRunCurr    = unitPlayer:GetResource(0)
  local nRunMax     = unitPlayer:GetMaxResource(0)
  local bAtMax      = nRunCurr == nRunMax or unitPlayer:IsDead()
  local bShowSprint = self.db.char.SprintMeterShow

  self.wndMain:FindChild("ProgBar"):SetMax(nRunMax)
  self.wndMain:FindChild("ProgBar"):SetProgress(nRunCurr, bWndVisible and nRunMax or 0)

  if self.nLastSprintValue ~= nRunCurr then
    self.nLastSprintValue = nRunCurr
  end

  if bWndVisible and bAtMax and not self.bJustFilled then
    self.bJustFilled = true
    Apollo.StopTimer("SprintMeterGracePeriod")
    Apollo.CreateTimer("SprintMeterGracePeriod", 0.4, false)
    --self.wndMain:FindChild("ProgFlash"):SetSprite("sprResourceBar_Sprint_ProgFlash")
  end

  if not bAtMax then
    self.bJustFilled = false
    Apollo.StopTimer("SprintMeterGracePeriod")
  end

  self.wndMain:Show(bShowSprint or not bAtMax or self.bJustFilled, not bAtMax)
end

function VikingSprintMeter:OnSprintMeterGracePeriod()
  Apollo.StopTimer("SprintMeterGracePeriod")
  self.bJustFilled = false
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Show(false)
  end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function VikingSprintMeter:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
  if eAnchor == GameLib.CodeEnumTutorialAnchor.VikingSprintMeter then

  local tRect = {}
  tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

  Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
  end
end

---------------------------------------------------------------------------------------------------
-- VikingSettings Functions
---------------------------------------------------------------------------------------------------

function VikingSprintMeter:OnSettingsSprintMeter( wndHandler, wndControl, eMouseButton )
  self.db.char.SprintMeterShow = wndControl:IsChecked()
end

-- Called when the settings form needs to be updated so it visually reflects the options
function VikingSprintMeter:UpdateSettingsForm(wndContainer)
  --Show SprintMeter to set new position
  wndContainer:FindChild("SprintMeterShow:Content:ShowSprintMeter"):SetCheck(self.db.char.SprintMeterShow)
end


local VikingSprintMeterInst = VikingSprintMeter:new()
VikingSprintMeterInst:Init()
