--Mining Bomb, destroys blocks in a range of 3x3x8

minetest.register_craft({
	output = "mining_plus:tunnelbomb",
	recipe = {
		{ "group:wood", "default:obsidian_shard", "group:wood" },
		{ "group:stick", "default:steel_ingot", "group:stick" },
		{ "group:wood", "default:coal_lump", "group:wood" },
	}
})


minetest.register_node("mining_plus:tunnelbomb", {
	description = "Tunnel Bomb",
	tiles = {"mining_tunnelbomb_top.png", "mining_tunnelbomb_top.png", "mining_tunnelbomb_side.png",
		"mining_tunnelbomb_side.png", "mining_tunnelbomb_back.png", "mining_tunnelbomb_front.png"},
	paramtype2 = "facedir",
	groups = {cracky=1},
	sounds = default.node_sound_stone_defaults(),
	on_punch = function(pos, node, player)
		if tunnelbomb_drops ~= nil then
			return
		end
		local player_name = player:get_player_name()
		if minetest.is_protected(pos, player_name) then
			return
		end
		if player:get_wielded_item():get_name() == "default:torch" then
			minetest.sound_play("exploding0", {
				pos=pos,
				max_hear_distance = 8,
				gain = 0.5,
			})
			minetest.remove_node(pos)
			local nearto = minetest.get_objects_inside_radius(pos, 3)
			for _, obj in pairs(nearto) do
				if obj:is_player() then
					obj:set_hp(obj:get_hp() - 4)
				end
			end

			if node.param2 > 3 then
				minetest.chat_send_player(player_name, "Too bad, now you've lost this tunnel bomb.")
				return
			end

			local vec = vector.new
			local pmin, pmax
			if node.param2 == 0 then --z++
				pmin = vec(-1, 0, 1)
				pmax = vec( 1, 2, 6)
			elseif node.param2 == 1 then --x++
				pmin = vec(1, 0, -1)
				pmax = vec(6, 2,  1)
			elseif node.param2 == 2 then --z--
				pmin = vec(-1, 0, -6)
				pmax = vec( 1, 2, -1)
			elseif node.param2 == 3 then --x--
				pmin = vec(-6, 0, -1)
				pmax = vec(-1, 2,  1)
			end

			pmin = vector.add(pos, pmin)
			pmax = vector.add(pos, pmax)
			local manip = minetest.get_voxel_manip()
			local emin, emax = manip:read_from_map(pmin, pmax)
			local vm_area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
			local vm_nodes = manip:get_data()

			local protected_pos = nil
			local tunnelbomb_drops = {}
			tunnelbomb_drops["default:cobble"] = 0
			tunnelbomb_drops[":current player"] = player

			for z = pmin.z, pmax.z do
			for y = pmin.y, pmax.y do
			for x = pmin.x, pmax.x do
				local xpos = vec(x, y, z)
				if minetest.is_protected(xpos, player_name) then
					protected_pos = xpos
				else
					tunnelbomb_dig(xpos, tunnelbomb_drops, vm_area, vm_nodes)
				end
			end
			end
			end

			manip:set_data(vm_nodes)
			manip:write_to_map()
			manip:update_map()

			for item, count in pairs(tunnelbomb_drops) do
				if item ~= ":current player" and count > 0 then
					local def = minetest.registered_items[item]
					if def and def.stack_max then
						while count > def.stack_max do
							minetest.add_item(pos, item .." ".. def.stack_max)
							count = count - def.stack_max
						end
						minetest.add_item(pos, item .." ".. count)
					end
				end
			end
			tunnelbomb_drops = nil
			if protected_pos then
				minetest.record_protection_violation(protected_pos, player_name)
			end
		end
	end,
})

local c_air = minetest.get_content_id("air")
function tunnelbomb_dig(pos, tunnelbomb_drops, vm_area, vm_nodes)
	local node = minetest.get_node(pos)
	if node.name == "air" or node.name == "ignore" then
		return
	end

	local node_data = minetest.registered_nodes[node.name]
	if node_data.can_dig then
		if not node_data.can_dig(pos, tunnelbomb_drops[":current player"]) then
			return
		end
	end
	if node_data.liquidtype ~= "none" then
		return
	end

	vm_nodes[vm_area:index(pos.x, pos.y, pos.z)] = c_air
	if node.name == "default:stone" then
		tunnelbomb_drops["default:cobble"] = tunnelbomb_drops["default:cobble"] + 1
		return
	end
	local drops = minetest.get_node_drops(node.name)
	for _, item in ipairs(drops) do
		local stack = ItemStack(item)
		local item_name = stack:get_name()
		local item_count = stack:get_count()
		if not tunnelbomb_drops[item_name] then
			tunnelbomb_drops[item_name] = item_count
		else
			tunnelbomb_drops[item_name] = tunnelbomb_drops[item_name] + item_count
		end
	end
end