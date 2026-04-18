-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-----------------------------
-- VARIABLES --
-----------------------------
local ClickPart = {}
local ClickPartMT = {Part = nil, Multiplier = 0, ClickDetector = nil}
ClickPartMT.__index = ClickPartMT

local DataModule = require(ReplicatedStorage.Modules.PlayerData.Data) 
local GameCommsEnum = require(ReplicatedStorage.Modules.Enums.GameCommunicationsEnum)
local gameCommsEvent = ReplicatedStorage.Events.Remotes.GameCommunication
local GuiActionsEnum = require(ReplicatedStorage.Modules.Enums.GuiActionsEnum)
local updateGuiEvent = ReplicatedStorage.Events.Remotes.UpdateGui
local PetsConfig = require(ReplicatedStorage.Configs.Pets)
local ShopConfig = require(ReplicatedStorage.Configs.Shop)
local AchievementsManager = require(ServerScriptService.Server.Modules.Achievements)
local AchievementsConfig = require(ReplicatedStorage.Configs.Achievements)
local QuestManager = require(ServerScriptService.Server.Modules.Quest)
local QuestConfig = require(ReplicatedStorage.Configs.Quest)
local Stats = require(ReplicatedStorage.Utils.Stats)
local FormatNumber = require(ReplicatedStorage.Libs.FormatNumber.Simple)
local Manager = require(ServerScriptService.Manager)
local PlayerState = require(ReplicatedStorage.Modules.PlayerState)
local PlayerStats = require(ServerScriptService.PlayerStats)
local PrestigeShop = require(ReplicatedStorage.Configs.PrestigeShop)
local Decoder = require(ReplicatedStorage.Modules.Decoder)

local remotes = ReplicatedStorage.Events.Remotes

local cashParticle = ReplicatedStorage.Particles.Clicking.StarEmitter
local starParticle = ReplicatedStorage.Particles.Clicking.Star
local ringParticle = ReplicatedStorage.Particles.Clicking.Ring

local initialized = false
local rng = Random.new()

local autoClickConnections = {} -- map userId -> { targetPart, conn, lastClick }
local yield = {}
local target = {}
local criticalClick = {}

-- CONSTANTS --
local CLICK_PART_TAG = "ClickPart"
local CLICK_COOLDOWN = 0.1

local RED = Color3.fromRGB(255, 0, 0)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function spawnFXonPlayer(player: Player, crit: boolean, attachment: Attachment)
	local cloneParticle = cashParticle:Clone()
	local cloneParticle2 = starParticle:Clone()
	
	if crit then
		cloneParticle.Color = ColorSequence.new(RED)
		cloneParticle2.Color = ColorSequence.new(RED)
	end
	
	if PlayerState.IsStateActive(player, "GoldenCursor") then
		cloneParticle2.Color = ColorSequence.new(Color3.fromRGB(255, 191, 0))
	end
	local ringClone = ringParticle:Clone()
	cloneParticle.Parent = attachment
	cloneParticle2.Parent = attachment
	cloneParticle:Emit(10)
	cloneParticle2:Emit(1)

	task.delay(1, function()
		cloneParticle:Destroy()
		cloneParticle2:Destroy()
	end)
end

local function onClickPartClicked(player: Player, self)
	if not player then
		return warn("Player not found")
	end
	
	local part = self
	if typeof(part) == "table" then
		part = part.Part
	end
	
	local playerData = DataModule.GetData(player)
	if playerData.ClickDB then
		return
	end
	
	local threshold = part.Threshold
	
	if threshold then -- double check on server
		local totalCash = player:GetAttribute("TotalCash")
		if threshold:IsA("NumberValue") then
			if threshold.Value > totalCash then
				return
			end
		elseif threshold:IsA("StringValue") then
			if Decoder.EncodeStoredInteger(tonumber(threshold.Value)) > totalCash then
				return
			end
		end
	end
	
	local playerClickCooldown = playerData.ClickCooldown
	playerData.ClickDB = true

	local attachment = Instance.new("Attachment")
	attachment.Parent = player.Character.HumanoidRootPart
	Debris:AddItem(attachment, 1)
	
	local achievementId = AchievementsConfig.GetFirstAvailableAchievementId("Clicks", playerData)
	if achievementId then
		AchievementsManager.AddPoint(player, "Clicks", achievementId)
	end
	
	if playerData.Quests.ActiveQuest then
		local quest = playerData.Quests.ActiveQuest.Quest
		if not quest then
			warn("Could not find quest")
		end
		QuestManager.AddPoint(player, quest, 1, "Clicks")
	end
	
	PlayerStats.UpdateIntStat(player, 1, "ButtonTaps", true)
	
	local clickMultiplier = Stats.ClickMultiplier(playerData).Power
	local petClickPower = PetsConfig.GetEquippedClickPower(playerData) or 0
	local cashValue = player:FindFirstChild("CashValue")
	local clickPower = playerData.ClickPower
	
	local partMultiplier = part:GetAttribute("Multiplier") or part.Multiplier.Value or 1
	local total = ((clickPower + petClickPower) * (clickMultiplier)) * partMultiplier
	
	local crit = false
	if not yield[player.UserId] then
		yield[player.UserId] = true
		criticalClick[player.UserId] = PrestigeShop.GetUpgradeMultiplierFor("CriticalClicks", playerData)
	end
	
	target[player.UserId] += 0.1
	if target[player.UserId] >= 1 then
		target[player.UserId] = 0 
		yield[player.UserId] = false
		criticalClick[player.UserId] = PrestigeShop.GetUpgradeMultiplierFor("CriticalClicks", playerData)
	end
	
	if criticalClick[player.UserId] then
		local num = rng:NextInteger(1, 100)
		if num <= criticalClick[player.UserId] then
			total *= 20
			crit = true
		end
	end
	
	if crit then
		spawnFXonPlayer(player, true, attachment)
		updateGuiEvent:FireClient(player, GuiActionsEnum.SpawnGuiElement, {Value = total, Crit = crit})
		updateGuiEvent:FireClient(player, GuiActionsEnum.DropOrb, {Part = part, Crit = crit})
		gameCommsEvent:FireClient(player, GameCommsEnum.ToClient.ClickPartTween, {PartClicked = part, Crit = crit})
		
		Manager.AdjustCash(player, total)

		task.wait(playerClickCooldown)
		playerData.ClickDB = false
		return
	end
	
	spawnFXonPlayer(player, false, attachment)
	updateGuiEvent:FireClient(player, GuiActionsEnum.SpawnGuiElement, {Value = total})
	updateGuiEvent:FireClient(player, GuiActionsEnum.DropOrb, {Part = part})
	gameCommsEvent:FireClient(player, GameCommsEnum.ToClient.ClickPartTween, {PartClicked = part})
	
	--cashValue.Value += total
	Manager.AdjustCash(player, total)
	
	task.wait(playerClickCooldown)
	playerData.ClickDB = false
	
	return true
end

local function enableClickDetector(clickPart)
	if not clickPart:IsA("BasePart") then
		return
	end
	if not clickPart.ClickDetector.Enabled then
		clickPart.ClickDetector.Enabled = true
	end
end

local function disableClickDetector(clickPart)
	if not clickPart:IsA("BasePart") then
		return
	end
	if clickPart.ClickDetector.Enabled then
		clickPart.ClickDetector.Enabled = false
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function ClickPart.new(part: BasePart, multiplier, clickDetector: ClickDetector) 
	local self = {} -- why did I ever use oop damnit 😭
	self.Part = part
	self.Parent = self.Part.Parent
	self.ClickDetector = clickDetector
	self.BillBoardGui = self.Part:FindFirstChild("BillboardGui")
	self.Threshold = self.Part.Threshold
	self.Multiplier = multiplier
	
	if self.Parent then
		self.Sign = self.Parent:FindFirstChild("Sign")
		if self.Sign then
			local threshold = self.Threshold
			if threshold:IsA("NumberValue") then
				self.Sign.Display.Gui.Title.Text = `Req: {FormatNumber.FormatCompact(self.Threshold.Value)}`
			elseif threshold:IsA("StringValue") then
				self.Sign.Display.Gui.Title.Text = `Req: {FormatNumber.FormatCompact(tonumber(self.Threshold.Value))}`
			end
		end
	end
	
	self.Part:SetAttribute("Multiplier", self.Multiplier)
	self.Part:SetAttribute("OrigSize", self.Part.Size)
	self.BillBoardGui.TextLabel.TextColor3 = self.Part.Color
	
	self.BillBoardGui.TextLabel.Text = tostring(self.Multiplier).."x"

	self.ClickDetector.MouseClick:Connect(function(player)
		onClickPartClicked(player, self)
	end)

	return setmetatable(self, ClickPartMT)
end

function ClickPart:Init()
	local ClickParts = CollectionService:GetTagged(CLICK_PART_TAG)
	if initialized then
		return
	end
	initialized = true
	for _, part in ipairs(ClickParts) do
		ClickPart.new(part, part.Multiplier.Value, part:FindFirstChild("ClickDetector"))
	end
end

function ClickPart:GetPart(partName)
	for _, part in CollectionService:GetTagged(CLICK_PART_TAG) do
		if part.Name ~= partName then
			continue
		end
		return part
	end
end

function ClickPart:DisableClickDetector(clickPart)
	disableClickDetector(clickPart)
end

function ClickPart:EnableClickDetector(clickPart)
	enableClickDetector(clickPart)
end

function ClickPart:RemovePlayerTables(player: Player)
	if not player then
		return
	end
	yield[player.UserId] = nil
	target[player.UserId] = nil
	criticalClick[player.UserId] = nil
	local ex = autoClickConnections[player.UserId]
	if ex then
		if ex.conn and ex.conn.Connected then ex.conn:Disconnect() end
		autoClickConnections[player.UserId] = nil
	end
end

function ClickPart:AddPlayerTables(player: Player)
	if not player then
		return
	end
	yield[player.UserId] = false
	target[player.UserId] = 0
	criticalClick[player.UserId] = false
end

-----------------------------
-- HANDLERS --
-----------------------------
local AUTOCLICK_WAIT_TIME = 0.01
remotes.MobileAutoClick.OnServerEvent:Connect(function(player, enable, clickPart)
	if not player or not player.Parent then return end
	if enable then
		if not clickPart or not clickPart:IsA("BasePart") then
			return warn("not basepart?")
		end

		local data = DataModule.GetData(player)
		if not data then return end
		local clickCooldown = data.ClickCooldown or 0.2

		local existing = autoClickConnections[player.UserId]
		if existing then
			if existing.targetPart == clickPart then
				return
			end

			existing.targetPart = clickPart
			return
		end

		-- create new record & connection
		local record = {
			targetPart = clickPart,
			lastClick = 0,
			conn = nil,
		}

		record.conn = RunService.Heartbeat:Connect(function(dt)
			if not record or not record.targetPart then return end
			
			local char = player.Character
			if not char then
				-- cleanup
				if record.conn and record.conn.Connected then record.conn:Disconnect() end
				autoClickConnections[player.UserId] = nil
				return
			end
			
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end

			local tp = record.targetPart
			if not tp or not tp:IsDescendantOf(workspace) then
				if record.conn and record.conn.Connected then record.conn:Disconnect() end
				autoClickConnections[player.UserId] = nil
				pcall(function() remotes.MobileAutoClick:FireClient(player, false) end)
				return
			end

			-- player too far chekc
			if (root.Position - tp.Position).Magnitude > 25 then
				if record.conn and record.conn.Connected then record.conn:Disconnect() end
				autoClickConnections[player.UserId] = nil
				pcall(function() remotes.MobileAutoClick:FireClient(player, false) end)
				return
			end

			-- respect the player's internal click debounce (ClickDB) so we don't double-fire
			local playerData = DataModule.GetData(player)
			if playerData and playerData.ClickDB then
				return
			end

			if os.clock() - record.lastClick >= clickCooldown then
				record.lastClick = os.clock()
				local success, err = pcall(function()
					onClickPartClicked(player, tp)
				end)
				
				if not success then
					warn("autoclick failed:", err)
				end
			end
		end)

		-- store record
		autoClickConnections[player.UserId] = record

	else
		-- this should never happen, but just in case
		local existing = autoClickConnections[player.UserId]
		if existing then
			if existing.conn and existing.conn.Connected then
				existing.conn:Disconnect()
			end
			autoClickConnections[player.UserId] = nil
		end
	end
end)

-----------------------------
-- MAIN --
-----------------------------
return ClickPart
