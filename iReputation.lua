-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, iReputation = ...;
LibStub("AceEvent-3.0"):Embed(iReputation);

--local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;
local format = _G.string.format;

local FACTION_BAR_COLORS = {
	[1] = {r = 0.63, g = 0, b = 0},
	[2] = {r = 0.63, g = 0, b = 0},
	[3] = {r = 0.63, g = 0, b = 0},
	[4] = {r = 0.82, g = 0.67, b = 0},
	[5] = {r = 0.32, g = 0.67, b = 0},
	[6] = {r = 0.32, g = 0.67, b = 0},
	[7] = {r = 0.32, g = 0.67, b = 0},
	[8] = {r = 0, g = 0.75, b = 0.44},
};

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

local BONUSREP_POSSIBLE = "|TInterface\\Common\\ReputationStar:14:14:0:0:32:32:17:32:1:16|t %s";
local BONUSREP_ACTIVE = "|TInterface\\Common\\ReputationStar:14:14:0:0:32:32:1:16:1:16|t %s";
local BONUSREP_ACCOUNT = "|TInterface\\Common\\ReputationStar:14:14:0:0:32:32:17:32:17:32|t %s";

local function get_perc(earned, barMin, barMax, isFriendship)
	local perc;
	if( isFriendship ) then
		perc = _G.math.min(earned / barMax * 100, 100);
	else
		perc = _G.math.min((earned - barMin) / (barMax - barMin) * 100, 100);
	end
	
	if( perc >= 99.01 ) then
		perc = 100;
	end
	return perc;
end

local function get_label(earned, barMin, barMax, isFriendship)
	if( isFriendship ) then
		return ("%s / %s"):format(_G.BreakUpLargeNumbers(earned), _G.BreakUpLargeNumbers(barMax));
	else
		return ("%s / %s"):format(_G.BreakUpLargeNumbers(earned - barMin), _G.BreakUpLargeNumbers(barMax - barMin));
	end
end

-----------------------------
-- Setting up the LDB
-----------------------------

iReputation.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = AddonName,
	icon = "Interface\\Addons\\iReputation\\Images\\iReputation",
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
	
	local standing, barMin, barMax;
	name, standing, barMin, barMax, earned, factionID = _G.GetWatchedFactionInfo();
	
	-- check for paragon
	local isParagon = false;
	-- if( factionID and C_Reputation.IsFactionParagon(factionID) ) then
	-- 	local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(factionID);

	-- 	-- we may farm paragon reputation more than once, so we must reduce the currentValue by threshold
	-- 	if( currentValue > threshold and threshold > 0 ) then
	-- 		currentValue = currentValue - (math.floor(currentValue / threshold, 0) * threshold);
	-- 	end

	-- 	if( not tooLowLevelForParagon ) then
	-- 		barMin = 0;
	-- 		barMax = threshold;
	-- 		earned = currentValue;
	-- 		isParagon = true;
	-- 	end
	-- end
	
	-- check for cap
	local isCapped;
	if (standing == _G.MAX_REPUTATION_REACTION and not (isParagon and earned < barMax)) then
		isCapped = true;
	end
	
	-- local friendID, friendRep, _, _, _, _, _, friendThreshold, nextFriendThreshold  = _G.GetFriendshipReputation(factionID);
	-- isFriendship = friendID ~= nil;
	-- if( isFriendship ) then
	-- 	if( nextFriendThreshold ) then
	-- 		barMin, barMax, earned = friendThreshold, nextFriendThreshold, friendRep;
	-- 		isCapped = false;
	-- 	else
	-- 		isCapped = true;
	-- 	end
	-- end
	
	--self.ldb.text = name and name..": "..get_label(earned, barMin, barMax, false) or AddonName;
	self.ldb.text = not name and "" or isCapped and get_label(barMax, barMin, barMax, false) or get_label(earned, barMin, barMax, false);

	self:CheckTooltips("Main");
end

------------------------------------------
-- Custom Cell Provider - LibQTip
------------------------------------------

local cell_provider, cell_prototype = LibStub("LibQTip-1.0"):CreateCellProvider();

function cell_prototype:InitializeCell()
	local bar = self:CreateTexture(nil, "ARTWORK", self);
	self.bar = bar;
	bar:SetWidth(100);
	bar:SetHeight(14);
	bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
	bar:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1);
	
	local bg = self:CreateTexture(nil, "BACKGROUND");
	self.bg = bg;
	bg:SetWidth(102);
	bg:SetHeight(16);
	bg:SetColorTexture(0, 0, 0, 0.5);
	bg:SetPoint("TOPLEFT", self);
	
	local fs = self:CreateFontString(nil, "OVERLAY");
	self.fs = fs;
	fs:SetFontObject(_G.GameTooltipText);
	local font, size = fs:GetFont();
	fs:SetFont(font, size, "OUTLINE");
	fs:SetJustifyH("CENTER");
	fs:SetTextColor(1, 1, 1);
	
	local bonusRep = self:CreateTexture(nil, "OVERLAY");
	self.bonusRep = bonusRep;
	bonusRep:SetWidth(16);
	bonusRep:SetHeight(16);
	bonusRep:SetTexture("Interface\\Common\\ReputationStar");
	bonusRep:SetTexCoord(0.5, 1, 0.5, 1);
	bonusRep:SetPoint("CENTER", bg, "LEFT", 2, 0);

	local paragonBar = self:CreateTexture(nil, "ARTWORK", self);
	self.paragonBar = paragonBar;
	paragonBar:SetWidth(100);
	paragonBar:SetHeight(5);
	paragonBar:SetVertexColor(0.26, 0.42, 1);
	paragonBar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
	paragonBar:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 1, 1);

	local paragonBg = self:CreateTexture(nil, "BACKGROUND");
	self.paragonBg = paragonBg;
	paragonBg:SetWidth(102);
	paragonBg:SetHeight(4);
	paragonBg:SetColorTexture(0, 0, 0, 0.5);
	paragonBg:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, 0);
	
	local paragonBag = self:CreateTexture(nil, "OVERLAY");
	self.paragonBag = paragonBag;
	paragonBag:SetWidth(16);
	paragonBag:SetHeight(16);
	paragonBag:SetAtlas("ParagonReputation_Bag");
	paragonBag:SetPoint("CENTER", bg, "RIGHT", 2, 0);

	local paragonGlow = self:CreateTexture(nil, "BACKGROUND");
	self.paragonGlow = paragonGlow;
	paragonGlow:SetWidth(34);
	paragonGlow:SetHeight(34);
	paragonGlow:SetAtlas("ParagonReputation_Glow");
	paragonGlow:SetPoint("CENTER", paragonBag, "CENTER", -1, -1);
	
	self.r, self.g, self.b = 1, 1, 1;
end

function cell_prototype:SetupCell(tip, data, justification, font, r, g, b)
	local label, perc, standing, hasBonusRepGain, isParagon, isParagonGlow = unpack(data);
	local c = FACTION_BAR_COLORS[standing] or {r=1, g=1, b=1};
	
	-- toggle display bonus rep gain star
	self.bonusRep:SetShown(hasBonusRepGain);
	
	-- toggle display paragon widgets
	self.paragonBar:SetShown(isParagon);
	self.paragonBg:SetShown(isParagon);
	self.paragonBag:SetShown(isParagon);
	self.paragonGlow:SetShown(isParagon and isParagonGlow);
	
	-- basic widgets
	self.bar:SetVertexColor(c.r, c.g, c.b);
	self.bar:SetWidth(isParagon and 100 or perc);
	self.bar:SetShown(isParagon and true or perc ~= 0);

	self.fs:SetText(label);
	self.fs:ClearAllPoints();

	if( isParagon ) then
		self.fs:SetPoint("CENTER", self.bg, "CENTER", 0, -2);
	else
		self.fs:SetAllPoints(self.bg);
	end

	-- paragon widgets
	self.paragonBar:SetWidth(perc);
	
	return self.bg:GetWidth() + 14, self.bar:GetHeight() + (isParagon and self.paragonBg:GetHeight() + 2 or 0) + 2; -- add 14 to width in order to prevent Paragon image to be cut off by tooltip borders
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
local function tooltipStandingOnEnter(self, info)
	oldText = self.fs:GetText();
	self.fs:SetText(info);
end

local function tooltipStandingOnLeave(self)
	self.fs:SetText(oldText);
end

local function tooltipLineClick(self, factionIndex, button)
	-- 1     2     3           4       5       6         7          8               9         10           11      12         13       14         15               16
	-- name, desc, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus
	
	--    1     2  3  4  5  6  7  8               9  10 11 12         13 14
	local name, _, _, _, _, _, _, canToggleAtWar, _, _, _, isWatched, _, _, hasBonusRepGain, canBeLFGBonus = _G.GetFactionInfo(factionIndex);
	local isInactive = _G.IsFactionInactive(factionIndex);
	
	-- left click
	if( button == "LeftButton" ) then
		-- no modifier
		if( not _G.IsModifierKeyDown() ) then
			_G.SetWatchedFactionIndex(isWatched and 0 or factionIndex);
		else
			-- shift + ctrl + left click
			if( canToggleAtWar and _G.IsControlKeyDown() and _G.IsShiftKeyDown() ) then
				_G.FactionToggleAtWar(factionIndex);
				iReputation:CheckTooltips("Main");
			end
		end
	-- right click
	elseif( button == "RightButton" and _G.IsShiftKeyDown() ) then
		if( isInactive ) then
			_G.SetFactionActive(factionIndex);
		else
			_G.SetFactionInactive(factionIndex);
		end
	end
end

local isInChild;
function iReputation:UpdateTooltip(tip)
	tip:Clear();
	tip:SetColumnLayout(5, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT");
	
	-- check for addon updates
	if( LibStub("iLib"):IsUpdate(AddonName) ) then
		line = tip:AddHeader(" ");
		tip:SetCell(line, 1, "|cffff0000Addon Update available!|r", nil, "CENTER", 0);
	end
	--------------------------
	
	local name, desc, standing, barMin, barMax, earned, atWar, canAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus;
	local line, isFriendship;
	local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThresh, nextFriendThreshold;
	
	--local lfgBonusFactionID = _G.GetLFGBonusFactionID();
	
	for i = 1, _G.GetNumFactions() do
		-- 1     2     3           4       5       6         7          8               9         10           11      12         13       14         15               16
		-- name, desc, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus
		name, desc, standing, barMin, barMax, earned, atWar, canAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = _G.GetFactionInfo(i);
		
		if( isHeader and i > 1  and not isChild ) then
			tip:AddSeparator();
		end
		line = tip:AddLine("", "", "", "");
		
		if( isWatched ) then
			name = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14|t "..name;
		end
		
		-- reformat faction name for LFG bonus
		-- if( factionID == lfgBonusFactionID ) then
		-- 	name = (BONUSREP_ACTIVE):format(name);
		-- elseif( canBeLFGBonus ) then
		-- 	name = (BONUSREP_POSSIBLE):format(name);
		-- end
		--
		
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
			tip:SetCell(line, 3, (atWar and COLOR_ATWAR or "%s"):format(name));
		end
		
		if( not isHeader or hasRep ) then
			-- check for Paragon
			local isParagon, isParagonGlow = false, false;
			-- if( factionID and C_Reputation.IsFactionParagon(factionID) ) then
			-- 	local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(factionID);
				
			-- 	-- we may farm paragon reputation more than once, so we must reduce the currentValue by threshold
			-- 	if( currentValue > threshold and threshold > 0 ) then
			-- 		currentValue = currentValue - (math.floor(currentValue / threshold, 0) * threshold);
			-- 	end

			-- 	if( not tooLowLevelForParagon ) then
			-- 		barMin = 0;
			-- 		barMax = threshold;
			-- 		earned = currentValue;
			-- 		isParagon = true;
			-- 		isParagonGlow = hasRewardPending;
			-- 	end
			-- end
			
			-- check for cap
			local isCapped;
			if (standing == _G.MAX_REPUTATION_REACTION and not (isParagon and earned < barMax)) then
				isCapped = true;
			end
			
			-- check for friendship
			-- local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold  = _G.GetFriendshipReputation(factionID);
			-- isFriendship = friendID ~= nil;
			-- if( isFriendship ) then
			-- 	if( nextFriendThreshold ) then
			-- 		barMin, barMax, earned = friendThreshold, nextFriendThreshold, friendRep;
			-- 		isCapped = false;
			-- 	else
			-- 		barMin, barMax, earned = 0, 1, 1;
			-- 		isCapped = true;
			-- 	end
			-- end
			
			-- setup cell
			tip:SetCell(line, 4, {
				(isFriendship and friendTextLevel or _G["FACTION_STANDING_LABEL"..standing]),
				get_perc(earned, barMin, barMax, isFriendship),
				standing,
				hasBonusRepGain,
				isParagon,
				isParagonGlow
			}, cell_provider, 1, 0, 0);
			
			if( not isCapped ) then
				tip:SetCellScript(line, 4, "OnEnter", tooltipStandingOnEnter, get_label(earned, barMin, barMax, isFriendship));
				tip:SetCellScript(line, 4, "OnLeave", tooltipStandingOnLeave);
			end
			
			tip:SetLineScript(line, "OnMouseDown", tooltipLineClick, i);
			
			-- write changed reputation value
			local change = self.db.chars[CharName][tostring(factionID)].changed;
			if( change ~= 0 ) then
				tip:SetCell(line, 5, change > 0 and (COLOR_GREEN.." "):format("+".._G.AbbreviateLargeNumbers(change)) or (COLOR_RED.." "):format(_G.AbbreviateLargeNumbers(change)));
			end
		end
		
	end
end