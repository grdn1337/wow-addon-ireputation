-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, iReputation = ...;
LibStub("AceEvent-3.0"):Embed(iReputation);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;
local format = _G.string.format;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, iReputation);

------------------------------------------
-- Variables, functions and colors
------------------------------------------

local CharName = _G.GetUnitName("player", false); -- The charname doesn't change during a session. To prevent calling the function more than once, we simply store the name.

local COLOR_GOLD = "|cfffed100%s|r";
local COLOR_RED  = "|cffff0000%s|r";
local COLOR_GREEN= "|cff00ff00%s|r";
local COLOR_ATWAR= "|TInterface\\PVPFrame\\Icon-Combat:14:14|t |cffff0000%s|r";

-----------------------------
-- Setting up the LDB
-----------------------------

iReputation.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = AddonName,
});

iReputation.ldb.OnEnter = function(anchor)
	if( iReputation:IsTooltip("Main") ) then
		return;
	end
	iReputation:HideAllTooltips();
	
	local tip = iReputation:GetTooltip("Main", "UpdateTooltip");
	tip:SmartAnchorTo(anchor);
	tip:SetAutoHideDelay(0.25, anchor);
	tip:Show();
end

iReputation.ldb.OnLeave = function() end -- some display addons refuse to display brokers when this is not defined

----------------------
-- Initializing
----------------------

function iReputation:Boot()
	self.db = LibStub("AceDB-3.0"):New("iReputationDB", {realm={today="",chars={}}}, true).realm;
	_G["DDB"]=self.db;
	
	if( not self.db.chars[CharName] ) then
		self.db.chars[CharName] = {};
	end
	
	local c = self.db.chars[CharName];
	local today = date("%y-%m-%d");
	
	if( today ~= self.db.today ) then
		self.db.today = today;
		
		for k, v in pairs(self.db.chars) do
			for k2, v2 in pairs(v) do
				v2.changed = 0;
			end
		end
	end
	
	self:UpdateFactions();
	self:RegisterEvent("UPDATE_FACTION", "UpdateFactions");
end
iReputation:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

function iReputation:UpdateFactions()
	local _, name, earned, isHeader, hasRep, factionID, facStr;
	
	for i = 1, _G.GetNumFactions() do
		name, _, _, _, _, earned, _, _, isHeader, _, hasRep, _, _, factionID = _G.GetFactionInfo(i);
		facStr = tostring(factionID);
		
		if( not isHeader or hasRep ) then
			if( not self.db.chars[CharName][facStr] ) then
				self.db.chars[CharName][facStr] = {earned = earned, changed = 0};
			else			
				self.db.chars[CharName][facStr].changed = self.db.chars[CharName][facStr].changed + (earned - self.db.chars[CharName][facStr].earned);
				self.db.chars[CharName][facStr].earned = earned;
			end
		end
	end

	self:CheckTooltips("Main");
end

------------------------------------------
-- Custom Cell Provider - LibQTip
------------------------------------------

local cell_provider, cell_prototype = LibStub("LibQTip-1.0"):CreateCellProvider();

function cell_prototype:InitializeCell()
	local bar = self:CreateTexture(nil, "OVERLAY", self);
	self.bar = bar;
	bar:SetWidth(100);
	bar:SetHeight(14);
	bar:SetPoint("LEFT", self, "LEFT", 1, 0);
	
	local bg = self:CreateTexture(nil, "BACKGROUND");
	self.bg = bg;
	bg:SetWidth(102);
	bg:SetHeight(16);
	bg:SetTexture(0, 0, 0, 0.5);
	bg:SetPoint("LEFT", self);
	
	local fs = self:CreateFontString(nil, "OVERLAY");
	self.fs = fs;
	fs:SetAllPoints(self);
	fs:SetFontObject(_G.GameTooltipText);
	local font, size = fs:GetFont();
	fs:SetFont(font, size - 1, "OUTLINE");
	self.r, self.g, self.b = 1, 1, 1;
end

function cell_prototype:SetupCell(tip, data, justification, font, r, g, b)
	local bar = self.bar;
	local fs = self.fs;
	local label, perc, standing = unpack(data);
	local c = _G.FACTION_BAR_COLORS[standing];
	
	bar:SetVertexColor(c.r, c.g, c.b);
	bar:SetWidth(perc);
	bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
	bar:Show();
	
	fs:SetText(label);
	fs:SetFontObject(font or tooltip:GetFont());
	fs:SetJustifyH("CENTER");
	fs:SetTextColor(1, 1, 1);
	fs:Show();
	
	return bar:GetWidth() + 2, bar:GetHeight() + 2;
end

function cell_prototype:ReleaseCell()
	self.r, self.g, self.b = 1, 1, 1;
end

function cell_prototype:getContentHeight()
	return self.bar:GetHeight() + 2;
end

------------------------------------------
-- UpdateTooltip
------------------------------------------

local function tooltipCollapseClick(_, info, button)
	if( not _G.IsModifierKeyDown() and button == "LeftButton" ) then
		if( info[2] ) then
			_G.ExpandFactionHeader(info[1]);
		else
			_G.CollapseFactionHeader(info[1]);
		end
	end
end

local oldText;
local function tooltipOnEnter(self, info)
	oldText = self.fs:GetText();
	self.fs:SetText(info);
end

local function tooltipOnLeave(self)
	self.fs:SetText(oldText);
end

local function get_perc(earned, barMin, barMax, isFriendship)
	if( isFriendship ) then
		return _G.math.min(earned / barMax * 100 ,100);
	else
		return _G.math.min((earned - barMin) / (barMax - barMin) * 100, 100);
	end
end

local function get_label(earned, barMin, barMax, isFriendship)
	if( isFriendship ) then
		return ("%d / %d"):format(earned, barMax);
	else
		return ("%d / %d"):format((earned - barMin), (barMax - barMin));
	end
end

local isInChild;
function iReputation:UpdateTooltip(tip)
	tip:Clear();
	tip:SetColumnLayout(5, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT");
	
	local name, desc, standing, barMin, barMax, earned, atWar, canAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID;
	local line, isFriendship;
	local friendID, friendRep, friendMaxRep, friendText, friendTexture, friendTextLevel, friendThresh;
	
	for i = 1, _G.GetNumFactions() do
		name, desc, standing, barMin, barMax, earned, atWar, canAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = _G.GetFactionInfo(i);
		
		if( isHeader and i > 1  and not isChild ) then
			tip:AddSeparator();
		end
		line = tip:AddLine("", "", "", "");
		
		if( isWatched ) then
			name = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14|t "..name;
		end
		
		if( isHeader ) then
			isInChild = isChild;		
			
			if( isChild ) then
				tip:SetCell(line, 2, "|TInterface\\Buttons\\UI-"..(isCollapsed and "Plus" or "Minus").."Button-Up:14:14|t");
				tip:SetCell(line, 3, (atWar and COLOR_ATWAR or COLOR_GOLD):format(name));
				tip:SetCellScript(line, 2, "OnMouseDown", tooltipCollapseClick, {i, isCollapsed});
			else
				tip:SetCell(line, 1, "|TInterface\\Buttons\\UI-"..(isCollapsed and "Plus" or "Minus").."Button-Up:14:14|t");
				tip:SetCell(line, 2, (atWar and COLOR_ATWAR or COLOR_GOLD):format(name), nil, "LEFT", 2);
				tip:SetCellScript(line, 1, "OnMouseDown", tooltipCollapseClick, {i, isCollapsed});
			end
		else
			tip:SetCell(line, 3, (atWar and COLOR_ATWAR or "%s"):format(name), nil, nil, nil, nil, nil, nil, 150);
		end
		
		if( not isHeader or hasRep ) then
			friendID, friendRep, friendMaxRep, friendText, friendTexture, friendTextLevel, friendThresh = _G.GetFriendshipReputationByID(factionID);
			isFriendship = friendID ~= nil;
			if( isFriendship ) then
				barMax = min( friendMaxRep - friendThresh, 8400);
				earned = friendRep - friendThresh;
			end
			
			tip:SetCell(line, 4, {
				(isFriendship and friendTextLevel or _G["FACTION_STANDING_LABEL"..standing]),
				get_perc(earned, barMin, barMax, isFriendship),
				standing
			}, cell_provider, 1, 0, 0);
			tip:SetCellScript(line, 4, "OnEnter", tooltipOnEnter, get_label(earned, barMin, barMax, isFriendship));
			tip:SetCellScript(line, 4, "OnLeave", tooltipOnLeave);
			
			local change = self.db.chars[CharName][tostring(factionID)].changed;
			if( change ~= 0 ) then
				tip:SetCell(line, 5, change > 0 and (COLOR_GREEN):format("+".._G.AbbreviateLargeNumbers(change)) or (COLOR_RED):format("-".._G.AbbreviateLargeNumbers(change)));
			end
		end
	end
end