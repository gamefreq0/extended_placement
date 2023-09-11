local HorizHud = {}
local VertHud = {}
local hud_horiz_def = {
	hud_elem_type = "image",
	text = "extended_placement_horiz.png",
	position = {x = 0.5, y = 0.5},
	scale = {x = 1, y = 1},
	alignment = {x = 0, y = 0},
	offset = {x = 0, y = 0}
}
local hud_vert_def = {
	hud_elem_type = "image",
	text = "extended_placement_vert.png",
	position = {x = 0.5, y = 0.5},
	scale = {x = 1, y = 1},
	alignment = {x = 0, y = 0},
	offset = {x = 0, y = 0}
}

local function target_at_player_height(eye_pos, target, step_dir)
	target.under = vector.add(target.under, step_dir)
	if ((math.abs(target.under.y - eye_pos.y) < 1) or (math.abs(target.under.y - (eye_pos.y - 1)) < 1)) then
		return true
	end
end

local function target_in_player(eye_pos, target, step_dir)
	if (not target_at_player_height(eye_pos, target, step_dir)) then
		return
	end
	if ((math.abs(target.under.x - eye_pos.x) < 1) and (math.abs(target.under.z - eye_pos.z) < 1)) then
		return true
	end
end

local function get_vertical_target(eye_pos, scaled_look_dir, player)
	local look = player:get_look_dir()
	local step_dir = vector.normalize(vector.new(0, look.y, 0))
	local stepped_offset = vector.add(eye_pos, vector.multiply(step_dir, -1))
	local pointed = minetest.raycast(stepped_offset, vector.add(stepped_offset, scaled_look_dir), false, false)
	local target
	local direction
	for pointed_thing in pointed do
		if ((pointed_thing) and (pointed_thing.type == "node") and (not target_at_player_height(eye_pos, pointed_thing, step_dir))) then
			target = pointed_thing
			direction = step_dir
			break
		end
	end
	return target, direction
end

local function get_horizontal_target(eye_pos, scaled_look_dir, step_dir)
	local stepped_offset = vector.add(eye_pos, vector.multiply(step_dir, -1))
	local pointed = minetest.raycast(stepped_offset, vector.add(stepped_offset, scaled_look_dir), false, false)
	local target
	local direction
	for pointed_thing in pointed do
		if ((pointed_thing) and (pointed_thing.type == "node") and (not target_in_player(eye_pos, pointed_thing, step_dir))) then
			target = pointed_thing
			direction = step_dir
			break
		end
	end
	return target, direction
end

local function get_extended_placement_target(eye_pos, scaled_look_dir, step_dir, player)
	local target, direction
	target, direction = get_vertical_target(eye_pos, scaled_look_dir, player)
	if (not target) then
		target, direction = get_horizontal_target(eye_pos, scaled_look_dir, step_dir)
	end
	return target, direction
end

local place_cooldown = {}

local function do_player_placement_checks(player, dtime)
	local hand_reach = minetest.registered_items[""].range or 4
	place_cooldown[player] = place_cooldown[player] + dtime
	local pname = player.get_player_name(player)
	if (HorizHud[pname]) then
		player:hud_remove(HorizHud[pname])
		HorizHud[pname] = nil
	end
	if (VertHud[pname]) then
		player:hud_remove(VertHud[pname])
		VertHud[pname] = nil
	end
	if (not player:get_wielded_item()) then
		return
	end
	local wield_name = ItemStack().get_name(player:get_wielded_item())
	if (not minetest.registered_nodes[wield_name]) then
		return
	end
	local dir = player:get_look_dir()
	local eye_pos = player:get_pos()
	eye_pos.y = eye_pos.y + player:get_properties().eye_height
	local first, third = player:get_eye_offset()
	if not vector.equals(first, third) then
		minetest.log("warning", "First & third person eye offsets don't match, assuming first person")
	end
	eye_pos = vector.add(eye_pos, vector.divide(first, 10)) -- eye offsets are in block space (10x), transform them back to metric
	local def = player:get_wielded_item():get_definition()
	local scaled_look_dir = vector.multiply(dir, def.range or hand_reach)
	local look_yaw = vector.new(0, player:get_look_horizontal(), 0)
	local look_xz = vector.normalize(vector.rotate(vector.new(0, 0, 1), look_yaw))
	local direction_vec
	if ((math.abs(look_xz.x)) > (math.abs(look_xz.z))) then
		direction_vec = vector.normalize(vector.new(look_xz.x, 0, 0))
	else
		direction_vec = vector.normalize(vector.new(0, 0, look_xz.z))
	end
	local pointed = minetest.raycast(eye_pos, vector.add(eye_pos, scaled_look_dir), false, false)
	local pointed_node
	for pointed_thing in pointed do
		if (pointed_thing and pointed_thing.type == "node") then
			pointed_node = pointed_thing
		end
	end
	if (pointed_node) then
		return
	end
	local target, direction = get_extended_placement_target(eye_pos, scaled_look_dir, direction_vec, player)
	if ((not target) or (not direction)) then
		return
	end
	if (direction.y ~= 0) then
		if (not VertHud[pname]) then
			VertHud[pname] = player:hud_add(hud_vert_def)
		end
	elseif ((direction.x ~= 0) or (direction.z ~= 0)) then
		if (not HorizHud[pname]) then
			HorizHud[pname] = player:hud_add(hud_horiz_def)
		end
	end
	if (not player.get_player_control(player).place) then
		return
	end
	if (place_cooldown[player] < 0.3) then
		return
	end
	place_cooldown[player] = 0
	if (HorizHud[pname]) then
		player:hud_remove(HorizHud[pname])
		HorizHud[pname] = nil
	end
	if (VertHud[pname]) then
		player:hud_remove(VertHud[pname])
		VertHud[pname] = nil
	end
	if minetest.is_protected(target, player:get_player_name()) then
		return
	end
	local wieldstack = player:get_wielded_item()
	local _, position = minetest.item_place(wieldstack, player, target)
	if (not position) then
		return
	end
	player:set_wielded_item(wieldstack)
	local placed_node = minetest.get_node(position)
	local placed_node_def = minetest.registered_nodes[placed_node.name]
	local sound_param = {pos = position, to_player = player:get_player_name()}
	if (not placed_node_def.sounds.place) then
		return
	end
	minetest.sound_play(placed_node_def.sounds.place, sound_param, true)
end

minetest.register_globalstep(function (dtime)
for _, player in pairs(minetest.get_connected_players()) do
	do_player_placement_checks(player, dtime)
end

end)

minetest.register_on_joinplayer(function (player)
	place_cooldown[player] = 0
end)

minetest.register_on_leaveplayer(function (player)
	HorizHud[player] = nil
	VertHud[player] = nil
	place_cooldown[player] = nil
end)
