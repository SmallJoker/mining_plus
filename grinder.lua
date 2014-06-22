--Grinder, grinds... how easy.
--License: WTFPL

local grinder_recipes = {}
-- input | output
grinder_recipes["default:stone"]		= {"default:sand",		2}
grinder_recipes["default:cobble"]		= {"default:gravel",	1}
grinder_recipes["default:gravel"]		= {"default:dirt",		1}
grinder_recipes["default:tree"]			= {"default:stick",		16}
grinder_recipes["default:jungletree"]	= {"moreblocks:jungle_stick",	16}
grinder_recipes["default:obsidian"]		= {"default:obsidian_shard",	5}
grinder_recipes["default:ice"]			= {"default:snow",		4}

if minetest.registered_items["moretrees:beech_stick"] then
	for i,v in ipairs({"beech", "apple_tree", "oak", "sequoia", "birch", "palm", "spruce", "pine", "willow", "rubber_tree", "fir"}) do
		grinder_recipes["moretrees:"..v.."_trunk"] = {"moretrees:"..v.."_stick", 16}
	end
end

if unified_inventory then
	for k,v in pairs(grinder_recipes) do
		unified_inventory.register_craft({
			type = "grinding",
			output = v[1].." "..v[2],
			items = {k},
			width = 0,
		})
	end
end

local function set_infotext(meta, mode)
	if mode == meta:get_int("state") then
		return
	end
	local owner = meta:get_string("owner")
	local text = "Grinder "
	local text2 = "[Inactive]"
	if(mode == 0) then
		text = text.."(constructing)"
	elseif(mode == 1) then
		text2 = "Inactive"
	elseif(mode == 2) then
		text2 = "Active"
	end
	if(mode ~= 0) then
		 text = text.."["..text2.."] (owned by "..owner..")"
	end
	
	meta:set_int("state", mode)
	meta:set_string("infotext", text)
	
	local formspec = ("size[8,9]"..
		"label[0,0;Grinder]"..
		"label[0.5,1;Nodes to grind:]"..
		"list[current_name;src;1,1.5;1,1;]"..
		"label[0.7,2.5;MineNinth:]]"..
		"list[current_name;fuel;1,3;1,1;]"..
		"label[2.2,2.2;\\["..text2.."\\] -->]"..
		"label[4,0.5;Milled nodes:]"..
		"list[current_name;dst;4,1;2,3;]"..
		"label[4,4;Ejected:]"..
		"list[current_name;ej;5.5,4;1,1;]"..
		"list[current_player;main;0,5;8,4;]")
	meta:set_string("formspec", formspec)
end

minetest.register_craft({
	output = "mining_plus:grinder",
	recipe = {
		{ "default:steel_ingot", "default:stone", "default:steel_ingot" },
		{ "default:diamond", "default:diamond", "default:diamond" },
		{ "default:steel_ingot", "default:stone", "default:steel_ingot" },
	}
})

minetest.register_node("mining_plus:grinder", {
	description = "Grinder",
	tiles = {"mining_autominer_top.png", "mining_autominer_top.png", "mining_autominer_side.png",
		"mining_autominer_side.png", "mining_autominer_side.png", "mining_grinder_front.png"},
	paramtype2 = "facedir",
	groups = {cracky=1, tubedevice=1, tubedevice_receiver=1},
	tube = {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("src", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:room_for_item("src", stack)
		end,
		input_inventory="dst",
		connect_sides = {left=1, right=1, back=1, top=1, bottom=1}
	},
	sounds = default.node_sound_stone_defaults(),
	after_place_node = function(pos, placer, itemstack)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name())
		set_infotext(meta, 1)
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", "")
		set_infotext(meta, 0)
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
		inv:set_size("dst", 2*3)
		inv:set_size("fuel", 1)
		inv:set_size("ej", 1)
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if player:get_player_name() == ":pipeworks" then
			return stack:get_count()
		end
		if not has_mining_access(player, meta) then
			return 0
		end
		
		if listname == "src" or listname == "fuel" then
			if(stack:get_wear() == 0) then
				return stack:get_count()
			end
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if player:get_player_name() == ":pipeworks" then
			return stack:get_count()
		end
		if has_mining_access(player, meta) then
			return stack:get_count()
		end
		return 0
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		if has_mining_access(player, meta) then
			local inv = meta:get_inventory()
			return inv:is_empty("src") and inv:is_empty("dst") and inv:is_empty("fuel") and inv:is_empty("ej")
		end
		return 0
	end,
})

minetest.register_abm({
	nodenames = {"mining_plus:grinder"},
	interval = 5,
	chance = 2,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		
		if inv:is_empty("src") or not inv:is_empty("ej") then
			set_infotext(meta, 1)
			return
		end
		local src = inv:get_stack("src", 1)
		
		if src:get_count() < 4 or src:get_wear() ~= 0 then
			set_infotext(meta, 1)
			return
		end
		
		local src_name = src:get_name()
		if not grinder_recipes[src_name] then
			set_infotext(meta, 1)
			return
		end
		
		local fuel = inv:get_stack("fuel", 1)
		if fuel:is_empty() or fuel:get_name() ~= "bitchange:mineninth" then
			set_infotext(meta, 1)
			return
		end
		
		inv:remove_item("src", src_name.." 4")
		inv:remove_item("fuel", "bitchange:mineninth 1")
		local item_str = grinder_recipes[src_name][1].." "..(grinder_recipes[src_name][2] * 4)
		if inv:room_for_item("dst", item_str) then
			inv:add_item("dst", item_str)
		else
			inv:add_item("ej", item_str)
		end
		
		set_infotext(meta, 2)
	end
})