-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingBuddies
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"
require "FriendshipLib"
require "math"
require "string"

-----------------------------------------------------------------------------------------------
-- VikingBuddies Module Definition
-----------------------------------------------------------------------------------------------
local VikingBuddies = {}


-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function VikingBuddies:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  -- indexing to call against the radio buttons
  o.arFriends         = {}
  o.arAccountFriends  = {}
  o.arAccountInvites  = {}
  o.arInvites         = {}
  o.tUserSettings     = {}
  o.tExpandedOffsets  = {}
  o.tMinimumSize     = {
    width = 200,
    height = 120
  }
  o.tCollapsedSize   = {
    nOL = 0,
    nOT = 0,
    nOR = 64,
    nOB = 34
  }

  o.cColorOffline = ApolloColor.new("UI_BtnTextGrayNormal")

  o.tStatusColors = {
    [FriendshipLib.AccountPresenceState_Available] = ApolloColor.new("ChatCircle2"),
    [FriendshipLib.AccountPresenceState_Away]      = ApolloColor.new("yellow"),
    [FriendshipLib.AccountPresenceState_Busy]      = ApolloColor.new("red"),
    [FriendshipLib.AccountPresenceState_Invisible] = ApolloColor.new("gray")
  }
  o.tTextColors = {
    [FriendshipLib.AccountPresenceState_Available] = ApolloColor.new("UI_TextHoloBodyHighlight"),
    [FriendshipLib.AccountPresenceState_Away]      = ApolloColor.new("gray"),
    [FriendshipLib.AccountPresenceState_Busy]      = ApolloColor.new("gray"),
    [FriendshipLib.AccountPresenceState_Invisible] = ApolloColor.new("gray")

  }

  o.arListTypes =
  {
    o.arFriends
  }


  return o
end

function VikingBuddies:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = { "VikingLibrary" }
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- VikingBuddies OnLoad
-----------------------------------------------------------------------------------------------
function VikingBuddies:OnLoad()
  -- load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("VikingBuddies.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)

end

function VikingBuddies:OnSave(eType)
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return nil
  end

  local tCurrentOffsets = self:GetCurrentOffsets(self.wndMain)

  if self.bShowList then
    self.tExpandedOffsets = tCurrentOffsets
  end

  local tSavedData = {
    tCurrentOffsets = tCurrentOffsets,
    tExpandedOffsets = self.tExpandedOffsets,
    bShowList = self.bShowList
  }

  return tSavedData
end

function VikingBuddies:OnRestore(eType, tSavedData)

  if tSavedData ~= nil then
    for idx, item in pairs(tSavedData) do
      self.tUserSettings[idx] = item
    end
  end

end


-----------------------------------------------------------------------------------------------
-- VikingBuddies OnDocLoaded
-----------------------------------------------------------------------------------------------
function VikingBuddies:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    self.wndOptions       = Apollo.LoadForm(self.xmlDoc, "VikingBuddiesForm", nil, self)
    self.wndMain          = Apollo.LoadForm(self.xmlDoc, "BuddyList", nil, self)


    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end


    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil

    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

    self.timer = ApolloTimer.Create(1, true, "OnRenderLoop", self)
    Apollo.RegisterSlashCommand("vb", "OnVikingBuddiesOn", self)

    -- Do additional Addon initialization here
    -- Restore the Show State
    self.bShowList = self.tUserSettings.bShowList

    self.wndListWindow    = self.wndMain:FindChild("ListWindow")
    self.wndListContainer = self.wndMain:FindChild("ListContainer")

    -- Show the list window if it's set to show ;)
    self.wndListWindow:Show(self.bShowList, true)
    self.wndMain:Show(true, true)
    self.wndOptions:Show(false, true)


    self.wndMain:SetSizingMinimum(self.tMinimumSize.width, self.tMinimumSize.height)

    -- Restore the checkbutton state
    self.wndMain:FindChild("ListToggleButton"):SetCheck(self.bShowList)
    self:ResizeFriendsList(self.bShowList, true)
  end
end

function VikingBuddies:OnVikingBuddiesOn()
  self.wndMain:SetAnchorOffsets(200, 200, 600, 600)
end


-----------------------------------------------------------------------------------------------
-- VikingBuddies RENDER LOOP
-----------------------------------------------------------------------------------------------

function VikingBuddies:OnRenderLoop()

  -- Don't bother rendering the list if it's not being displayed
  if self.bShowList then
    self:UpdateBuddyList()
  end

  -- Get Number of online buddies
  self:UpdateBuddiesOnline()

end


-----------------------------------------------------------------------------------------------
-- VikingBuddies Render management functions
-----------------------------------------------------------------------------------------------

function VikingBuddies:GetLineByFriendId(nId)
  for key, wndPlayerEntry in pairs(self.wndListContainer:GetChildren()) do
    if wndPlayerEntry:GetData().nId == nId then
      return wndPlayerEntry
    end
  end

  return nil
end


function VikingBuddies:UpdateBuddyLine(tFriend)
  local wndParent = self.wndListContainer
  local wndNew = self:GetLineByFriendId(tFriend.nId)

  -- Check for friend
  if not wndNew then
    wndNew = Apollo.LoadForm(self.xmlDoc, "BuddyLine", self.wndListContainer, self)
    wndNew:SetData(tFriend)
  end

  wndParent:SetData(oData)
  self:UpdateFriendData(wndNew, tFriend)

  return wndNew
end

function VikingBuddies:UpdateFriendData(wndBuddyLine, tFriend)

  local colorText   = self.tTextColors.offline
  local colorStatus = self.tStatusColors.offline

  local bOnline = tFriend.fLastOnline == 0

  if bOnline then
    nPresenceState = tFriend.nPresenceState or 0
    colorText   = self.tTextColors[nPresenceState]
    colorStatus = self.tStatusColors[nPresenceState]
  else
    colorText   = self.cColorOffline
    colorStatus = self.cColorOffline
  end

  -- Update data
  local wndName         = wndBuddyLine:FindChild("Name")
  local wndStatus       = wndBuddyLine:FindChild("StatusIcon")
  -- local wndType         = wndBuddyLine:FindChild("TypeIcon")
  local wndButtons      = wndBuddyLine:FindChild("Buttons")

  wndStatus:SetSprite("VikingSprites:" .. tFriend.type)
  wndStatus:SetSprite("VikingSprites:" .. tFriend.type)

  wndButtons:Show(bOnline)
  wndBuddyLine:Enable(bOnline)
  wndName:SetText(tFriend.strCharacterName)
  wndName:SetTextColor(colorText)
  wndStatus:SetBGColor(colorStatus)

end

function VikingBuddies:GetFriends()
  local arIgnored = {}
  local arFriends = {}

  for key, tFriend in pairs(FriendshipLib.GetList()) do
    if tFriend.bIgnore == true then
      arIgnored[tFriend.nId] = tFriend
    else
      if tFriend.bFriend == true then
        tFriend.type = "Single"
        arFriends[tFriend.nId] = tFriend
      end
    end

  end

  for key, tFriend in pairs(FriendshipLib.GetAccountList()) do
    tFriend.type = "Account"
    arFriends[tFriend.nId] = tFriend
    -- Event_FireGenericEvent("SendVarToRover", "tFriend " .. tFriend.nId, FriendshipLib.GetAccountById(tFriend.nId))
    -- arFriends[tFriend.nId].wnd = self.arFriends[tFriend.nId].wnd
  end

  self.arIgnored = arIgnored
  self.arFriends = arFriends

  return arFriends

end


---------------------------------------------------------------------------------------------------
-- BuddyList Functions
---------------------------------------------------------------------------------------------------


function VikingBuddies:UpdateBuddyList()
  local arFriends = self:GetFriends()
  -- self.wndListContainer:DestroyChildren()
  self.wndListContainer:SetData(arFriends)

  for key, tFriend in pairs(self.arFriends) do
    self:UpdateBuddyLine(tFriend)
  end


  -- Sort the buddy list by "online"
  self.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)

    local friendLeft = wndLeft:GetData()
    local friendRight = wndRight:GetData()

    local leftState = friendLeft.fLastOnline
    local rightState = friendRight.fLastOnline

    return (leftState or 0) < (rightState or 0)

  end)
end


function VikingBuddies:UpdateBuddiesOnline()

  local isOnline = function(tFriend)
    if tFriend.fLastOnline == 0 then return 1 else return 0 end
  end

  local nOnline = 0
  for key, tFriend in pairs(FriendshipLib.GetList()) do
    nOnline = nOnline + isOnline(tFriend)
  end

  for key, tFriend in pairs(FriendshipLib.GetAccountList()) do
    nOnline = nOnline + isOnline(tFriend)
  end

  local txtBuddiesOnline = self.wndMain:FindChild("BuddiesOnline")
  txtBuddiesOnline:SetText(nOnline)

end

function VikingBuddies:ResizeFriendsList(bExpand, bSetup)
  -- Print("VikingBuddies:ResizeFriendsList()")

  local tCurrentOffsets = {}
  local tNewOffsets = {}

  if bSetup and self.tUserSettings.tCurrentOffsets then
    tCurrentOffsets = self.tUserSettings.tCurrentOffsets
    self.tExpandedOffsets = self.tUserSettings.tExpandedOffsets
  else
    tCurrentOffsets.nOL, tCurrentOffsets.nOT, tCurrentOffsets.nOR, tCurrentOffsets.nOB = self.wndMain:GetAnchorOffsets()
  end


  if bExpand then
  -- If the window should be Expanded

    if self.tExpandedOffsets.nOL then
      -- If we already have Expanded Offsets stored

      self.tExpandedOffsets = {
        nOL = tCurrentOffsets.nOL,
        nOT = tCurrentOffsets.nOT,
        nOR = self.tExpandedOffsets.nOR + (tCurrentOffsets.nOL - self.tExpandedOffsets.nOL),
        nOB = self.tExpandedOffsets.nOB + (tCurrentOffsets.nOT - self.tExpandedOffsets.nOT)
      }

    else

      -- This is probably the first time you've run the addon, ever... so we need to set some things up
      self.tExpandedOffsets = {
        nOL = tCurrentOffsets.nOL,
        nOT = tCurrentOffsets.nOT,
        nOR = tCurrentOffsets.nOR + self.tMinimumSize.width,
        nOB = tCurrentOffsets.nOB + self.tMinimumSize.height
      }
    end

    -- Cache the Expanded Offsets to use later on in this method
    tNewOffsets = self.tExpandedOffsets

  else
  -- Otherwise the window should be Collapsed

    if not bSetup then
      -- If this is the first time the addon is loading this session,
      -- then we need to use the CurrentOffsets for the Expanded Data.
      -- ExpandedData is only saved when toggling between minimized and maximized.
      self.tExpandedOffsets = tCurrentOffsets
    end

    tNewOffsets =  {
      nOL = tCurrentOffsets.nOL,
      nOT = tCurrentOffsets.nOT,
      nOR = tCurrentOffsets.nOL + self.tCollapsedSize.nOR,
      nOB = tCurrentOffsets.nOT + self.tCollapsedSize.nOB
    }

  end

  -- You shouldn't be able to resize the window when collapsed
  self.wndMain:SetStyle("Sizable", bExpand)
  self.wndMain:SetAnchorOffsets(tNewOffsets.nOL, tNewOffsets.nOT, tNewOffsets.nOR, tNewOffsets.nOB)

end

function VikingBuddies:ShowFriendsList(bShow)
  self.wndListWindow:Show(bShow, true)
  self:ResizeFriendsList(bShow)

  -- store the display state
  self.bShowList = bShow
end


---------------------------------------------------------------------------------------------------
-- VikingBuddies Event Functions
---------------------------------------------------------------------------------------------------

function VikingBuddies:OnListCheck( wndHandler, wndControl, eMouseButton )
  self:ShowFriendsList(true)
end

function VikingBuddies:OnListUncheck( wndHandler, wndControl, eMouseButton )
  self:ShowFriendsList(false)
end

function VikingBuddies:GetCurrentOffsets(wnd)
  local tCurrentOffsets = {}
  tCurrentOffsets.nOL, tCurrentOffsets.nOT, tCurrentOffsets.nOR, tCurrentOffsets.nOB = wnd:GetAnchorOffsets()
  return tCurrentOffsets
end


---------------------------------------------------------------------------------------------------
-- VikingBuddies:BuddyLine Event Functions
---------------------------------------------------------------------------------------------------

function VikingBuddies:OnGroupButtonClick( wndHandler, wndControl, eMouseButton )
  local data = wndControl:GetParent():GetParent():GetData()
  GroupLib.Invite(data.strCharacterName)

  -- Event_FireGenericEvent("SendVarToRover", "button click", data)
end

function VikingBuddies:OnWhisperButtonClick( wndHandler, wndControl, eMouseButton )
  local data = wndControl:GetParent():GetParent():GetData()
  if data.type == "Account" then
    local strTargetName = data.arCharacters[1].strCharacterName
    local strRealm = data.arCharacters[1].strRealm
    Event_FireGenericEvent("Event_EngageAccountWhisper", data.strCharacterName, strTargetName, strRealm)
  else
    Event_FireGenericEvent("GenericEvent_ChatLogWhisper", data.strCharacterName)
  end
end

-----------------------------------------------------------------------------------------------
-- VikingBuddiesForm Event Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function VikingBuddies:OnOK()
  self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function VikingBuddies:OnCancel()
  self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- VikingBuddies Instance
-----------------------------------------------------------------------------------------------
local VikingBuddiesInst = VikingBuddies:new()
VikingBuddiesInst:Init()
