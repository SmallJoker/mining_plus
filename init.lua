--Created by Krock for the mining_plus mod
--License: WTFPL

local mod_path = minetest.get_modpath("mining_plus")

dofile(mod_path.."/tunnelbomb.lua")
dofile(mod_path.."/bridgebuilder.lua")
dofile(mod_path.."/autominer.lua")

minetest.register_node("mining_plus:breaknode", {
    description = "Breaknode",
    tiles = { "mining_breaknode.png" },
    groups = { dig_immediate = 2 },
})

minetest.register_craft({
	output = "mining_plus:breaknode",
	recipe = {
		{ "default:stick" },
		{ "default:steel_ingot" },
		{ "default:stick" },
	}
})

-- ADDITIONAL COBBLE-EATER

minetest.register_node("mining_plus:polished_cobble", {
    description = "Polished Cobble",
    tiles = { "mining_polished_cobble.png" },
    groups = { cracky = 1 },
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_craft({
	output = "mining_plus:polished_cobble",
	recipe = {
		{ "default:cobble", "default:cobble", "default:cobble" },
		{ "default:cobble", "default:cobble", "default:cobble" },
		{ "default:cobble", "default:cobble", "default:cobble" },
	}
})

minetest.register_craft({
	output = "default:cobble 8",
	recipe = {
		{ "mining_plus:polished_cobble" },
	}
})