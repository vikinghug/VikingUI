-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingSettings
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local NAME = "VikingSettings"
local VERSION = "0.0.1"

tColors = {
  black       = "141122",
  white       = "ffffff",
  lightGrey   = "bcb7da",
  green       = "1fd865",
  aqua        = "2fd5ac",
  yellow      = "ffd161",
  orange      = "e08457",
  lightPurple = "645f7e",
  purple      = "2b273d",
  red         = "e05757",
  blue        = "4ae8ee"
}

local defaults = {
  char = {
    colors = {
      background = "992b273d",
      gradient   = "ff141122"
    },
    dispositionColors = {
      [Unit.CodeEnumDisposition.Neutral]  = "ff" .. tColors.yellow,
      [Unit.CodeEnumDisposition.Hostile]  = "ff" .. tColors.red,
      [Unit.CodeEnumDisposition.Friendly] = "ff" .. tColors.green,
    }
  }
}

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local MergeTables, RegisterDefaults, UpdateForm, UpdateAllForms, CreateAddonForm
local BuildSettingsWindow, SortByKey, DisplayNameCompare, ResetNamespace

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local VikingSettings = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon(
                                  NAME,
                                  true,
                                  {
                                    "Gemini:Logging-1.2",
                                    "GeminiColor",
                                    "Gemini:DB-1.0"
                                  })

local tDisplayNames = {}
local tAddons = {}
local wndContainers = {}
local wndButtons = {}

local wndSettings

local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
local glog

local GColor = Apollo.GetPackage("GeminiColor").tPackage

local db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(VikingSettings, defaults)

function VikingSettings:OnInitialize()
  glog = GeminiLogging:GetLogger({
              level = GeminiLogging.INFO,
              pattern = "%d [%c:%n] %l - %m",
              appender = "GeminiConsole"
             })

  glog:info(string.format("Loaded "..NAME.." - "..VERSION))

  self.xmlDoc = XmlDoc.CreateFromFile("VikingSettings.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function VikingSettings:OnDocLoaded()
  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    Apollo.RegisterSlashCommand("vui", "OnVikingUISlashCommand", self)

    VikingSettings.RegisterSettings(self, "VikingSettings", nil, "Settings")
  end
end

function VikingSettings.RegisterSettings(tAddon, strAddonName, tDefaults, strDisplayName)
  if db:GetNamespace(strAddonName, true) then
    return
  end

  tAddons[strAddonName] = tAddon
  tDisplayNames[strAddonName] = strDisplayName or strAddonName

  return db:RegisterNamespace(strAddonName, tDefaults)
end

function VikingSettings:ResetAddon(strAddonName)
  local tAddonDb = db:GetNamespace(strAddonName, true)

  if tAddonDb then
    ResetNamespace(tAddonDb)
    UpdateForm(strAddonName)
  end
end

function VikingSettings:ResetAllAddons()
  ResetNamespace(db)
  UpdateAllForms()
end

function ResetNamespace(tNamespace)
  if not tNamespace then
    return
  end

  local tSections = rawget(tNamespace, "keys")

  for section in pairs(tSections) do
    if tostring(section) ~= "profiles" then
      tNamespace:ResetSection(tostring(section))
    end
  end
end

function VikingSettings:ShowSettings(bShow)
  if bShow then
    if not wndSettings then
      BuildSettingsWindow()
    end

    UpdateAllForms()
  end

  wndSettings:Show(bShow, false)
end

function UpdateForm(strAddonName)
  local tAddon = tAddons[strAddonName]
  local wndContainer = wndContainers[strAddonName]

  if wndContainer and tAddon and tAddon.UpdateSettingsForm then
    tAddon:UpdateSettingsForm(wndContainer)
  end
end

function UpdateAllForms()
  for strAddonName, tAddon in pairs(tAddons) do
    UpdateForm(strAddonName)
  end
end

function BuildSettingsWindow()
  wndSettings = Apollo.LoadForm(VikingSettings.xmlDoc, "VikingSettingsForm", nil, VikingSettings)

  local tSorted = SortByKey(tAddons, DisplayNameCompare)

  for i, strAddonName in ipairs(tSorted) do
    CreateAddonForm(strAddonName)
    wndButtons[strAddonName]:SetAnchorOffsets(0, (i - 1) * 40, 0, i * 40)
  end

  wndButtons[tSorted[1]]:SetCheck(true)
  VikingSettings:OnSettingsMenuButtonCheck( wndButtons[tSorted[1]] )
end

function SortByKey(t, compare)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, compare)
  return a
end

function DisplayNameCompare(a,b)
  return tDisplayNames[a] < tDisplayNames[b]
end

function CreateAddonForm(strAddonName)
  local tAddon = tAddons[strAddonName]
  local wndAddonContainer = Apollo.LoadForm(tAddon.xmlDoc, "VikingSettings", wndSettings:FindChild("Content"), tAddon)
  local wndAddonButton    = Apollo.LoadForm(VikingSettings.xmlDoc, "AddonButton", wndSettings:FindChild("Menu"), VikingSettings)
  local ButtonText        = wndAddonButton:FindChild("Text")

  -- attaching makes it show/hide the container according to the check state
  wndAddonButton:AttachWindow(wndAddonContainer)
  ButtonText:SetText(tDisplayNames[strAddonName])
  wndAddonButton:Show(true)
  wndAddonButton:SetCheck(false)

  wndAddonContainer:Show(false)

  wndContainers[strAddonName] = wndAddonContainer
  wndButtons[strAddonName] = wndAddonButton
end

-----------------------------------------------------------------------------------------------
-- Color Functions
-----------------------------------------------------------------------------------------------

function VikingSettings.GetColors()
  return tColors
end

--
-- ShowColorPickerForSetting(tSection, strKeyName[, callback][, wndControl])
--
--   Shows a color picker for a specific color setting in the database
--
-- tSection is a reference to the table containing the color
-- strKeyName is the key name for the color in that section
-- callback is a function reference that's called when the color changes
-- wndControl is a window which bagground will show the color
--
-- callback(tSection, strKeyName, strColor, wndControl)
--
function VikingSettings.ShowColorPickerForSetting(tSection, strKeyName, callback, wndControl)
  local strInitialColor = tSection[strKeyName]

  GColor:ShowColorPicker(VikingSettings, "OnColorPicker", true, strInitialColor, tSection, strKeyName, callback, wndControl)
end

function VikingSettings:OnColorPicker(strColor, tSection, strKeyName, callback, wndControl)
  tSection[strKeyName] = strColor

  if wndControl then
    wndControl:SetBGColor(strColor)
  end

  if callback then
    callback(tSection, strKeyName, strColor, wndControl)
  end
end

local function ButtonColors( wnd, fg, bg )
  if wnd then
    wnd:SetBGColor(ApolloColor.new(bg))
    wnd:FindChild("Text"):SetTextColor(ApolloColor.new(fg))
    wnd:FindChild("Arrow"):SetBGColor(ApolloColor.new(fg))
  end
end

-----------------------------------------------------------------------------------------------
-- VikingSettings Form Functions
-----------------------------------------------------------------------------------------------
function VikingSettings:OnSettingsMenuButtonCheck( wndHandler, wndControl, eMouseButton )
  ButtonColors(wndHandler, "ff"..tColors.purple, "ff"..tColors.yellow)
  wndSettings:FindChild("Content"):SetVScrollPos(0)
  wndSettings:FindChild("Content"):RecalculateContentExtents()
end

function VikingSettings:OnSettingMenuButtonUncheck( wndHandler, wndControl, eMouseButton )
  ButtonColors(wndHandler, "ff"..tColors.lightGrey, "00"..tColors.purple)
end

function VikingSettings:OnResetEverythingButton( wndHandler, wndControl, eMouseButton )
  VikingSettings:ResetAllAddons()
end

-----------------------------------------------------------------------------------------------
-- VikingSettings Functions
-----------------------------------------------------------------------------------------------
function VikingSettings:OnVikingUISlashCommand(strCmd, strParam)
  self:ShowSettings(true)
end

function VikingSettings:OnConfigure()
  self:ShowSettings(true)
end

-----------------------------------------------------------------------------------------------
-- VikingSettingsForm Functions
-----------------------------------------------------------------------------------------------
function VikingSettings:OnCloseButton()
  self:ShowSettings(false)
end



