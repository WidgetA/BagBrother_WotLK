--[[
	Useful methods to implement a class for frame objects.
	All Rights Reserved
--]]


local ADDON, Addon = ...
local C = LibStub('C_Everywhere').Item
local L = LibStub('AceLocale-3.0'):GetLocale(ADDON)

local Frame = Addon.Base:NewClass('Frame', 'Frame', nil, true)
Frame.OpenSound = SOUNDKIT.IG_BACKPACK_OPEN
Frame.CloseSound = SOUNDKIT.IG_BACKPACK_CLOSE
Frame.MoneyFrame = Addon.PlayerMoney
Frame.BagGroup = Addon.BagGroup
Frame.RegisterEvents = nop

local KEYSTONE_FORMAT = '^' .. strrep('%d+:', 6) .. '%d+$'
local PET_FORMAT = '^' .. strrep('%d+:', 7) .. '%d+$'


--[[ Events ]]--

function Frame:OnShow()
	PlaySound(self.OpenSound)
	self:RegisterFrameSignal('LAYOUT_FINISHED', 'OnLayout')
	self:RegisterFrameSignal('BAG_FRAME_TOGGLED', 'Layout')
	self:RegisterFrameSignal('ELEMENT_RESIZED', 'Layout')
	self:RegisterSignal('SKINS_LOADED', 'UpdateSkin')
	self:RegisterSignal('UPDATE_ALL', 'Update')
	self:RegisterEvents()
	self:Update()
end

function Frame:OnLayout()
	Addon.Skins:Call('layout', self.bg)
end

function Frame:OnHide()
	PlaySound(self.CloseSound)
	self:UnregisterAll()

	if Addon.sets.resetPlayer then
		self.owner = nil
	end
end


--[[ UI ]]--

function Frame:Update()
	self:ClearAllPoints()
	self:SetFrameStrata(self.profile.strata)
	self:SetAlpha(self.profile.alpha)
	self:SetScale(self.profile.scale)
	self:SetPoint(self:GetPosition())
	self:UpdateSkin()
	self:Layout()
end

function Frame:UpdateSkin()
	if self.bg then
		Addon.Skins:Release(self.bg)
	end

	local bg = Addon.Skins:Acquire(self.profile.skin)
	bg:SetParent(self)
	bg:SetFrameLevel(self:GetFrameLevel())
	bg:SetPoint('BOTTOMLEFT', bg.skin.x or 0, bg.skin.y or 0)
	bg:SetPoint('TOPRIGHT', bg.skin.x1 or 0, bg.skin.y1 or 0)
	bg:EnableMouse(true)

	self.bg, self.inset = bg, bg.skin.inset or 0
	self.CloseButton:SetPoint('TOPRIGHT', (bg.skin.closeX or 0)-2, (bg.skin.closeY or 0)-2)
	self.Title:SetHighlightFontObject(bg.skin.fontH or self.FontH)
	self.Title:SetNormalFontObject(bg.skin.font or self.Font)

	local center = self.profile.color
	local border = self.profile.borderColor

	Addon.Skins:Call('load', bg)
	Addon.Skins:Call('borderColor', bg, border[1], border[2], border[3], border[4])
	Addon.Skins:Call('centerColor', bg, center[1], center[2], center[3], center[4])
end

function Frame:RecomputePosition()
	local x, y = self:GetCenter()
	if x and y then
		local scale = self:GetScale()
		local h = UIParent:GetHeight() / scale
		local w = UIParent:GetWidth() / scale
		local xPoint, yPoint

		if x > w/2 then
			x = self:GetRight() - w
			xPoint = 'RIGHT'
		else
			x = self:GetLeft()
			xPoint = 'LEFT'
		end

		if y > h/2 then
			y = self:GetTop() - h
			yPoint = 'TOP'
		else
			y = self:GetBottom()
			yPoint = 'BOTTOM'
		end

		self:SetPosition(yPoint..xPoint, x, y)
	end
end

function Frame:SetPosition(point, x, y)
	self.profile.x, self.profile.y = x, y
	self.profile.point = point
end

function Frame:GetPosition()
	return self.profile.point or 'CENTER', self.profile.x, self.profile.y
end

function Frame:GetWidget(key, ...)
	if not rawget(self, key) then
		self[key] = (self[key] or Addon[key])(self, ...)
	end
	return self[key]
end

function Frame:GetExtraButtons()
	return {}
end


--[[ Filtering ]]--

function Frame:IsShowingBag(bag)
	local bag = self:GetBagInfo(bag)
	return not bag or not bag.hidden
end

function Frame:IsShowingItem(bag, slot, info, family)
	if self.profile.sidebar and self.filter then
        local ok, shown = pcall(self.filter, self, bag, slot, family, info)
        return not ok or shown
    end
	return true
end

function Frame:SortItems()
	if not self:IsCached() then
		if self.profile.serverSort and self.ServerSort then
			self:ServerSort()
		else
			Addon.Sorting:Start(self)
		end
	end
end


--[[ Properties ]]--

function Frame:GetItemInfo(bag, slot)
	local bag = self:GetBagInfo(bag)
	local data = bag and bag.items and bag.items[slot]
	if data then
		if data:find(PET_FORMAT) then
			local id, _, quality = data:match('(%d+):(%d+):(%d+)')
			local item = {itemID = tonumber(id), quality = tonumber(quality)}
			item.name, item.iconFileID = C_PetJournal.GetPetInfoBySpeciesID(item.itemID)
			item.hyperlink = format('|c%s|Hbattlepet:%sx0|h[%s]|h|r', select(4, GetItemQualityColor(item.quality)), data, item.name)
			return item
		elseif data:find(KEYSTONE_FORMAT) then
			local item = {itemID = tonumber(data:match('(%d+)'))}
			_,_,_,_, item.iconFileID = C.GetItemInfoInstant(item.itemID)
			_, item.hyperlink, item.quality = C.GetItemInfo(item.itemID)
			item.hyperlink = item.hyperlink:gsub('item[:%d]+', data, 1)
			return item
		else
			local link, count = strsplit(';', data)
			local item = {hyperlink = 'item:' .. link, stackCount = tonumber(count)}
			item.itemID, _,_,_, item.iconFileID = C.GetItemInfoInstant(item.hyperlink)
			_, item.hyperlink, item.quality = C.GetItemInfo(item.hyperlink) 
			return item
		end
	end
	return {}
end

function Frame:GetBagInfo(bag)
	return self:GetOwner()[bag]
end

function Frame:GetBagFamily()
	return 0
end

function Frame:IsCached()
	return self:GetOwner().offline
end

function Frame:AreBagsShown()
	return self:GetProfile().showBags
end

function Frame:GetProfile()
	return self:GetOwner().profile[self.id]
end

function Frame:GetBaseProfile()
	return Addon.player.profile[self.id]
end

function Frame:SetOwner(owner)
	self.owner = owner
	self:SendFrameSignal('OWNER_CHANGED', owner)
end

function Frame:GetOwner()
	return self.owner or Addon.player
end

function Frame:GetFrameID()
	return self.id
end