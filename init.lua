local HorizHud = nil
local VertHud = nil
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

local function get_vertical_target(eye_pos, scaled_look_dir, player)
	local pos_above = vector.add(eye_pos, vector.new(0, -1, 0))
	local pos_below = vector.add(eye_pos, vector.new(0, 1, 0))
	local pitch = player:get_look_vertical()
	local pointed
	pointed = minetest.raycast(pos_below, vector.add(pos_below, scaled_look_dir), false, false)
	local pointed_thing
	local target
	local direction
	for pointed_thing in pointed do
		if ((pitch > 0) and (pointed_thing) and (pointed_thing.type == "node") and (math.abs(eye_pos.y - pointed_thing.under.y) > 1)) then
			target = pointed_thing
			break
		end
	end
	if (target) then
		direction = vector.new(0, -1, 0)
		return {target = target, direction = direction}
	end
	pointed = minetest.raycast(pos_above, vector.add(pos_above, scaled_look_dir), false, false)
	for pointed_thing in pointed do
		if ((pitch < 0) and (pointed_thing) and (pointed_thing.type == "node") and (math.abs(player:get_pos().y - pointed_thing.under.y) > 2)) then
			target = pointed_thing
			break
		end
	end
	if (target) then
		direction = vector.new(0, 1, 0)
		return {target = target, direction = direction}
	end
	return {target = nil, direction = nil}
end

local function get_horizontal_target(eye_pos, scaled_look_dir, step_dir, player)
	local stepped_offset = vector.add(eye_pos, vector.multiply(step_dir, -1))
	local pointed = minetest.raycast(stepped_offset, vector.add(stepped_offset, scaled_look_dir), false, false)
	local pointed_thing
	local target
	local direction
	for pointed_thing in pointed do
		if ((pointed_thing) and (pointed_thing.type == "node")) then
			target = pointed_thing
			direction = step_dir
			break
		end
	end
	return {target = target, direction = direction}
end

local function get_extended_placement_target(eye_pos, scaled_look_dir, step_dir, player)
	local target
	target = get_vertical_target(eye_pos, scaled_look_dir, player)
	if (not target.target) then
		target = get_horizontal_target(eye_pos, scaled_look_dir, step_dir, player)
	end
	return {target = target.target, direction = target.direction}
end

local place_cooldown = 0

local function is_player_looking_past_node(dtime)
	place_cooldown = place_cooldown + dtime
	local p = minetest.get_player_by_name("singleplayer")
	if (HorizHud) then
		p:hud_remove(HorizHud)
		HorizHud = nil
	end
	if (VertHud) then
		p:hud_remove(VertHud)
		VertHud = nil
	end
	if (p ~= nil) then
		if (p:get_wielded_item() ~= nil) then
			local wield_name = ItemStack().get_name(p:get_wielded_item())
			if (minetest.registered_nodes[wield_name]) then
				local dir = p:get_look_dir()
				local eye_pos = p:get_pos()
				eye_pos.y = eye_pos.y + p:get_properties().eye_height
				local first, third = p:get_eye_offset()
				if not vector.equals(first, third) then
					minetest.log("warning", "First & third person eye offsets don't match, assuming first person")
				end
				eye_pos = vector.add(eye_pos, vector.divide(first, 10)) -- eye offsets are in block space (10x), transform them back to metric
				local def = p:get_wielded_item():get_definition()
				local scaled_look_dir = vector.multiply(dir, def.range or 4)
				local look_yaw = vector.new(0, p:get_look_horizontal(), 0)
				local look_xz = vector.normalize(vector.rotate(vector.new(0, 0, 1), look_yaw))
				local direction_vec
				if ((math.abs(look_xz.x)) > (math.abs(look_xz.z))) then
					direction_vec = vector.normalize(vector.new(look_xz.x, 0, 0))
				else
					direction_vec = vector.normalize(vector.new(0, 0, look_xz.z))
				end
				local pointed = minetest.raycast(eye_pos, vector.add(eye_pos, scaled_look_dir), false, false)
				local pointed_thing
				local pointed_node
				for pointed_thing in pointed do
					if (pointed_thing and pointed_thing.type == "node") then
						pointed_node = pointed_thing
					end
				end
				if (not pointed_node) then
					local result = get_extended_placement_target(eye_pos, scaled_look_dir, direction_vec, p)
					if ((result.direction) and (result.direction.y ~= 0)) then
						if (p.get_player_control(p).sneak) then
							if (not VertHud) then
								VertHud = p:hud_add(hud_vert_def)
							end
						end
					elseif ((result.direction) and ((result.direction.x ~= 0) or (result.direction.z ~= 0))) then
						if (not HorizHud) then
							HorizHud = p:hud_add(hud_horiz_def)
						end
					end
					if ((p.get_player_control(p).place) and (result.target) and (result.direction)) then
						if (place_cooldown >= 0.3) then
							place_cooldown = 0
							local new_pos = vector.add(result.target.under, result.direction)
							result.target.under = new_pos
							if minetest.is_protected(new_pos, p:get_player_name()) then
								return
							end
							local wieldstack = p:get_wielded_item()
							p:set_wielded_item(minetest.item_place(wieldstack, p, result.target))
						end
					end
				end
			end
		end
	end
end

local timer=0
minetest.register_globalstep(function (dtime)
	timer = timer + dtime
	if (timer >= 0.01) then
		timer = 0
		is_player_looking_past_node(dtime)
	end

end)
