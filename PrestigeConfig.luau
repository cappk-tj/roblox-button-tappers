-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- VARIABLES --
-----------------------------
export type PerkType = "PASSIVE" | "UPGRADE"

export type RewardType = "CashMulti" | "DiamondMulti" | "SprintSpeed" | "Luck" | "PassiveClickCooldown" | "GoldenPower"

type PrestigeRequirements = {
	Area: string,
	Prestige: number,
}

type PrestigeBenefits = {
	Diamonds: number,
	GlobalMultiplier: number,
	Tokens: number,
	Aura: string
}

export type PrestigePerk = {
	RewardType: RewardType,
	Icon: string,
	Name: string,
	Text: { string },
	Multiplier: number?,
	Amount: number?,
	Type: PerkType,
}

type PrestigePerks = {
	Perk1: PrestigePerk,
	Perk2: PrestigePerk,
	Perk3: PrestigePerk,
}

export type PrestigeType = {
	Id: string,
	Prestige: number,
	Cash: number | string,
	Text: { string },
	
	Requirements: PrestigeRequirements,
	Benefits: PrestigeBenefits,
	PrestigePerks: PrestigePerks,
}

local Altar = {}
local remotes = ReplicatedStorage.Events.Remotes
local guiActionsEnum = require(ReplicatedStorage.Modules.Enums.GuiActionsEnum)
local Decoder = require(ReplicatedStorage.Modules.Decoder)
local Template
local AchievementsHandler
local DataModule

-- CONSTANTS -- 
local DIAMOND_ICON = "rbxassetid://115325945753157"
local SPRINT_ICON = "rbxassetid://9525535512"
local CASH_ICON = "rbxassetid://80120083525360"

local LUCK_ICON = "rbxassetid://14169674580"
local PASSIVE_ICON = "rbxassetid://18212381351"
local CLICKS_ICON = "rbxassetid://9468220156"

local Config: { [string]: { PrestigeType } } = {
	-- PRESTIGE 1
	[1] = {
		Id = "Red Crystal Altar",
		Prestige = 1,
		Cash = 1_000_000_000,
		Text = {
			"Prestige 1",
			"The First Ascension.",
		},
		
		Requirements = {
			Area = "Volcano",
			Prestige = 0,
		},
		
		Benefits = {
			Diamonds = 50_000,
			GlobalMultiplier = 4,	
			Tokens = 1_500,
			ClickRate = 0.09, -- ClickCooldown in %
			Aura = "Fiery Aura"
		},
		
		PrestigePerks = {
			Perk1 = {
				RewardType = "DiamondMulti",
				Icon = DIAMOND_ICON,
				Name = "Diamond Greed",
				Text = {
					"+50% Diamonds from all sources",
					"MORE DIAMONDS!!!"
				},
				Multiplier = 0.5,
				Type = "PASSIVE"
			},
			Perk2 = {
				RewardType = "CashMulti",
				Icon = CASH_ICON,
				Name = "Cash Flow",
				Text = {
					"+100% Clicks Multiplier",
					"Because you want even more clicks..."
				},
				Multiplier = 1,
				Type = "PASSIVE"
			},
			Perk3 = {
				RewardType = "SprintSpeed",
				Icon = SPRINT_ICON,
				Name = "Speedster",
				Text = {
					"+25% Sprint Speed",
					"The fastest man alive."
				},
				Multiplier = 0.25,
				Type = "UPGRADE"
			},	
		}
	},
	-- PRESTIGE 2
	[2] = {
		Id = "Purple Crystal Altar",
		Prestige = 2,
		Cash = 600_000_000_000_000,
		Text = {
			"Prestige 2",
			"The Abyss calls out.",
		},

		Requirements = {
			Area = "The Abyss",
			Prestige = 1,
		},

		Benefits = {
			Diamonds = 350_000,
			GlobalMultiplier = 25,	
			Tokens = 3_000,
			ClickRate = 0.08, -- ClickCooldown in %
			Aura = "Abyssal Aura"
		},
		
		PrestigePerks = {
			Perk1 = {
				RewardType = "PassiveClickCooldown",
				Icon = PASSIVE_ICON,
				Name = "Fast Clicker",
				Text = {
					"25% Faster passive clicks.",
					"Gotta go fast!"
				},
				Multiplier = 0.25,
				Type = "PASSIVE"
			},
			Perk2 = {
				RewardType = "Luck",
				Icon = LUCK_ICON,
				Name = "Collector's Dream",
				Text = {
					"+25% Luck",
					"Gotta hatch em all!"
				},
				Multiplier = 0.25,
				Type = "PASSIVE"
			},
			Perk3 = {
				RewardType = "GoldenPower",
				Icon = CLICKS_ICON,
				Name = "The Power of Gold",
				Text = {
					"25% Stronger golden clicks",
					"A good choice."
				},
				Multiplier = 0.25,
				Type = "PASSIVE"
			},	
		}
	},
	-- PRESTIGE 3
	[3] = {
		Id = "Blue Crystal Altar",
		Prestige = 3,
		Cash = "20e21", -- 20Sx 
		Text = {
			"Prestige 3",
			"The cosmos bends to your will.",
		},

		Requirements = {
			Area = "Starfordge",
			Prestige = 2,
		},

		Benefits = {
			Diamonds = 1_500_000,
			GlobalMultiplier = 150,	
			Tokens = 7_500,
			ClickRate = 0.07, -- ClickCooldown in %
			Aura = "Star Aura"
		},

		PrestigePerks = {
			Perk1 = {
				RewardType = "Luck",
				Icon = LUCK_ICON,
				Name = "Lady Luck",
				Text = {
					"+50% Luck",
					"It ain't luck, Its all skill."
				},
				Multiplier = 0.5,
				Type = "PASSIVE"
			},
			Perk2 = {
				RewardType = "CashMulti",
				Icon = CASH_ICON,
				Name = "Cash LORD",
				Text = {
					"+200% Clicks Multiplier",
					"LET THE CASH FLOW IN!!!"
				},
				Multiplier = 2,
				Type = "PASSIVE"
			},
			Perk3 = {
				RewardType = "GoldenPower",
				Icon = CLICKS_ICON,
				Name = "King of Gold",
				Text = {
					"50% Stronger golden clicks",
					"A good choice."
				},
				Multiplier = 0.5,
				Type = "PASSIVE"
			},	
		}
	},
	[4] = {
		Id = "Yellow Crystal Altar",
		Prestige = 4,
		Cash = "2e39", -- 2Dd
		Text = {
			"Prestige 4",
			"King of the Sun.",
		},

		Requirements = {
			Area = "Celestial Nexus",
			Prestige = 3,
		},

		Benefits = {
			Diamonds = 10_000_000,
			GlobalMultiplier = 1250,	
			Tokens = 12_000,
			ClickRate = 0.065, -- ClickCooldown in %
			Aura = "Solar Flare Aura"
		},

		PrestigePerks = {
			Perk1 = {
				RewardType = "DiamondMulti",
				Icon = LUCK_ICON,
				Name = "Diamond LORD",
				Text = {
					"+100% Diamonds",
					"It's raining diamonds..."
				},
				Multiplier = 1,
				Type = "PASSIVE"
			},
			Perk2 = {
				RewardType = "PassiveClickCooldown",
				Icon = PASSIVE_ICON,
				Name = "Idle Click LORD",
				Text = {
					"25% Faster passive clicks.",
					"Look at all those clicks!"
				},
				Multiplier = 0.25,
				Type = "PASSIVE"
			},
			Perk3 = {
				RewardType = "GoldenPower",
				Icon = CLICKS_ICON,
				Name = "Gold LORD",
				Text = {
					"100% Stronger golden clicks",
					"INSANE Golden Clicks."
				},
				Multiplier = 1,
				Type = "PASSIVE"
			},	
		}
	},
}

Altar.Config = Config

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function AddDefaultValues(dataTable, defaultTable) -- gpt
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

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function Altar.GetPerkDescriptionFromName(perkName: string)
	for _, config in Config do
		for _, perk in config.PrestigePerks do
			if perk.Name == perkName then
				return perk.Text[1]
			end
		end
	end	
end	

function Altar.GetPrestigeTextFromPrestige(prestige: number)
	return Altar.Config[prestige].Text
end

function Altar.GetMultiplierFromPrestige(prestige: number)
	if prestige > 0 then
		return Altar.Config[prestige].Benefits.GlobalMultiplier
	end
	
	return 0
end

function Altar.GetPerksFromPerkType(rewardType: RewardType)
	local perks = {}
	
	for _, config in Altar.Config do
		for _, perk in config.PrestigePerks do
			if perk.RewardType == rewardType then
				table.insert(perks, perk)
			end
		end
	end
	
	return perks
end

function Altar.GetMultiplierFromType(rewardType: RewardType, data)
	local perks = Altar.GetPerksFromPerkType(rewardType)
	if not perks then
		return
	end
	
	local multiplier = 0
	
	for _, altar in data.Altar do
		if not altar.ChosenPerk then
			continue
		end
		
		for _, perk in perks do
			if perk.RewardType == altar.ChosenPerk.RewardType then
				multiplier += perk.Multiplier
				continue
			end
		end
	end
	
	if multiplier ~= 0 then
		return multiplier
	else
		return false
	end
	
end

function Altar.DoesPlayerHavePerk(perkType: RewardType, data)
	for _, altar in data.Altar do
		if not altar.ChosenPerk then
			continue
		end
		
		if altar.ChosenPerk.RewardType == perkType then
			return true
		end
	end
	
	return false
end

function Altar.GetConfigFromId(id: string)
	for prestige, config in Altar.Config do
		if config.Id == id then
			return config
		end
	end
end

function Altar.GetIdFromPrestige(prestige: number)
	return Altar.Config[prestige].Id
end

function Altar.ResetPlayerStats(player: Player)
	if not DataModule then
		DataModule = require(ReplicatedStorage.Modules.PlayerData.Data)
	end

	if not AchievementsHandler then
		AchievementsHandler = require(ServerScriptService.Server.Modules.Achievements)
	end

	if not Template then
		Template = require(ReplicatedStorage.PlayerData.Template)
	end
	
	local data = DataModule.GetData(player)
	if not data then
		return warn("could not get data?")
	end
	
	AchievementsHandler.ClaimAllAvailableRewards(player)
	
	-- wipe pets
	for _, uuid in data.Pets do
		local pet: PetsConfig.PetInstance = uuid
		if not pet then 
			warn(pet)
			continue
		end

		if pet.Exclusive then
			continue
		end

		if pet.Robux then
			continue
		end

		-- add check for if pet was bought with robux.

		local PetsHandler = require(ServerScriptService.Server.Modules.PetsHandler)
		PetsHandler.ForceDeletePet(player, pet.UUID)
	end
	
	-- wipe player stats.
	data.PassiveClick = 0
	data.ClickPower = 1
	data.Cash = 0
	player.CashValue.Value = 0
	player:SetAttribute("TotalCash", 0)
	
	data.ClickDB = false

	data.Areas = AddDefaultValues({}, Template.Areas)
	data.Upgrades = AddDefaultValues({}, Template.Upgrades)
	--data.Quests = AddDefaultValues({}, Template.Quests)
	
	remotes.UpdatePassiveClick:FireClient(player, false, data.PassiveClick)
	remotes.UpdateClickPower:FireClient(player, false, data.ClickPower)
	remotes.UpdateGui:FireClient(player, guiActionsEnum.UpdateClickPower, data.ClickPower)
	remotes.UpdateGui:FireClient(player, guiActionsEnum.UpdatePassiveClick, data.PassiveClick)
	remotes.Altars.ConfirmPrestige:FireClient(player, data)
	remotes.Altars.ResetUpgrades:FireClient(player, data.Upgrades)
	remotes.UpdateWalls:FireClient(player)
end

-----------------------------
-- MAIN --
-----------------------------
return Altar
