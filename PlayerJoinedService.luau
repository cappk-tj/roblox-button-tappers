-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local PolicyService = game:GetService("PolicyService")

local DataVersion = 16 -- 16 is official version 17 is testing server
local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData-"..tostring(DataVersion))

-----------------------------
-- VARIABLES --
-----------------------------
local PlayerJoinedService = {}
local loadedPlayers = {}

local Remotes = ReplicatedStorage.Events.Remotes

-- MODULES
local DataModule = require(ReplicatedStorage.Modules.PlayerData.Data) 
local PetsConfig = require(ReplicatedStorage.Configs.Pets)
local PetsHandler = require(ServerScriptService.Server.Modules.PetsHandler)
local ShopConfig = require(ReplicatedStorage.Configs.Shop)
local Stats = require(ReplicatedStorage.Utils.Stats)
local Template = require(ReplicatedStorage.PlayerData.Template)
local TitlesManager = require(ServerScriptService.Titles)
local GoldenCursorConfig = require(ReplicatedStorage.Configs.GoldenCursor)
local AuraHandler = require(ServerScriptService.Server.Modules.AuraHandler)
local PlayerState = require(ReplicatedStorage.Modules.PlayerState)
local Decoder = require(ReplicatedStorage.Modules.Decoder)
local PlayerStats = require(ServerScriptService.PlayerStats)
local PowerUpConfig = require(ReplicatedStorage.Configs.PowerUp)
local OfflineEarnings = require(ServerScriptService.Server.Modules.OfflineEarnings)
local AltarConfig = require(ReplicatedStorage.Configs.Altar)
local ClickPart = require(ServerScriptService.Server.Services.ClickPart)
local BadgeHandler = require(ServerScriptService.BadgeHandler)
local BadgeEnum = require(ReplicatedStorage.Modules.Enums.BadgeEnums)
local DiamondShopConfig = require(ReplicatedStorage.Configs.DiamondShop)

-- ENUMS / LIBS
local GuiActionsEnum = require(ReplicatedStorage.Modules.Enums.GuiActionsEnum)
local updateGuiEvent = ReplicatedStorage.Events.Remotes.UpdateGui
local GameCommsEnum = require(ReplicatedStorage.Modules.Enums.GameCommunicationsEnum)
local gameCommsEvent = ReplicatedStorage.Events.Remotes.GameCommunication
local AbbreviationHandler = require(ReplicatedStorage.Modules.AbbreviationHandler)
local FormatNumber = require(ReplicatedStorage.Libs.FormatNumber.Simple)
local updatePlayerRotationEvent = ReplicatedStorage.Events.Remotes.UpdatePlayerRotation
local Manager = require(ServerScriptService.Manager)

local rng = Random.new()
local playTesters = {
	1235238608, -- me
	851496794, -- tjd05
	2436355172, -- kano
	4810286831, -- dymitai
	187530797, -- tonki10
	52359604, -- swordflash
	4977184718, -- blake
	8662550629, -- zog
	4242008551, -- diso
} 
local CFNew, CFAngles, asin = CFrame.new, CFrame.Angles, math.asin

local playersMoving = {}
local passiveClicks = {}

-- CONSTANTS --
local PASSIVE_CLICK_COOLDOWN = 1

local CASH_THRESHOLDS = {
	Million     = Decoder.EncodeStoredInteger(1e6),
	Billion     = Decoder.EncodeStoredInteger(1e9),
	Trillion    = Decoder.EncodeStoredInteger(1e12),
	Quadrillion = Decoder.EncodeStoredInteger(1e15),
	Quintillion = Decoder.EncodeStoredInteger(1e18),
	Sxtillion = Decoder.EncodeStoredInteger(1e21),
	Septillion = Decoder.EncodeStoredInteger(1e24),
	Octillion = Decoder.EncodeStoredInteger(1e27),
	Nonillion = Decoder.EncodeStoredInteger(1e30),
	Decillion = Decoder.EncodeStoredInteger(1e33),
	Undecillion = Decoder.EncodeStoredInteger(1e36),
	Duodecillion = Decoder.EncodeStoredInteger(1e39),
	Tredecillion = Decoder.EncodeStoredInteger(1e42),
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- unlock parts for players that reach the click part req.
local function checkClickParts(player, totalCash)
	if totalCash < 1 then
		return
	end
	gameCommsEvent:FireClient(player, GameCommsEnum.ToClient.CheckClickParts, {TotalCash = totalCash})
end

-- earn cash passively
local function startPassiveClicks(player: Player)
	local data = DataModule.GetData(player)
	passiveClicks[player.UserId] = true
	
	
	while passiveClicks[player.UserId] do
		data = DataModule.GetData(player)
		
		if data.PassiveCD >= 1 then
			local hasPerk = AltarConfig.DoesPlayerHavePerk("PassiveClickCooldown", data)
			if hasPerk then
				data.PassiveCD = 0.75
			end
		end
		
		task.wait(data.PassiveCD)
		
		local petPassiveClick = PetsConfig.GetEquippedPassiveClicks(data)
		
		local multiplier = Stats.ClickMultiplier(data).Passive
		
		if (data.PassiveClick <= 0 and petPassiveClick <= 0) or not data.PassiveClick  then
			continue
		end
		
		local total = (data.PassiveClick + petPassiveClick) * multiplier
		
		updateGuiEvent:FireClient(player, GuiActionsEnum.SpawnGuiElement, {Value = total})
		Manager.AdjustCash(player, total)
	end
	
	warn("breaking loop")
end

local function incrementRewardTime(data)
	while true do
		data.Rewards.Time += 1
		
		task.wait(1)
	end
end

-- update player gui to show accurate click stats
local function updateClickInfo(player: Player, data, updateCash: boolean?)
	data = DataModule.GetData(player)
	if updateCash then
		local abrvValue = AbbreviationHandler:GetAbbrv(data.Cash, false)
		updateGuiEvent:FireClient(player, GuiActionsEnum.UpdateCash, {Value = abrvValue})
	end
	
	local petClickPower = 0
	local petPassiveClick = 0
	local multiplier = Stats.ClickMultiplier(data)
	
	if not updateCash then
		petClickPower = PetsConfig.GetEquippedClickPower(data)
		petPassiveClick = PetsConfig.GetEquippedPassiveClicks(data)
	end
	
	local passiveTotal = (data.PassiveClick + petPassiveClick) * multiplier.Passive
	local powerTotal = (data.ClickPower + petClickPower) * multiplier.Power
	
	local passiveAbrv = FormatNumber.FormatCompact(passiveTotal)
	local powerAbrv = FormatNumber.FormatCompact(powerTotal)
	updateGuiEvent:FireClient(player, GuiActionsEnum.UpdatePassiveClick, {Value = passiveAbrv})
	updateGuiEvent:FireClient(player, GuiActionsEnum.UpdateClickPower, {Value = powerAbrv})
end

local function AddDefaultValues(dataTable, defaultTable) -- Thank you gpt for this function that actually works. 🙏
	if not dataTable then
		dataTable = {}
	end
	-- First, add any missing default values
	for key, defaultValue in pairs(defaultTable) do
		-- Check if the key doesn't exist in the dataTable
		if dataTable[key] == nil then
			dataTable[key] = defaultValue

			-- If the value in both tables is a table, recursively add defaults for nested tables
		elseif type(dataTable[key]) == "table" and type(defaultValue) == "table" then
			AddDefaultValues(dataTable[key], defaultValue)
		end
	end

	-- Then, remove any keys in dataTable that don't exist in defaultTable
	for key in pairs(dataTable) do
		if defaultTable[key] == nil then
			dataTable[key] = nil  -- Remove the key from dataTable if it's not in defaultTable
		end
	end

	return dataTable
end

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

local function ApplyTitles(player: Player, data)
	TitlesManager.UpdatePlayerTitle(player)

	player.CharacterAdded:Connect(function()
		TitlesManager.UpdatePlayerTitle(player)
	end)
end

local function onCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	
	local data = DataModule.GetData(player)
	if not data then
		return
	end
	
	if data.Prestige > 0 then
		AuraHandler.EquipAura(player, `Prestige {data.Prestige}`)
	end
	ApplyTitles(player)
	
	local spawnLocations = ReplicatedStorage.Spawns:GetChildren()
	local spawn = spawnLocations[rng:NextInteger(1, #spawnLocations)]

	character.HumanoidRootPart.CFrame = spawn.CFrame
end

local timeSinceGoldenCursor = {}

local GoldenRemotes = Remotes.GoldenCursor

local function disableAllCursors(playerData)
	for name, cursor in playerData.GoldenCursor do
		if typeof(cursor) ~= "table" then
			continue
		end
		cursor.Enabled = false
	end
	
	playerData.GoldenCursor.OnScreen = false
end

-- im calling this function every second in a while true loop.
local function enableGoldenCursor(player: Player, data)
	warn("enabling golden cursor for player:", player.Name)
	GoldenCursorConfig.UpdatePlayerTimer(player)
	
	disableAllCursors(data)
	
	local extraChance = 0
	while player do
		task.wait(1)
		local cursor = GoldenCursorConfig.GetHighestOwnedCursorUpgrade(data)
		if not cursor then
			warn("Could not get highest upgraded cursor.")
			continue 
		end

		if data.GoldenCursor.OnScreen then
			continue 
		end
		
		if data.GoldenCursor[cursor].Enabled then
			continue
		end
		
		local timer = GoldenCursorConfig.GetTimeSinceLastGoldenTime(player)

		local chance = data.GoldenCursor[cursor].Chance 
		local powerUpMultiplier = PowerUpConfig.GetPowerUpMultiplier("Golden Cursor", data) 
		if powerUpMultiplier > 0 then
			chance += (powerUpMultiplier / 100)
		end
		
		local origChance = chance
		local randomNum = rng:NextNumber(0, 100)
		
		if timer and timer >= 60 then -- 60
			extraChance = 0.9 -- 1%
		end 

		if timer and timer >= 90 then -- 90
			extraChance = 4.9 -- 5%
		end

		if timer and timer >= 120 then -- 120
			extraChance = 9.9 -- 10%
		end
		
		if randomNum <= chance + extraChance and not data.GoldenCursor.OnScreen then
			extraChance = 0
			timer = 0
			data.GoldenCursor.OnScreen = true
			chance = origChance
			GoldenRemotes.UpdateGoldenCursor:FireClient(player, cursor, data.GoldenCursor.GoldenTime)
		end
	end
end

local function setupPlayTimeFor(player: Player)
	while player do 
		PlayerStats.UpdateIntStat(player, 1, "Playtime", true)
		task.wait(1)
	end
end

local function onceCheck(player: Player, diamond: NumberValue)
	local data = DataModule.GetData(player)
	local diamondValue = diamond.Value
	diamond:GetPropertyChangedSignal("Value"):Once(function()
		if diamondValue >= 10_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.TenThousandDiamonds)
		elseif diamondValue >= 100_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.HundredThousandDiamonds)
		elseif diamondValue >= 1_000_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.MillionDiamonds)
		elseif diamondValue >= 10_000_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.TenMillionDiamonds)
		elseif diamondValue >= 100_000_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.HundredMillionDiamonds)
		else
			return
		end
	end)
end

local function checkForOwner(player: Player)
	if player.UserId == 1235238608 then
		for _, plr in Players:GetPlayers() do
			BadgeHandler.AwardBadge(plr, BadgeEnum.MetOwner)
		end
	else
		for _, plr in Players:GetPlayers() do
			if plr.UserId == 1235238608 then
				BadgeHandler.AwardBadge(player, BadgeEnum.MetOwner)
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	if loadedPlayers[player.UserId] then
		return
	end
	loadedPlayers[player.UserId] = true
	
	warn("onPlayerAdded()")
	--local i = table.find(playTesters, player.UserId)
	
	--if not i and player.UserId > 1 then
	--	player:Kick("Game is only open to testers. (ASK CAPPK FOR TESTER)")
	--end
	local key = player.UserId
	
	local playerDataTable = Template.DeepCopy()
	DataModule.AddPlayer(player, playerDataTable)
	ClickPart:AddPlayerTables(player)
	PlayerState.AddPlayer(player)
	local playerData = DataModule.GetData(player)
	
	player:SetAttribute("TotalCash", 0)
	player:SetAttribute("Loading", true)
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = player
	
	local prestigeTokens = Instance.new("NumberValue")
	prestigeTokens.Name = "PrestigeTokens"
	prestigeTokens.Value = 0
	prestigeTokens.Parent = player
	
	local cashValue = Instance.new("NumberValue")
	cashValue.Name = "CashValue"
	cashValue.Value = 0
	cashValue.Parent = player
	
	local cash = Instance.new("StringValue")
	cash.Name = "💸Cash"
	cash.Value = "0"
	cash.Parent = leaderstats
	
	local diamond = Instance.new("IntValue")
	diamond.Name = "💎Diamonds"
	diamond.Value = 0
	diamond.Parent = leaderstats
	
	local prestige = Instance.new("IntValue")
	prestige.Name = "✨Prestige"
	prestige.Value = 0
	prestige.Parent = leaderstats
	
	task.defer(startPassiveClicks, player)
	
	local success, data
	local count = 0
	local previousValue -- declare it here but initialize later

	-- attempt to load player data
	repeat
		if player.UserId <= 1 then
			break
		end
		success, data = pcall(function()
			return PlayerDataStore:GetAsync(key)
		end)
		count += 1
		if not success then
			warn("Could not get player data, trying again... attempt:", count)
			task.wait(5 * count)
		end
	until success or count >= 3

	-- handle failed data retrieval
	if not success then
		warn("Failed to get data for:", player.Name, "Error:", data)
	elseif success and not data then
		warn("Failed to find data for:", player.Name, "Possibly their first time playing.")
	end

	-- set player data attributes
	if data then
		print("Successfully got", player.Name, "'s Data!")
		local abrvValue = AbbreviationHandler:GetAbbrv(data.Cash, false)

		player:SetAttribute("TotalCash", Decoder.DecodeStoredInteger(data.TotalCash))
		checkClickParts(player, player:GetAttribute("TotalCash"))
		cash.Value = abrvValue
		cashValue.Value = data.Cash
		diamond.Value = data.Diamonds
		prestige.Value = data.Prestige
		prestigeTokens.Value = data.PrestigeTokens or 0
		
		-- set playerData stuff, this cannot be optimal 🥀
		playerData.PrestigeTokens = data.PrestigeTokens or 0
		playerData.Tutorial = data.Tutorial or true
		playerData.Prestige = data.Prestige or 0

		playerData.PassiveClick = data.PassiveClick or 0
		playerData.ClickPower = if data.ClickPower > 0 then data.ClickPower else 1
		playerData.ClickCooldown = data.ClickCooldown or 0.1
		playerData.LastPlayed = data.LastPlayed or false
		playerData.PassiveCD = 1
		
		playerData.Statistics = AddDefaultValues(data.Statistics or {}, Template.Statistics)
		playerData.DiamondShop = AddDefaultValues(data.DiamondShop or {}, Template.DiamondShop)
		playerData.PrestigeShop = AddDefaultValues(data.PrestigeShop or {}, Template.PrestigeShop)
		
		playerData.Badges = AddDefaultValues(data.Badges or {}, Template.Badges)
		playerData.Settings = AddDefaultValues(data.Settings or {}, Template.Settings)
		playerData.Upgrades = AddDefaultValues(data.Upgrades or {}, Template.Upgrades) -- addDefaultValues adds any missing values inside the data.Upgrades (if any new upgrades were added after release)
		playerData.Pets = data.Pets or {}
		playerData.PetRainbow = data.PetRainbow or {}
		playerData.Achievements = AddDefaultValues(data.Achievements or {}, Template.Achievements)
		playerData.Areas = AddDefaultValues(data.Areas or {}, Template.Areas)
		playerData.Gamepasses = AddDefaultValues(data.Gamepasses or {}, Template.Gamepasses)
		playerData.PowerUps = AddDefaultValues(data.PowerUps or {}, Template.PowerUps)
		playerData.Boosts = AddDefaultValues(data.Boosts or {}, Template.Boosts)
		playerData.WheelSpin = data.WheelSpin or 0
		playerData.GoldenCursor = AddDefaultValues(data.GoldenCursor or {}, Template.GoldenCursor)
		playerData.PetIndex = AddDefaultValues(data.PetIndex or {}, Template.PetIndex)
		playerData.Codes = AddDefaultValues(data.Codes or {}, Template.Codes) -- TESTING RIGHT NOW
		playerData.Rewards = AddDefaultValues(data.Rewards or {}, Template.Rewards)
		playerData.Altar = AddDefaultValues(data.Altar or {}, Template.Altar)
		playerData.Group = AddDefaultValues(data.Group or {}, Template.Group)
		playerData.Quests = AddDefaultValues(data.Quests or {}, Template.Quests)
		playerData.GoldenCursor = AddDefaultValues(data.GoldenCursor or {}, Template.GoldenCursor)
		print(playerData)
	end
	
	BadgeHandler.AwardBadge(player, BadgeEnum.Welcome)
	playerData.Statistics.PrestigeTokens = playerData.PrestigeTokens
	task.spawn(enableGoldenCursor, player, playerData)
	
	task.spawn(function()
		local success, policyInfo = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)	
		end) 

		if success then
			playerData.PolicyInfo = policyInfo
			Remotes.Parent.Functions.UpdatePolicyInfo:FireClient(player, policyInfo)
			warn("PolicyInfo Success.")
		end
	end)
	
	playerData.Player = player
	if player.Name == "CaptainKing_15" then
		if not player.PlayerGui:FindFirstChild("AdminGui") then
			ReplicatedStorage.Admin.Assets.AdminGui:Clone().Parent = player.PlayerGui
		end
	end
	
	-- spawn any yielding functions here.
	task.spawn(incrementRewardTime, playerData)
	
	-- initialize previousValue AFTER loading data
	previousValue = cashValue.Value
	DataModule.DataLoaded:Fire(player, playerData)
	-- NOW we connect the property changed signal so it dont bug out!!1111
	local clickEventDB = 0
	cashValue:GetPropertyChangedSignal("Value"):Connect(function()
		if cashValue.Value == previousValue then
			return
		end
		
		-- badge check.... bruh
		local encodedValue = Decoder.EncodeStoredInteger(cashValue.Value)
		
		if encodedValue >= CASH_THRESHOLDS.Million and encodedValue < CASH_THRESHOLDS.Billion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Million)

		elseif encodedValue >= CASH_THRESHOLDS.Billion and encodedValue < CASH_THRESHOLDS.Trillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Billion)

		elseif encodedValue >= CASH_THRESHOLDS.Trillion and encodedValue < CASH_THRESHOLDS.Quadrillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Trillion)

		elseif encodedValue >= CASH_THRESHOLDS.Quadrillion and encodedValue < CASH_THRESHOLDS.Quintillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Quadrillion)

		elseif encodedValue >= CASH_THRESHOLDS.Quintillion and encodedValue < CASH_THRESHOLDS.Sxtillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Quintillion)
			
		elseif encodedValue >= CASH_THRESHOLDS.Sxtillion and encodedValue < CASH_THRESHOLDS.Septillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Sxtillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Septillion and encodedValue < CASH_THRESHOLDS.Octillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Septillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Octillion and encodedValue < CASH_THRESHOLDS.Nonillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Octillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Nonillion and encodedValue < CASH_THRESHOLDS.Decillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Nonillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Decillion and encodedValue < CASH_THRESHOLDS.Undecillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Decillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Undecillion and encodedValue < CASH_THRESHOLDS.Duodecillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Undecillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Duodecillion and encodedValue < CASH_THRESHOLDS.Tredecillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Duodecillion)
		
		elseif encodedValue >= CASH_THRESHOLDS.Tredecillion then
			BadgeHandler.AwardBadge(player, BadgeEnum.Tredecillion)
			
		end

		local cashEarned = cashValue.Value - previousValue
		local totalCash = player:GetAttribute("TotalCash") or 0
		
		if cashEarned > 0 then
			player:SetAttribute("TotalCash", totalCash + cashEarned)
			PlayerStats.UpdateIntStat(player, cashEarned, "TotalCash")
		end
		
		Remotes.UpdateClicks:FireClient(player)

		previousValue = cashValue.Value
		playerData.Cash = cashValue.Value
		
		local abrvValue = AbbreviationHandler:GetAbbrv(cashValue.Value)
		cash.Value = abrvValue
		updateGuiEvent:FireClient(player, GuiActionsEnum.UpdateCash, {Value = abrvValue, OrigValue = cashValue.Value})
		if clickEventDB <= 5 then
			clickEventDB += 1
			return
		else
			clickEventDB = 0
			checkClickParts(player, player:GetAttribute("TotalCash"))
		end
	end)
	
	diamond:GetPropertyChangedSignal("Value"):Connect(function()
		local diamondValue = diamond.Value
		if diamondValue < 0 then
			diamond.Value = 0
		end
		if diamondValue >= 10_000 and diamondValue <= 99_999 then
			BadgeHandler.AwardBadge(player, BadgeEnum.TenThousandDiamonds)
		elseif diamondValue >= 100_000 and diamondValue <= 999_999 then
			BadgeHandler.AwardBadge(player, BadgeEnum.HundredThousandDiamonds)
		elseif diamondValue >= 1_000_000 and diamondValue <= 9_999_999 then
			BadgeHandler.AwardBadge(player, BadgeEnum.MillionDiamonds)
		elseif diamondValue >= 10_000_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.TenMillionDiamonds)
		elseif diamondValue >= 100_000_000 then
			BadgeHandler.AwardBadge(player, BadgeEnum.HundredMillionDiamonds)
		else
			return
		end
	end)
	
	prestigeTokens:GetPropertyChangedSignal("Value"):Connect(function()
		local value = prestigeTokens.Value
		Remotes.PlayerStats.UpdateIntStat:FireClient(player, "PrestigeTokens", value)
	end)
	
	onceCheck(player, diamond)
	checkForOwner(player)
	local remove = Manager.SetupValues(player)
	
	DataModule.GamepassesLoaded.Event:Connect(function(playerWhoFired, action)
		if player ~= playerWhoFired then
			return
		end
		
		if action == "UpdateClicks" then
			updateClickInfo(player, playerData)
		end
		if playerData.Prestige > 0 then
			Remotes.Altars.UnlockAbyss:FireClient(player, workspace.ButtonClickerGame.Abyss.AbyssDoor)
		end
		
		if playerData.Tutorial == true then
			Remotes.Tutorial.StartTutorial:FireClient(player)
		else
			Remotes.Tutorial.RemoveTutorial:FireClient(player)
		end
		
		remove()
		ApplyTitles(player, playerData)
		player:SetAttribute("Loading", nil) 
		player.CharacterAdded:Connect(onCharacterAdded)
		Remotes.Pets.UpdateStorage:FireClient(player)
		Remotes.UpdateArea:FireClient(player)
		Remotes.UpdateWalls:FireClient(player, true)
		Remotes.Altars.UpdateAltars:FireClient(player)
		Remotes.SetupWalls:FireClient(player)
		Remotes.PlayerStats.UpdateIntStat:FireClient(player, "PrestigeTokens", playerData.PrestigeTokens)
		Remotes.Parent.Parent.ShowSkipButton:FireClient(player)
		Remotes.UpdateDiamonds:FireClient(player)
		Remotes.PrestigeShop.UpdatePrestigeTokens:FireClient(player, prestigeTokens.Value)
		Remotes.ClientLoaded:FireClient(player)
		Remotes.UpdateSetting:FireClient(player, "Music", playerData.Settings.Music)
		if playerData.Prestige > 0 then
			AuraHandler.EquipAura(player, `Prestige {playerData.Prestige}`)
			Remotes.Abyss.AbyssDoor:FireClient(player, "OpenDoor")
		end
		
		if cashValue.Value > 0 then
			playerData.Cash = cashValue.Value
		end
		
		-- calculate offline cash --
		local previousTick = playerData.LastPlayed
		if previousTick then
			local passiveClick = playerData.PassiveClick or 0
			local petPassiveClick = PetsConfig.GetEquippedPassiveClicks(playerData) or 0

			local total = (passiveClick + petPassiveClick) * Stats.ClickMultiplier(playerData).Passive

			OfflineEarnings.Calculate(player, previousTick, total, playerData)
		end
		
		task.delay(5, function()
			playerData.LoadedData = true
			Remotes.LoadedData:FireClient(player)
		end)
		
		task.delay(0, function()
			while not player.Character do
				task.wait(1)
			end

			local petsGiven = {}

			if not playerData.Pets then
				updateClickInfo(player, data, true)
				return
			end

			for uuid, pet in playerData.Pets do
				if petsGiven[pet] then
					continue
				end
				PetsHandler.GivePet(player, pet)
				petsGiven[pet] = true
				if pet.isEquipped then
					PetsHandler.EquipPet(player, uuid, true)
				end
			end

			task.wait(1)
			updateClickInfo(player, data, true)
		end)
		
		task.spawn(PlayerStats.UpdateStatInfo, player)
		task.spawn(setupPlayTimeFor, player)
	end)
end

-- handle saving player data when they leave game
local function onPlayerRemoved(player: Player)
	-- REMOVE ALL TABLES THAT REFERENCE THE PLAYER IN DIFFERENT SCRIPTS. so we dont get no memory leks... 🗣️
	GoldenCursorConfig.RemovePlayerTimer(player)
	PlayerState.RemovePlayer(player)
	PlayerStats.RemovePlayerFromTable(player)
	ClickPart:RemovePlayerTables(player)
	
	loadedPlayers[player.UserId] = nil
	passiveClicks[player.UserId] = nil
	
	if player.UserId <= 1 then
		return print("Testing in studio. Will not save data")
	end
	local key = player.UserId
	local playerData = DataModule.GetData(player)
	
	local data = {
		--Stats & Attributes
		Cash = player.CashValue and player.CashValue.Value or 0,
		Diamonds = player.leaderstats and player.leaderstats["💎Diamonds"].Value or 0,
		Prestige = player.leaderstats and player.leaderstats["✨Prestige"].Value or 0,
		TotalCash = Decoder.EncodeStoredInteger(player:GetAttribute("TotalCash")),
		PrestigeTokens = player and player.PrestigeTokens.Value or 0,
		
		-- playerData
		PassiveClick = playerData.PassiveClick or 0,
		ClickPower = playerData.ClickPower or 1,
		ClickCooldown = playerData.ClickCooldown,
		PassiveCD = playerData.PassiveCD,
		
		Tutorial = playerData.Tutorial or 1,
		Statistics = if playerData.Statistics then playerData.Statistics else {},
		
		LastPlayed = os.time(),
		Badges = if playerData.Badges then playerData.Badges else {},
		Settings = if playerData.Settings then playerData.Settings else {},
		Upgrades = if playerData.Upgrades then playerData.Upgrades else {},
		Pets = playerData.Pets or {},
		PetRainbow = playerData.PetRainbow,
		Achievements = if playerData.Achievements then playerData.Achievements else {},
		PetIndex = if playerData.PetIndex then playerData.PetIndex else {},
		Areas = if playerData.Areas then playerData.Areas else {},
		Gamepasses = if playerData.Gamepasses then playerData.Gamepasses else {},
		PowerUps = if playerData.PowerUps then playerData.PowerUps else {},
		Boosts = if playerData.Boosts then playerData.Boosts else {},
		WheelSpin = playerData.WheelSpin,
		Codes = if playerData.Codes then playerData.Codes else {},
		Rewards = if playerData.Rewards then playerData.Rewards else {},
		Altar = if playerData.Altar then playerData.Altar else {},
		DiamondShop = if playerData.DiamondShop then playerData.DiamondShop else {},
		PrestigeShop = if playerData.PrestigeShop then playerData.PrestigeShop else {},
		Group = if playerData.Group then playerData.Group else {},
		Quests = if playerData.Quests then playerData.Quests else {},
		GoldenCursor = if playerData.GoldenCursor then playerData.GoldenCursor else {},
	}
	
	local success, err
	local count = 0
	
	repeat
		success, err = pcall(function()
			return PlayerDataStore:SetAsync(key, data)
		end)
		count += 1
		if not success then
			warn("Could not save player data, trying again... attempt:", count)
			task.wait(5 * count)
		end
	until success or count >= 3
	
	if success then
		print("Successfully saved", player.Name, "'s Data! \n", data)
	end
end

local function saveAllPlayerData()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerRemoved, player)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS / HANDLERS --
-----------------------------
function PlayerJoinedService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoved)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

Remotes.UpdateClicks.OnServerEvent:Connect(function(player: Player)
	updateClickInfo(player)
end)

-- Dont need this
--Remotes.Parent.Bindables.UpdatePassiveCD.Event:Connect(function(player: Player)
--	warn(`got event for: {player.Name}, {passiveClicks[player.UserId]}`)
--	if not player then
--		return warn("player not found")
--	end
	
--	passiveClicks[player.UserId] = nil
--	startPassiveClicks(player)
--end)

GoldenRemotes.UpdateGoldenCursor.OnServerEvent:Connect(function(player, cursor: string, clicked: boolean)
	local data = DataModule.GetData(player)
	data.GoldenCursor.OnScreen = false
	
	if clicked then
		PlayerState.SetState(player, "GoldenCursor", true)
		data.GoldenCursor[cursor].Enabled = true
		updateClickInfo(player, data)
		
		task.delay(data.GoldenCursor.GoldenTime, function()
			PlayerState.SetState(player, "GoldenCursor", false)
			data.GoldenCursor[cursor].Enabled = false
			GoldenCursorConfig.UpdatePlayerTimer(player)
			updateClickInfo(player, data)
		end)
	end
end)

Remotes.Tutorial.UpdateTutorial.OnServerEvent:Connect(function(player: Player, bool: boolean)
	local data = DataModule.GetData(player)
	if not data then
		return
	end
	
	data.Tutorial = bool
end)

-----------------------------
-- MAIN --
-----------------------------
game:BindToClose(function()
	saveAllPlayerData()
end)

return PlayerJoinedService
