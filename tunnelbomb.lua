--Mining Bomb, destroys blocks in a range of 3x3x8
--Created by Krock, WTFPL

minetest.register_craft({
	output = "mining_plus:tunnelbomb",
	recipe = {
		{ "group:wood", "default:obsidian_shard", "group:wood" },
		{ "default:stick", "default:steel_ingot", "default:stick" },
		{ "group:wood", "default:coal_lump", "group:wood" },
	}
})

local tunnelbomb_drops = nil
local vm_area, vm_nodes
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
	
			local p1, p2
			if node.param2 == 0 then --z++
				p1 = {-1, 0, 1}
				p2 = {1, 2, 6}
			elseif node.param2 == 1 then --x++
				p1 = {1, 0, -1}
				p2 = {6, 2, 1}
			elseif node.param2 == 2 then --z--
				p1 = {-1, 0, -6}
				p2 = {1, 2, -1}
			elseif node.param2 == 3 then --x--
				p1 = {-6, 0, -1}
				p2 = {-1, 2, 1}
			else
				minetest.chat_send_player(player_name, "Too bad, now you've lost this tunnel bomb.")
				return
			end

			local manip = minetest.get_voxel_manip()
			local emin, emax = manip:read_from_map(
				{x=pos.x+p1[1],y=pos.y+p1[2],z=pos.z+p1[3]},
				{x=pos.x+p2[1],y=pos.y+p2[2],z=pos.z+p2[3]}
			)
			vm_area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
			vm_nodes = manip:get_data()

			local protected = false
			local protect_node = {x=99999, y=99999, z=99999}
			tunnelbomb_drops = {}
			tunnelbomb_drops["default:cobble"] = 0
			tunnelbomb_drops["::player"] = player
			for posX = p1[1], p2[1] do
				for posY = p1[2], p2[2] do
					for posZ = p1[3], p2[3] do
						local xpos = vector.add(pos, {x=posX, y=posY, z=posZ})
						if minetest.is_protected(xpos, player_name) then
							if not protected then
								protect_node = xpos
							end
							protected = true
						else
							tunnelbomb_dig(xpos)
						end
					end
				end
			end

			manip:set_data(vm_nodes)
			manip:write_to_map()
			manip:update_map()

			for item,count in pairs(tunnelbomb_drops) do
				if item ~= "::player" and count ~= 0 then
					while count > 99 do
						minetest.add_item(pos, item.." 99")
						count = count - 99
					end
					minetest.add_item(pos, item.." "..count)
				end
			end
			tunnelbomb_drops = nil
			if protected then
				minetest.record_protection_violation(protect_node, player_name)
			end
		end
	end,
})

local c_air = minetest.get_content_id("air")
function tunnelbomb_dig(pos)
	local node = minetest.get_node(pos)
	if node.name == "air" or node.name == "ignore" then
		return
	end
	
	local node_data = minetest.registered_nodes[node.name]
	if node_data.can_dig then
		if not node_data.can_dig(pos, tunnelbomb_drops["::player"]) then
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