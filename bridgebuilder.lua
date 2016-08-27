--Bridge Builder, builds blocks

minetest.register_craft({
	output = "mining_plus:bridgebuilder",
	recipe = {
		{ "default:steel_ingot", "default:pick_mese", "default:steel_ingot" },
		{ "group:wood", "default:chest_locked", "group:wood" },
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
	}
})

local function bridgebuilder_make_formspec(num)
	return		("size[8,6;]"..
				"label[0,0;Bridge Builder]"..
				"button_exit[2.5,0;2.5,1;inv_save;Save changes]"..
				"field[6.2,0.4;2,1;wide;Wideness;"..num.."]"..
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
		meta:set_string("formspec", bridgebuilder_make_formspec(1))
		local inv = meta:get_inventory()
		inv:set_size("buildsrc", 1)
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("buildsrc")
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
		if not has_mining_access(player_name, meta) then
			minetest.chat_send_player(player_name, "This bridge biulder belongs to "..
					meta:get_string("owner") .. ". You are not allowed to use it.")
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
		if not has_mining_access(player_name, meta) then
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
		meta:set_string("formspec", bridgebuilder_make_formspec(wideness))
		minetest.chat_send_player(player_name, "Changes saved!")
	end,
})

function bridgebuilder_build(pos, direction, player_name)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack("buildsrc", 1)
	local node_name = stack:get_name()
	local node_count = stack:get_count()
	local width = meta:get_int("wide") - 1
	local protected_pos = nil

	if node_count == 0 then
		minetest.chat_send_player(player_name, "Building material slot is empty.")
		return
	end

	local def = minetest.registered_nodes[node_name]
	if not def or def.after_place_node then
		minetest.chat_send_player(player_name, "Only regular nodes can be placed.")
		return
	end
	if node_name == "default:cobble" then
		minetest.chat_send_player(player_name, "C'mon, cobble is no nice building material.")
		return
	end
	minetest.sound_play("building0", {pos=pos})
	local dir = minetest.facedir_to_dir(direction)
	local building_dir = {x = dir.z, y = 0, z = dir.x}

	for num = -width, width do
		local npos = vector.add(pos, vector.multiply(building_dir, num))
		npos.y = npos.y - 1

		if minetest.is_protected(npos, player_name) then
			protected_pos = npos
		elseif node_name ~= "" then
			if bridgebuilder_build_one(npos, node_name) then
				node_count = node_count - 1
			end
		end
		if node_count <= 0 then
			break
		end
	end

	if node_count > 0 then
		inv:set_list("buildsrc", { node_name.." "..node_count })
	else
		inv:set_list("buildsrc", {})
		minetest.chat_send_player(player_name, "Building material slot is empty.")
	end
	local movepos = vector.add(pos, dir)
	if minetest.is_protected(movepos, player_name) then
		protected_pos = movepos
	else
		move_node(pos, movepos)
	end
	if protected_pos then
		minetest.record_protection_violation(protected_pos, player_name)
	end
end

function bridgebuilder_build_one(pos, node_name)
	local node = minetest.get_node(pos)
	local node_table = minetest.get_meta(pos):to_table()
	local node_inv = minetest.get_meta(pos):get_inventory()
	local is_empty = true
	for listname, list in pairs(node_table.inventory) do
		if not node_inv:is_empty(listname) then
			is_empty = false
			break
		end
	end
	local node_data = minetest.registered_nodes[node.name]
	if not node_data or node.name == node_name or not is_empty then
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
	local def = minetest.registered_nodes[newnode.name]
	if def and def.buildable_to then
		local meta = minetest.get_meta(pos):to_table()
		minetest.set_node(newpos, node)
		minetest.get_meta(newpos):from_table(meta)
		minetest.remove_node(pos)
	end
end