--Mining Bomb, destroys blocks in a range of 3x3x8
--Created by Krock, WTFPL

minetest.register_craft({
	output = 'mining_plus:tunnelbomb',
	recipe = {
		{ 'group:wood', 'default:mese_crystal_fragment', 'group:wood' },
		{ 'default:stick', 'default:steel_ingot', 'default:stick' },
		{ 'group:wood', 'default:coal_lump', 'group:wood' },
	}
})

local tunnelbomb_drops = {}
minetest.register_node("mining_plus:tunnelbomb", {
	description = "Tunnel Bomb",
	tiles = {"mining_tunnelbomb_top.png", "mining_tunnelbomb_top.png", "mining_tunnelbomb_side.png",
		"mining_tunnelbomb_side.png", "mining_tunnelbomb_back.png", "mining_tunnelbomb_front.png"},
	paramtype2 = "facedir",
	groups = {cracky=1},
	--legacy_facedir_simple = true,
	sounds = default.node_sound_stone_defaults(),
	on_punch = function(pos, node, player)
		local player_name = player:get_player_name()
		if minetest.is_protected(pos, player_name) then
			return
		end
		if player:get_wielded_item():get_name() == "default:torch" then
			minetest.sound_play("exploding0", {pos=pos})
			minetest.remove_node(pos)
			local nearto = minetest.get_objects_inside_radius(pos, 3)
			for _, obj in pairs(nearto) do
				if obj:is_player() then
					obj:set_hp(obj:get_hp() - 4)
				end
			end
	
			local protected = false
			local protect_node = {x=99999, y=99999, z=99999}
			tunnelbomb_drops = {}
			tunnelbomb_drops["default:cobble"] = 0
			if(node.param2 == 0) then --z++
				for posX = -1, 1 do
				for posY = 0, 2 do
				for posZ = 1, 7 do
					local xpos = {x=pos.x+posX, y=pos.y+posY, z=pos.z+posZ}
					if minetest.is_protected(xpos, player_name) then
						if(not protected) then
							protect_node = xpos
						end
						protected = true
					else
						tunnelbomb_dig(xpos)
					end
				end
				end
				end
			elseif(node.param2 == 1) then --x++
				for posX = 1, 7 do
				for posY = 0, 2 do
				for posZ = -1, 1 do
					local xpos = {x=pos.x+posX, y=pos.y+posY, z=pos.z+posZ}
					if minetest.is_protected(xpos, player_name) then
						if(not protected) then
							protect_node = xpos
						end
						protected = true
					else
						tunnelbomb_dig(xpos)
					end
				end
				end
				end
			elseif(node.param2 == 2) then --z--
				for posX = -1, 1 do
				for posY = 0, 2 do
				for posZ = -1, -7,-1 do
					local xpos = {x=pos.x+posX, y=pos.y+posY, z=pos.z+posZ}
					if minetest.is_protected(xpos, player_name) then
						if(not protected) then
							protect_node = xpos
						end
						protected = true
					else
						tunnelbomb_dig(xpos)
					end
				end
				end
				end
			elseif(node.param2 == 3) then --x--
				for posX = -1, -7,-1 do
				for posY = 0, 2 do
				for posZ = -1, 1 do
					local xpos = {x=pos.x+posX, y=pos.y+posY, z=pos.z+posZ}
					if minetest.is_protected(xpos, player_name) then
						if(not protected) then
							protect_node = xpos
						end
						protected = true
					else
						tunnelbomb_dig(xpos)
					end
				end
				end
				end
			else
				minetest.chat_send_player(player_name, "Too bad, now you've lost one tunnel bomb.")
			end
			for item,count in pairs(tunnelbomb_drops) do
				if(count ~= 0) then
					while count > 99 do
						minetest.add_item(pos, item.." 99")
						count = count - 99
					end
					minetest.add_item(pos, item.." "..count)
				end
			end
			if(protected) then
				minetest.record_protection_violation(protect_node, player_name)
			end
		end
	end,
})
function tunnelbomb_dig(pos)
	local node = minetest.get_node(pos)
	if node.name == "air" or node.name == "ignore"
		or node.name == "default:lava_source" or node.name == "default:lava_flowing"
		or node.name == "default:water_source" or node.name == "default:water_flowing" then
		return
	end
	local grp = minetest.registered_nodes[node.name]
	if(grp.groups.cracky ~= 3) then
		return
	end
	minetest.remove_node(pos)
	if(node.name == "default:stone") then
		tunnelbomb_drops["default:cobble"] = tunnelbomb_drops["default:cobble"] + 1
		return
	end
	local drops = minetest.get_node_drops(node.name)
	for _, item in ipairs(drops) do
		local stack = ItemStack(item)
		local item_name = stack:get_name()
		local item_count = stack:get_count()
		if(tunnelbomb_drops[item_name] ~= nil) then
			tunnelbomb_drops[item_name] = tunnelbomb_drops[item_name] + item_count
		else
			tunnelbomb_drops[item_name] = item_count
		end
	end
end