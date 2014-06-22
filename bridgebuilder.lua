--Bridge Builder, builds blocks
--Created by Krock, WTFPL

minetest.register_craft({
	output = "mining_plus:bridgebuilder",
	recipe = {
		{ "default:steel_ingot", "default:pick_mese", "default:steel_ingot" },
		{ "group:wood", "default:chest_locked", "group:wood" },
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
	}
})

local function bridgebuilder_make_formspec(meta)
	meta:set_string("formspec", "size[8,6;]"..
				"label[0,0;Bridge Builder]"..
				"button_exit[2.5,0;2.5,1;inv_save;Save changes]"..
				"field[6.2,0.4;2,1;wide;Wideness;"..meta:get_int("wide").."]"..
				"label[0,1;Building materials:]"..
				"list[current_name;buildsrc;4,1;1,1;]"..
				"list[current_player;main;0,2;8,4;]")
end

minetest.register_node("mining_plus:bridgebuilder", {
	description = "Bridge Builder",
	tiles = {"mining_bridgebuilder_top.png", 
			"mining_bridgebuilder_top.png", 
			"mining_bridgebuilder_side.png",
			"mining_bridgebuilder_side.png", 
			"mining_bridgebuilder_back.png", 
			"mining_bridgebuilder_front.png"},
	paramtype2 = "facedir",
	groups = {cracky=1, level=2},
	sounds = {name="default_hard_footstep", gain=1.0},
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("infotext", "Bridge Builder (owned by "..
				meta:get_string("owner")..")")
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Bridge Builder (constructing)")
		meta:set_string("owner", "")
		meta:set_int("wide", 1)
		bridgebuilder_make_formspec(meta)
		local inv = meta:get_inventory()
		inv:set_size("buildsrc", 1)
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("buildsrc") and inv:is_empty("dug")
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		if has_mining_access(player, meta) then
			return count
		end
		return 0
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if has_mining_access(player, meta) then
			return stack:get_count()
		end
		return 0
	end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if has_mining_access(player, meta) then
			return stack:get_count()
		end
		return 0
	end,
	on_punch = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		local player_name = player:get_player_name()
		if not has_mining_access(meta, player) then
			minetest.chat_send_player(player_name, "You are not allowed to use this bridge builder.")
			return
		end
		if player:get_wielded_item():get_name() ~= "default:torch" then
			return
		end
		bridgebuilder_build(pos, node.param2, player_name)
	end,
	on_receive_fields = function(pos, formname, fields, player)
		if not fields.inv_save then return end
		local meta = minetest.get_meta(pos)
		local player_name = player:get_player_name()
		if not has_mining_access(meta, player) then
			minetest.chat_send_player(player_name, "You are not allowed to configure this bridge builder.")
			return
		end
		local wideness = tonumber(fields.wide)
		if not wideness then
			minetest.chat_send_player(player_name, "Seems like '"..fields.wide.."' isn't a number.")
			return
		end
		if wideness < 1 or wideness > 6 then
			minetest.chat_send_player(player_name, "'"..fields.wide.."' isn't a number between 1 and 6.")
			return
		end
		meta:set_int("wide", wideness)
		bridgebuilder_make_formspec(meta)
		minetest.chat_send_player(player_name, "Changes saved!")
	end,
})

function bridgebuilder_build(pos, direction, player_name)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack("buildsrc", 1)
	local node_name = stack:get_name()
	local node_count = stack:get_count()
	local wide = meta:get_int("wide") - 1
	local protected = false
	local protect_node = {x=99999, y=99999, z=99999}
	local node_dir = {x=0,y=0,z=0}
	
	if node_count == 0 then
		minetest.chat_send_player(player_name, "Building material slot is empty.")
		return
	end
	if node_name == "default:cobble" then
		minetest.chat_send_player(player_name, "C'mon, cobble is no nice building material.")
		return
	end
	minetest.sound_play("building0", {pos=pos})
	if direction == 0 or direction == 2 then --z++ , z--
		for posX = -wide, wide do
			local npos = {x=pos.x+posX,y=pos.y-1,z=pos.z}
			if minetest.is_protected(npos, player_name) then
				protected = true
				protect_node = npos
			elseif node_name ~= "" then
				if bridgebuilder_build_one(npos, node_name) then
					node_count = node_count - 1
				end
			end
			if node_count <= 0 then
				break
			end
		end
		if direction == 0 then
			node_dir.z = 1;
		else
			node_dir.z = -1;
		end
	elseif direction == 1 or direction == 3 then --x++ , x--
		for posZ = -wide, wide do
			local npos = {x=pos.x, y=pos.y-1, z=pos.z+posZ}
			if minetest.is_protected(npos, player_name) then
				protected = true
				protect_node = npos
			elseif node_name ~= "" then
				if bridgebuilder_build_one(npos, node_name) then
					node_count = node_count - 1
				end
			end
			if node_count <= 0 then
				break
			end
		end
		if direction == 1 then
			node_dir.x = 1;
		else
			node_dir.x = -1;
		end
	end
	if node_count > 0 then
		inv:set_list("buildsrc", { node_name.." "..node_count })
	else
		inv:set_list("buildsrc", {})
		minetest.chat_send_player(player_name, "Building material slot is empty.")
	end
	local movepos = {x=pos.x+node_dir.x,y=pos.y+node_dir.y,z=pos.z+node_dir.z}
	if minetest.is_protected(movepos, player_name) then
		protected = true
		protect_node = movepos
	else
		move_node(pos, movepos)
	end
	if protected then
		minetest.record_protection_violation(protect_node, player_name)
	end
end

function bridgebuilder_build_one(pos, node_name)
	local node = minetest.get_node(pos)
	local node_table = minetest.get_meta(pos):to_table()
	local node_inv = minetest.get_meta(pos):get_inventory()
	local is_empty = true
	for listname,list in pairs(node_table.inventory) do
		if not node_inv:is_empty(listname) then
			is_empty = false
			break
		end
	end
	local node_data = minetest.registered_nodes[node.name]
	if(not node_data or node.name == node_name or node.name == "ignore" or not is_empty) then
		return false
	end
	if node_data.groups.cracky == 1 then
		return false
	end
	if node.name ~= "air" and not node_data.groups.liquidtype ~= "none" then
		local drops = minetest.get_node_drops(node.name)
		local drop_pos = {x=pos.x,y=pos.y+1,z=pos.z}
		for _, item in ipairs(drops) do
			minetest.add_item(drop_pos, item)
		end
	end
	minetest.set_node(pos, {name=node_name})
	return true
end

function move_node(pos, newpos)
	local node = minetest.get_node(pos)
	if node.name == "ignore" then
		return
	end
	local newnode = minetest.get_node(newpos)
	if newnode.name == "air" or 
			newnode.name == "default:lava_flowing" or 
			newnode.name == "default:water_flowing" then
		local meta = minetest.get_meta(pos):to_table()
		minetest.set_node(newpos, node)
		minetest.get_meta(newpos):from_table(meta)
		minetest.remove_node(pos)
	end
end