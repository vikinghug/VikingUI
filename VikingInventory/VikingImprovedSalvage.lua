require "Window"
require "Apollo"
require "ApolloCursor"
require "GameLib"
require "Item"

local VikingImprovedSalvage = {}

local kidBackpack = 0

local karEvalColors =
{
  [Item.CodeEnumItemQuality.Inferior]  = "ItemQuality_Inferior",
  [Item.CodeEnumItemQuality.Average]   = "ItemQuality_Average",
  [Item.CodeEnumItemQuality.Good]      = "ItemQuality_Good",
  [Item.CodeEnumItemQuality.Excellent] = "ItemQuality_Excellent",
  [Item.CodeEnumItemQuality.Superb]    = "ItemQuality_Superb",
  [Item.CodeEnumItemQuality.Legendary] = "ItemQuality_Legendary",
  [Item.CodeEnumItemQuality.Artifact]  = "ItemQuality_Artifact",
}

function VikingImprovedSalvage:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  return o
end

function VikingImprovedSalvage:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingImprovedSalvage.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function VikingImprovedSalvage:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end

  Apollo.RegisterEventHandler("WindowManagementReady",    "OnWindowManagementReady", self)

  Apollo.RegisterEventHandler("RequestSalvageAll", "OnSalvageAll", self) -- using this for bag changes
  Apollo.RegisterSlashCommand("salvageall", "OnSalvageAll", self)

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingImprovedSalvageForm", nil, self)
  self.wndItemDisplay = self.wndMain:FindChild("ItemDisplayWindow")
  self.scrappy = Apollo.GetAddon("Scrappy")

  if self.locSavedWindowLoc then
    self.wndMain:MoveToLocation(self.locSavedWindowLoc)
  end

  self.tContents = self.wndMain:FindChild("HiddenBagWindow")
  self.arItemList = nil
  self.nItemIndex = nil

  self.wndMain:Show(false, true)
end

function VikingImprovedSalvage:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Viking Salvage" })
end

--------------------//-----------------------------
function VikingImprovedSalvage:OnSalvageAll()
  if self.scrappy == nil then
    self.arItemList = {}
    self.nItemIndex = 1

    local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
    for idx, tItem in ipairs(tInvItems) do
      if tItem and tItem.itemInBag and tItem.itemInBag:CanSalvage() and not tItem.itemInBag:CanAutoSalvage() then
        table.insert(self.arItemList, tItem.itemInBag)
      end
    end

    self:RedrawAll()
  end
end

function VikingImprovedSalvage:OnSalvageListItemCheck(wndHandler, wndControl)
  if not wndHandler or not wndHandler:GetData() then
    return
  end

  self.nItemIndex = wndHandler:GetData().nIdx

  local itemCurr = self.arItemList[self.nItemIndex]
  self.wndMain:SetData(itemCurr)
  self.wndMain:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, itemCurr:GetInventoryId())
end

function VikingImprovedSalvage:OnSalvageListItemGenerateTooltip(wndControl, wndHandler) -- wndHandler is VendorListItemIcon
  if wndHandler ~= wndControl then
    return
  end

  wndControl:SetTooltipDoc(nil)

  local tListItem = wndHandler:GetData().tItem
  local tPrimaryTooltipOpts = {}

  tPrimaryTooltipOpts.bPrimary = true
  tPrimaryTooltipOpts.itemModData = tListItem.itemModData
  tPrimaryTooltipOpts.strMaker = tListItem.strMaker
  tPrimaryTooltipOpts.arGlyphIds = tListItem.arGlyphIds
  tPrimaryTooltipOpts.tGlyphData = tListItem.itemGlyphData
  tPrimaryTooltipOpts.itemCompare = tListItem:GetEquippedItemForItemType()

  if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
    Tooltip.GetItemTooltipForm(self, wndControl, tListItem, tPrimaryTooltipOpts, tListItem.nStackSize)
  end
end

function VikingImprovedSalvage:RedrawAll()
  local itemCurr = self.arItemList[self.nItemIndex]

  if itemCurr ~= nil then
    local wndParent = self.wndMain:FindChild("MainScroll")
    local nScrollPos = wndParent:GetVScrollPos()
    wndParent:DestroyChildren()

    for idx, tItem in ipairs(self.arItemList) do
      local wndCurr = Apollo.LoadForm(self.xmlDoc, "VikingSalvageListItem", wndParent, self)
      wndCurr:FindChild("SalvageListItemBtn"):SetData({nIdx = idx, tItem=tItem})
      wndCurr:FindChild("SalvageListItemBtn"):SetCheck(idx == self.nItemIndex)

      wndCurr:FindChild("SalvageListItemTitle"):SetTextColor(karEvalColors[tItem:GetItemQuality()])
      wndCurr:FindChild("SalvageListItemTitle"):SetText(tItem:GetName())

      local bTextColorRed = self:HelperPrereqFailed(tItem)
      wndCurr:FindChild("SalvageListItemType"):SetTextColor(bTextColorRed and "UI_WindowTextRed" or "UI_TextHoloBodyCyan")
      wndCurr:FindChild("SalvageListItemType"):SetText(tItem:GetItemTypeName())

      wndCurr:FindChild("SalvageListItemCantUse"):Show(bTextColorRed)
      wndCurr:FindChild("SalvageListItemIcon"):GetWindowSubclass():SetItem(tItem)
    end

    wndParent:ArrangeChildrenVert(0)
    wndParent:SetVScrollPos(nScrollPos)

    self.wndMain:SetData(itemCurr)
    self.wndMain:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, itemCurr:GetInventoryId())
    self.wndMain:Show(true)
    self.wndMain:ToFront()
  else
    self.wndMain:Show(false)
  end
end

function VikingImprovedSalvage:HelperPrereqFailed(tCurrItem)
  return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

function VikingImprovedSalvage:OnSalvageCurr()
  if self.nItemIndex == #self.arItemList then
    table.remove(self.arItemList, self.nItemIndex )
    self.nItemIndex = self.nItemIndex - 1
  else
    table.remove(self.arItemList, self.nItemIndex )
  end
  self:RedrawAll()
end

function VikingImprovedSalvage:OnCloseBtn()
  self.arItemList = {}
  self.wndMain:SetData(nil)
  self.wndMain:Show(false)
end

----------------globals----------------------------

local VikingImprovedSalvage_Singleton = VikingImprovedSalvage:new()
Apollo.RegisterAddon(VikingImprovedSalvage_Singleton)
