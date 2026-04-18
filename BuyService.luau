-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-----------------------------
-- VARIABLES --
-----------------------------
local BuyHandler = {}
local playerDebounce = {}

local buyUpgradeEvent = ReplicatedStorage.Events.Remotes.BuyUpgrade
local GuiActionsEnum = require(ReplicatedStorage.Modules.Enums.GuiActionsEnum)
local updateGuiEvent = ReplicatedStorage.Events.Remotes.UpdateGui
local gameCommsEvent = ReplicatedStorage.Events.Remotes.GameCommunication
local DataModule = require(ReplicatedStorage.Modules.PlayerData.Data) 
local AbbreviationHandler = require(ReplicatedStorage.Modules.AbbreviationHandler)
local FormatNumber = require(ReplicatedStorage.Libs.FormatNumber.Simple)

local QuestManager = require(ServerScriptService.Server.Modules.Quest)
local PetsConfig = require(ReplicatedStorage.Configs.Pets)
local UpgradesConfig = require(ReplicatedStorage.Configs.Upgrades)
local ShopConfig = require(ReplicatedStorage.Configs.Shop)
local Stats = require(ReplicatedStorage.Utils.Stats)

local remotes = ReplicatedStorage.Events.Remotes.Shop
local updateUpgrade = remotes.UpdateUpgrade

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function checkUpgradeOrder(upgrades, upgradeId: number): boolean
	
	local sortedUpgrades = {}
	for _, upgrade in pairs(upgrades) do
		table.insert(sortedUpgrades, upgrade)
	end
	
	table.sort(sortedUpgrades, function(a, b)
		return a.Id < b.Id
	end)
	
	local canBuyUpgrade = false
	
	for i, upgrade in ipairs(sortedUpgrades) do
		if upgrade.Id ~= upgradeId then
			continue
		end
		
		if i == 1 then
			canBuyUpgrade = true
			break
		end
		
		local previousUpgrade = sortedUpgrades[i-1]
		
		if previousUpgrade.Owned then
			canBuyUpgrade = true
			break
		end
		
	end
	
	return canBuyUpgrade
end

local function setUpShopTouchParts()
	local shopParts = CollectionService:GetTagged("Shop")
	for _, part: BasePart in shopParts do
		part.Touched:Connect(function(otherPart)
			local player = Players:GetPlayerFromCharacter(otherPart.Parent)
			if not player then
				return
			end
			
			if playerDebounce[player.UserId] then
				return
			end
			playerDebounce[player.UserId] = true
			task.delay(2, function()
				playerDebounce[player.UserId] = nil
			end)

			local antiCheat = (player.Character.HumanoidRootPart.Position - part.Position).Magnitude >= 20
			if not antiCheat then
				remotes.OpenShop:FireClient(player, part.Name, part)
			end
		end)
	end
end

setUpShopTouchParts()

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function BuyHandler:Init()
	buyUpgradeEvent.OnServerInvoke = function(player: Player, action, args)
		if player ~= args.Player then
			return
		end
		local playerData = DataModule.GetData(player)
		if action == GuiActionsEnum.BuyUpgrade then
			local cashValue = player:FindFirstChild("CashValue")
			if not cashValue then
				return false, "CashValue not found??"
			end

			local upgradeConfig = UpgradesConfig.Config[args.ShopName][args.UpgradeName]
			if not upgradeConfig then
				return false, "Upgrade doesn't exist."
			end

			local upgrade = {
				Id = upgradeConfig.Id,
				Name = upgradeConfig.Name,
				Price = upgradeConfig.Price,
				Reward = upgradeConfig.Reward
			}
			
			if not upgrade then
				return false, "An unexpected error has occured while trying to get upgrade!"
			end

			local success = checkUpgradeOrder(playerData.Upgrades[args.ShopName], args.Upgrade.Id)
			
			if not success then
				return false, `You cannot skip upgrades!`
			end
			
			if upgrade.Price > cashValue.Value then
				return false, `You need {FormatNumber.FormatCompact(upgrade.Price)} cash to purchase this upgrade!`
			end
			
			if playerData.Upgrades[args.ShopName][upgrade.Name].Owned then
				return false, `You already own this upgrade!`
			end
			
			playerData.ClickPower += upgrade.Reward.ClickPower
			playerData.PassiveClick += upgrade.Reward.PassiveClick
			
			local petClickPower = 0
			local petPassiveClick = 0

			petClickPower = PetsConfig.GetEquippedClickPower(playerData)
			petPassiveClick = PetsConfig.GetEquippedPassiveClicks(playerData)
			local multiplier = Stats.ClickMultiplier(playerData)
			
			local totalClickPower = (playerData.ClickPower + petClickPower) * multiplier.Power
			local totalPassiveClick = (playerData.PassiveClick + petPassiveClick) * multiplier.Passive
				
			local passiveAbrv = AbbreviationHandler:GetAbbrv(totalPassiveClick, true)
			local powerAbrv = AbbreviationHandler:GetAbbrv(totalClickPower, false)
			
			if player == args.Player then
				playerData.Upgrades[args.ShopName][upgrade.Name].Owned = true
			end

			updateGuiEvent:FireClient(player, GuiActionsEnum.UpdatePassiveClick, {Value = passiveAbrv})
			updateGuiEvent:FireClient(player, GuiActionsEnum.UpdateClickPower, {Value = powerAbrv})
			
			cashValue.Value -= upgrade.Price
			if playerData.Tutorial then
				remotes.Parent.Tutorial.Bindable:Fire(player)
			end
			if playerData.Quests.ActiveQuest then
				QuestManager.AddPoint(player, playerData.Quests.ActiveQuest.Quest, 1, "Upgrade")
			end
			updateUpgrade:FireClient(player, args.ShopName, upgrade.Name)
			return true, "Successfully purchased upgrade!"
		end
	end
end

-----------------------------
-- MAIN --
-----------------------------
return BuyHandler
