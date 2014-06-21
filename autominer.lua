--Autominer, destroys blocks automatically
--License: WTFPL

minetest.register_craft({
	output = "mining_plus:autominer",
	recipe = {
		{ "default:steel_ingot", "default:pick_mese", "default:steel_ingot" },
		{ "default:stonebrick", "default:stonebrick", "default:stonebrick" },
		{ "default:steel_ingot", "default:chest_locked", "default:steel_ingot" },
	}
})

minetest.register_node("mining_plus:autominer", {
	description = "Autominer",
	tiles = {"mining_autominer_top.png", "mining_autominer_top.png", "mining_autominer_side.png",
		"mining_autominer_side.png", "mining_autominer_side.png", "mining_autominer_front.png"},
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
		meta:set_string("infotext", "Autominer (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("formspec", "size[8,9]"..
			"label[0,0;Autominer]"..
			"label[0.5,1.5;Nodes to break:]"..
			"list[current_name;src;1,2;1,1;]"..
			"label[2.5,2;-->]"..
			"label[4,0.5;Broken nodes:]"..
			"list[current_name;dst;4,1;2,3;]"..
			"label[4,4;Ejected:]"..
			"list[current_name;ej;5.5,4;1,1;]"..
			"list[current_player;main;0,5;8,4;]")
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Autominer (constructing)")
		meta:set_string("owner", "")
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
		inv:set_size("dst", 2*3)
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
		
		if listname == "src" then
			if stack:get_wear() == 0 then
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
			return inv:is_empty("src") and inv:is_empty("dst") and inv:is_empty("ej")
		end
		return 0
	end,
})

minetest.register_abm({
	nodenames = {"mining_plus:autominer"},
	interval = 10,
	chance = 2,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		
		if inv:is_empty("src") or not inv:is_empty("ej") then
			return
		end
		local src = inv:get_stack("src", 1)
		
		if src:get_count() < 4 or src:get_wear() ~= 0 then
			return
		end
		
		local src_name = src:get_name()
		local drops = minetest.get_node_drops(src_name)
		local count = 0
		for _, item in ipairs(drops) do
			local stack = ItemStack(item)
			local item_name = stack:get_name()
			local item_count = stack:get_count() * 4
			if not inv:room_for_item("dst", item_name.." "..item_count) then
				break
			end
			inv:add_item("dst", item_name.." "..item_count)
			count = count + 1
		end
		
		if count > 0 then
			inv:remove_item("src", src_name.." 4")
		end
	end
})