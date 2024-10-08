-- title: Plant Push
-- author: Samuel Familusi
-- desc: help the garden, the garden helps you
-- script: lua
-- saveid: plantpush

-- settings
debug_mode = false
debug_allowed = true
force_gamepad = false
start_level = 0


-- voxel scene variables
local transparency = 13 --transparency mask for voxels and background colour
local num_layers = 7 --the total height of the voxel data
local layer_width = 12
local layer_height = 12
local layer_map_separation = 13

-- camera variables
camera_angle = math.pi
camera_incline = 0
camera_zoom = 0

-- camera smoothly interpolates to these values
tcamera_angle = math.pi * 1.75
tcamera_incline = math.pi * 0.3
tcamera_zoom = 4

-- math
a = { -- important list of directions
	{ 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 },
	{ -1, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }
}

function clamp(n, low, high) return math.min(math.max(n, low), high) end

function lerp(a, b, t) return (1 - t) * a + t * b end

function frnd(max) return math.random() * max end

function rotate(point, angle)
	return {
		x = (point.x * math.cos(angle) - point.y * math.sin(angle)),
		y = (point.y * math.cos(angle) + point.x * math.sin(angle))
	}
end

function lerp_angle(a, b, t)
	local a_vec = rotate({ x = 0, y = -1 }, a)
	local b_vec = rotate({ x = 0, y = -1 }, b)
	local lerped_vec = { x = lerp(a_vec.x, b_vec.x, t), y = lerp(a_vec.y, b_vec.y, t) }
	return math.pi - math.atan(lerped_vec.x, lerped_vec.y)
end

function shuffle(array)
	newArray = {}
	while (#array > 0) do
		-- random index
		n = math.ceil(frnd(#array))
		table.insert(newArray, table.remove(array, n))
	end
	return newArray
end

Vec = {

	new = function(x, y, z)
		local v = { x = x, y = y, z = z }
		setmetatable(v, Vec.mt)
		return v
	end,

	mt = {

		__add = function(u, v)
			return Vec.new(u.x + v.x, u.y + v.y, u.z + v.z)
		end,

		__sub = function(u, v)
			return Vec.new(u.x - v.x, u.y - v.y, u.z - v.z)
		end,

		__eq = function(u, v)
			return u.x == v.x and u.y == v.y and u.z == v.z
		end,

		__tostring = function(v)
			return "(" .. v.x .. "," .. v.y .. "," .. v.z .. ")"
		end,

		__concat = function(s, v)
			return s .. "(" .. v.x .. "," .. v.y .. "," .. v.z .. ")"
		end,
	},
}

up = Vec.new(0, 0, 1)

-- game variables
local tics = 0 -- times the game has updated
start_time = time()

-- milliseconds scince the player started jumping
-- 0 if the player is not jumping
jump_start_time = 0

player_updated = false
plants = 0 -- number of plants in the level
watered_plants = 0
water = false
portal_pos = nil

-- used for smooth ui animations
dwatered_plants = 0
dwater = 0

-- tile data

tiles = {} -- tile data

tiles[64] = {
	name = "player",
	run = function() end,
	update = function(pos)
		-- update the player only once a frame
		-- even if it moves into  a position yet to be updated
		if player_updated then return else player_updated = true end

		local direction = Vec.new(0, 0, 0) -- the direction the player wants to move

		-- if the player is on solid ground
		if fget(get_tile(pos - up), 0) then
			jump_start_time = 0
			if input("Jump") then
				direction = up
				jump_start_time = time()
			end
		end

		if time() - jump_start_time > 1000 then
			jump_start_time = 0
		end

		-- map keyboard buttons to directions based on camera rotation
		local r = math.floor((((camera_angle + (math.pi / 4)) % (math.pi * 2)) / (math.pi * 2)) * 4)
		local dirs = "WASDWASD"

		for i = 1, 4 do
			local s = dirs:sub(i + 4 - r, i + 4 - r)

			if input(s) or input("a" .. s) then
				direction = Vec.new(a[i][1], a[i][2], 0)
				jump_start_time = 0
				sfx(5)
			end
		end

		fset(64, 6, jump_start_time == 0)
		push_tile(pos, direction)
	end
}
tiles[15] = {
	name = "plant_pot",
	run = function(pos, dir)
		if not water then return end
		if dir.z ~= 0 then return end

		local tile_above = get_tile(pos + up)
		if fget(tile_above, 2) then
			push_tile(pos + up, up)
		end

		tile_above = get_tile(pos + up)
		if fget(tile_above, 0) then
			return
		end

		set_tile(pos + up, 128)
		set_tile(pos, 143)
		sfx(1)
		watered_plants = watered_plants + 1
		water = false
		just_watered = true

		-- spawn a portal when all plants are watered
		if watered_plants == plants then
			sfx(2)
			set_tile(portal_pos, 77)
		end
	end,
	update = function(pos)
		if get_tile(pos - up) == 14 or get_tile(pos - up) == 136 then
			local keep = water
			water = true
			tiles[get_tile(pos)].run(pos, Vec.new(1, 0, 0))
			water = keep

			if get_tile(pos) == 143 then
				set_tile(pos - up, 13)
			end
		end
	end
}
tiles[79] = {
	name = "plant_pot_pushable",
	run = tiles[15].run,
	update = tiles[15].update
}
tiles[14] = {
	name = "bucket_pushable",
	run = function(pos, dir)
		if not water then
			water = true
			set_tile(pos, 13)
		end
	end,
	update = function(pos)
		if not water then
			set_tile(pos, 136)
		end
	end
}
tiles[136] = {
	name = "bucket",
	run = tiles[14].run,
	update = function(pos)
		if water then
			set_tile(pos, 14)
		end
	end
}
tiles[198] = {
	name = "empty_bucket",
	run = function(pos, dir)
		if water then
			set_tile(pos, 14)
			water = false
		end
	end,
	update = function(pos) end
}
tiles[197] = {
	name = "empty_bucket_pushable",
	run = tiles[198].run,
	update = function(pos) end
}
tiles[77] = {
	name = "portal",
	run = function(pos, dir)
		if current_level == num_levels or watered_plants < plants then return end
		change_level(false, -2)
		sfx(03)
	end,
	update = function(pos) end
}
tiles[192] = {
	name = "target",
	run = function(pos, dir) end,
	update = function(pos)
		if debug_mode and keyp(20) then
			-- press t to trace positions of all targets in the level
			set_tile(pos, 0)
			trace(tostring(pos))
		end
	end
}

function push_tile(pos, direction)

	local self = get_tile(pos)

	if self == 78 and direction.z == 1 then return end
	if self == 195 and (direction.x ~= 0 or direction.z == 1) then return end
	if self == 196 and (direction.y ~= 0 or direction.z == 1) then return end

	local target_pos = pos + direction

	if -- if the target position is out of the level
	target_pos.x < 0 or target_pos.x > layer_width - 1
		or target_pos.y < 0 or target_pos.y > layer_height - 1
		or target_pos.z < 0 or target_pos.z > num_layers - 1
	then return
	end

	local target_tile = get_tile(target_pos)

	if target_tile == 129 then -- fall into water
		if self == 79 or self == 15 or self == 64 then
			change_level(true, -4)
		end
		set_tile(pos, 0)
		return
	end

	if fget(target_tile, 2) then -- pushable tiles have flag 2 yellow
		push_tile(target_pos, direction)
		target_tile = get_tile(target_pos) -- update the target_tile
	end

	if fget(target_tile, 1) and self == 64 then -- interactable tiles have flag 1 orange
		tiles[target_tile].run(target_pos, direction)
		target_tile = get_tile(target_pos)
	end

	if not fget(target_tile, 0) then
		set_tile(target_pos, self)
		set_tile(pos, 0)
		if self == 79 or self == 13 or self == 14 or self == 197 then
			sfx(6)
		end
	end
end

function game_to_map(game_pos)
	return Vec.new(
		game_pos.x + (game_pos.z * (layer_map_separation)),
		game_pos.y,
		0
	)
end

function map_to_game(map_pos)
	return Vec.new(
		map_pos.x % (layer_map_separation),
		map_pos.y,
		map_pos.x // (layer_map_separation)
	)
end

function get_tile(pos)
	local map_pos = game_to_map(pos)
	return mget(map_pos.x, map_pos.y)
end

function set_tile(pos, tile)
	local map_pos = game_to_map(pos)
	mset(map_pos.x, map_pos.y, tile)
end

colors = {}
for i = 0, 255 do
	if fget(i, 4) then
		colors[i] = peek4((0x4000 + i * 32) * 2 + 1 % 8 + 1 % 8 * 8) -- get a pixel from the sheet at i
	end
end

-- level data
num_levels = 11
current_level = 0
level_trans = false -- used for the level transition animation
restart = false
function change_level(reset, zoom)
	level_trans = true

	if reset then restart = true end
	tcamera_zoom = zoom
	tcamera_incline = math.pi / 6
	tcamera_angle = 0
end

function set_level_data(level)

	if current_level == 0 and level == 1 and (pmem(1) ~= 0) then
		level = pmem(1)
	end

	-- reset the level variables
	watered_plants = 0
	water = false
	plants = 0

	-- copy the map data
	for i = 0, layer_height do -- for each row of the level
		memcpy(
		-- dest for each row
			0x08000 -- start of map data
			+ (240 * i) -- map is 240 tiles wide
			,
		-- the source
			0x08000
			+ (
				(240 * 17) -- each level region is 17 blocks tall
				* (level - (level > 7 and 8 or 0)) -- level > 7 : wrap back to top of map
			)
			+ (level > 7 and 120 or 0) -- level > 7 : start at 120 instead of 0
			+ (240 * i)
			,
		-- the number of tiles to copy
			layer_map_separation * num_layers -- total width of all layers in map row
		)
	end

	for x = 0, layer_width - 1 do
		for y = 0, layer_height - 1 do
			for z = 0, num_layers - 1 do
				local pos = Vec.new(x, y, z)
				local tile = get_tile(pos)

				if tile == 64 then
					portal_pos = pos
				end

				if tile == 79 or tile == 15 then
					plants = plants + 1
				end
			end
		end
	end

	if level ~= 0 then
		current_level = level
		pmem(1, level)
	end
end

-- debug stuff
lp = 0
np = 0
etg = {}
for i = 1, 20 do table.insert(etg, 0) end
fps = 0
function FPS()
	if tics % 12 == 0 then
		for i = 1, 19 do
			etg[i] = etg[i + 1]
		end
		etg[20] = math.floor(et)
		fps = math.floor(1 / (et / 1000))
	end
	if fps > 60 then fps = 60 end
	print("FPS:", 5, 5, 10)
	print(fps, 26, 5, 15)
	rect(4, 11, 13, 7, 0)
	print("et:", 5, 12)
	rect(18, 11, 21, 1, 15)
	rect(38, 11, 1, etg[20] / 2 + 1, 10)
	for i = 1, 20 do
		local c = 11
		if etg[i] > 20 then c = 7 end
		if etg[i] > 30 then c = 4 end
		if etg[i] > 50 then c = 2 end
		rect(17 + i, 12, 1, etg[i] / 2, c)
	end
	print(math.floor(1000 / fps), 19, 13)
	pix(37, etg[20] / 2 + 11, 10)

	print(
		"Tex : " .. texs ..
		"\nnot Tex : " .. tris ..
		"\nblank : " .. nulls,
		0, 136 - 32
	)
end

-- graphics
function pal(c0, c1)
	if (c0 == nil and c1 == nil) then for i = 0, 15 do poke4(0x3FF0 * 2 + i, i) end
	else poke4(0x3FF0 * 2 + c0, c1) end
end

function Text(text, x, y, colour, scale, alt)
	local keep = peek4(2 * 0x03FFC)
	pal(1, colour or 15)
	poke4(2 * 0x03FFC, 8)
	n = font(text, x, y, 0, 5, 8, false, scale, alt)
	pal()
	poke4(2 * 0x03FFC, keep)
	return n
end

function outlined_Text(
        text, x, y,
        color, outline_color,
        scale, alt, corners
)
	corners = corners or true
	for i = 1, corners and 8 or 4 do
		Text(text, x + a[i][1], y + a[i][2], outline_color, scale, alt)
	end
	Text(text, x, y, color, scale, alt)
end

function Progressbar(x, y, width, progress, colour)
	rect(
		x, y,
		math.min(progress, 1) * width, 3,
		colour
	)
	if progress > 0.07 then
		pix(x - 2, y + 1, 15)
		pix(x + width, y + 1, 15)
	end
end

-- input

kbd = {
	W = 23, aW = 58,
	A = 01, aA = 60,
	S = 19, aS = 59,
	D = 04, aD = 61,
	Jump = 48,
	Restart = 18,
}
btns = {
	W = 0, aW = 0,
	A = 2, aA = 2,
	S = 1, aS = 1,
	D = 3, aD = 3,
	Jump = 4,
	Restart = 6,
}
prev_mouse = {}

function input(action)
	if input_mode == "keyboard" then
		return keyp(kbd[action])
	elseif input_mode == "gamepad" then
		return btnp(btns[action]) and not btn(7)
	end
end

-- initialise the game
set_level_data(start_level)
camera_angle = math.pi * 1.5
input_mode = ""
platform = ""
if start_level ~= 0 then
	tcamera_zoom = 10
	camera_zoom = tcamera_zoom
	camera_angle = tcamera_angle
	camera_incline = tcamera_incline
	input_mode = force_gamepad and "gamepad" or "keyboard"
	platform = "desktop"
end
--

function TIC()

	-- part of FPS debug
	np = time()
	et = np - lp
	lp = np
	texs = 0
	tris = 0
	nulls = 0

	if keyp(42) and debug_allowed then
		debug_mode = not debug_mode
	end

	delta_time = (time() - start_time) * 0.001
	start_time = time()

	-- update game
	if input("Restart") and current_level ~= 0 then
		change_level(true, -5)
	end
	if level_trans and camera_zoom < (restart and 0.7 or 0.1) then
		if restart then
			tcamera_zoom = 0.7
			-- if not pressing the restart action
			if not (
				input_mode == "gamepad" and
					(btn(btns["Restart"]) and not btn(7))
					or
					key(kbd["Restart"]))
			then
				set_level_data(current_level)
				restart = false

				-- set camera variables
				tcamera_angle = math.pi * 1.75
				tcamera_incline = math.pi * 0.3
				tcamera_zoom = 8

				level_trans = false
			end
		else
			set_level_data(
				current_level + 1 > num_levels
				and num_levels or current_level + 1
			)
			deleteallps()
			sparks(240 / 2, 136 * (4 / 7))
			stars()

			-- set camera variables
			tcamera_angle = math.pi * 1.75
			tcamera_incline = math.pi * 0.3
			tcamera_zoom = current_level == 15 and 4 or 8

			level_trans = false
		end

		if current_level == 3 then
			tcamera_angle = math.pi * 1.25
		end
	end

	just_watered = false

	if current_level == 0 then -- tutorial level
		-- resume game or delete progress
		if pmem(1) ~= 0
		then
			if (input_mode == "gamepad" and btnp(6) or keyp(18)) then
				pmem(1, 0)
			end
			if (input_mode == "gamepad" and btnp(4) or keyp(48)) then
				change_level(false, -5)
			end
		end

		-- set input mode
		if input_mode == "" and tcamera_zoom - camera_zoom < 0.7 then
			if keyp() and not force_gamepad then
				input_mode = "keyboard"
				platform = "desktop"
				tcamera_zoom = 8
				tcamera_angle = math.pi * 0.25
				tcamera_incline = math.pi * 0.3
			else
				for i = 0, 7 do
					if btnp(i) then
						input_mode = "gamepad"
						platform = (({ mouse() })[3] and not prev_mouse[3]) and "mobile" or "desktop"
						tcamera_zoom = 8
						tcamera_angle = math.pi * 0.25
						tcamera_incline = math.pi * 0.3
					end
				end
			end
		end
	end

	update_cam()
	update_psystems()

	if debug_mode and keyp(20) then
		trace("-----------\n" .. "Level " .. current_level)
	end

	-- iterate over all the tiles in the game
	player_updated = false

	for x = 0, layer_width - 1 do
		for y = 0, layer_height - 1 do
			for z = 0, num_layers - 1 do
				local pos = Vec.new(x, y, z)
				local tile = get_tile(pos)

				if fget(tile, 1) then
					tiles[tile].update(pos)
				end

				-- flags 6 (dark blue) means that a block can be affected by gravity
				if fget(tile, 6) and not fget(get_tile(pos - up), 0) then
					push_tile(pos, Vec.new(0, 0, -1))
				end

			end
		end
	end

	--render game
	cls(transparency)
	poke(0x03FF8, transparency)

	if not level_trans then
		Text(-- background text
			current_level == 0 and
			"PLANT PUSH"
			or
			(current_level == num_levels and
				"Thanks" .. (platform == "desktop" and "\n\n\n" or "\n") .. "for playing :)"
				or
				"Level    " .. current_level
			),
			44,
			(current_level == num_levels and 40 or 50)
			+ ((camera_zoom - 4) * 22) - (platform == "mobile" and 40 or 0),
			15, 2, true
		)
	end

	-- Render the Level Progress
	local bar_width = camera_zoom * layer_width * 1.4
	Progressbar(
		(240 - bar_width) / 2,
		134,
		bar_width,
		current_level / num_levels,
		15
	)

	draw_psystems()
	if #particle_systems > 0 then
		rect(110, 75, 20, 10, transparency)
	end

	if platform == "mobile" then
		-- temporarily increase camera zoom before render on mobile
		local keep = camera_zoom
		camera_zoom = camera_zoom * 1.25
		renderVoxelScene()
		camera_zoom = keep
	else
		renderVoxelScene()
	end

	-- tutorial graphics
	if current_level == 0 and pmem(1) == 0 then

		if platform == "desktop" and input_mode == "gamepad" and watered_plants == 0 then

			local temp_text = "camera"
			spr(btn(7) and 287 or 271, 28, 128, 0, 1, 0, 0, 1, 1)

			if btn(7) then
				for i = 0, 3 do
					if btn(i) then
						spr(316 + i, 43, 128, 0)
						temp_text = "move"
					end
				end
			end
			if temp_text == "camera" then spr(335, 43, 128, 0) end
			Text("  +   = camera", 28, 128, 15, 1, false)
		end
		if platform == "mobile" then
			Text("Swipe to move camera", 28, 128, 15, 1, false)
		end

		if not water and camera_zoom > 7 and watered_plants == 0 then
			Text("Try collecting \nsome water", 140, 13, 15, 1, false)
		end
		if water and watered_plants == 0 then
			Text(" Water ->\n is used\n to grow plants", 140, 13, 15, 1, false)
		end
		if watered_plants > 0 then
			Text(
				watered_plants == plants
				and
				"All plants watered!  ->"
				or
				watered_plants .. " plant" ..
				(watered_plants > 1 and "s" or "")
				.. " watered ->"
				, 80, 2, 15, 1, false
			)
		end

		if platform == "mobile" then
			spr(484, 2, 118, 13, 1, 0, 0, 2, 2)
		elseif input_mode == "gamepad" then
			spr(486, 2, 118, 13, 1, 0, 0, 2, 2)
		elseif input_mode == "keyboard" then
			spr(488, 2, 118, 13, 1, 0, 0, 3, 2)
		end
	end
	if current_level == 0 and pmem(1) ~= 0 then
		if input_mode == "" then
			Text(
				"Welcome back to",
				72, 40 + ((camera_zoom - 4) * 16),
				15, 1, true)
		else
			Text(
				"Press " .. (input_mode == "keyboard" and "\n" or " ") .. "  to resume",
				75,
				clamp(
					40 + ((camera_zoom - 4) * 16),
					-50,
					136 - (input_mode == "keyboard" and 20 or 10)
				),
				15, 1, false
			)
			if input_mode == "keyboard" then
				spr(
					key(48) and 382 or 414,
					104, clamp(32 + ((camera_zoom - 4) * 16)
						, -50, 136 - 28), 13, 1, 0, 0, 1, 2
				)
				spr(
					key(48) and 383 or 415,
					140, clamp(32 + ((camera_zoom - 4) * 16)
						, -50, 136 - 28), 13, 1, 0, 0, 1, 2
				)
				for i = 1, 4 do
					spr(
						key(48) and 381 or 413,
						104 + (8 * i), clamp(32 + ((camera_zoom - 4) * 16)
						, -50, 136 - 28), 13, 1, 0, 0, 1, 2
					)
				end
				Text(
					"Space",
					108,
					clamp(
						35 + ((camera_zoom - 4) * 16) + (key(48) and 2 or 0),
						-50,
						136 - 25
					),
					6, 1, true
				)
			else
				for i = 1, 8 do
					spr(
						(btn(4) and 284 or 268) + 31,
						104 + a[i][1],
						a[i][2] + clamp(32 + ((camera_zoom - 4) * 16), -50, 136 - 18),
						0, 2, 0, 0, 1, 1
					)
				end
				spr(
					btn(4) and 284 or 268,
					104,
					clamp(32 + ((camera_zoom - 4) * 16), -50, 136 - 18),
					0, 2, 0, 0, 1, 1
				)
			end
			-- draw clear progress button
			Text(
				"Press " ..
				(input_mode == "keyboard" and "[R]" or "(X)") ..
				" \nto delete \nsaved progress",
				168, 112, 15, 1, false
			)
		end
	end
	if current_level == 1 then
		if watered_plants == 0 then
			Text("If you're stuck \nJust tap", 14, 113, 15, 1, false)
			if input_mode == "gamepad" then
				spr(btn(6) and 286 or 270, 60, 119, 0)
			else
				spr(key(18) and 382 or 414, 58, 119, 13, 1, 0, 0, 2, 2)
				Text("R", 62, 122 + (key(18) and 2 or 0), 6, 1, true)
			end
		end
		if watered_plants == 1 then
			Text(" How will we water \n the other one?", 140, 13, 15, 1, false)
		end
	end
	if current_level == 3 then
		if watered_plants == 1 and --the pot is on the platform
			(function()
				local found = get_tile(Vec.new(4, 5, 3)) == 79 or get_tile(Vec.new(6, 7, 3)) == 79
				local centre = Vec.new(6, 5, 3)
				for i = 1, 8 do
					if get_tile(centre + Vec.new(a[i][1], a[i][2], 0)) == 79 then
						found = true
					end
				end
				return not found
			end)()
		then
			Text("Is there a way to push \nthe other one up?", 0, 0, 15, 1, false)
		elseif watered_plants == 1 then
			Text("Plants push objects \nup when they grow", 0, 0, 15, 1, false)
		end
		local lfs = shuffle({ -- leaf colour should change
			{ 2, 6, 5 }, { 2, 7, 5 }, { 3, 6, 5 }, { 3, 7, 5 }, { 6, 7, 6 },
			{ 3, 8, 5 }, { 8, 9, 6 }, { 6, 8, 6 }, { 7, 7, 6 }, { 1, 8, 5 },
			{ 9, 6, 4 }, { 8, 6, 4 }, { 1, 6, 5 }, { 1, 7, 5 }, { 2, 8, 5 },
			{ 6, 9, 6 }, { 8, 8, 6 }, { 9, 5, 4 }, { 7, 9, 6 }, { 8, 7, 6 },
			{ 8, 4, 4 }, { 9, 4, 4 }, { 7, 8, 6 }, { 8, 5, 4 }, { 10, 4, 4 },
			{ 10, 5, 4 }, { 10, 6, 4 }
		})
		if watered_plants == 1 and just_watered then
			for p = 1, 9 do
				set_tile(Vec.new(lfs[p][1], lfs[p][2], lfs[p][3]), 69)
			end
		end
		if watered_plants == 2 and just_watered then
			for i, v in pairs(lfs) do
				set_tile(Vec.new(v[1], v[2], v[3]), 69)
			end
		end
	end
	if current_level == 6 then
		-- the numbers of unwatered plant found on each layer
		local found_S = { 0, 0, 0 }
		-- the numbers of watered plant found on each layer
		local found_W = { 0, 0, 0 }
		for z = 1, 3 do

			for y = 0, layer_height - 1 do
				for x = 0, layer_width - 1 do
					local p = Vec.new(x, y, z)
					if get_tile(p) == 79 then
						found_S[z] = found_S[z] + 1
					end
					if get_tile(p) == 143 then
						found_W[z] = found_W[z] + 1
					end
				end
			end

		end

		if (found_S[1] .. found_S[2] .. found_S[3]) == "111" then
			Text("It's best to make sure\nthe plants don't fall", 132, 2, 15, 1, false)
		elseif ((found_S[1] + found_W[1]) .. (found_S[2] + found_W[2]) .. (found_S[3] + found_W[3])) ~= "111" then
			Text("Oops!\n You might want \n to restart", 132, 2, 15, 1, false)
		end

	end
	if current_level == num_levels then
		if get_tile(Vec.new(9, 5, 1)) == 64 then
			pmem(1, 0)
			reset()
		end
	end

	dwatered_plants = math.min(lerp(dwatered_plants, watered_plants, 0.2), plants)
	dwater = lerp(dwater, water and 1 or 0, 0.2)
	Progressbar(190, 2, 40, dwatered_plants / plants, watered_plants == plants and 14 or 11)
	Progressbar(190, 12, 40, dwater, 10)
	if debug_mode then FPS() end
	prev_mouse = ({ mouse() })
	tics = tics + 1
end

function update_cam()
	poke(0x7FC3F, 1, 1) -- mouse capture
	local move = 0
	local zoom = 0

	if input_mode == "keyboard" then
		mouse_data = ({ mouse() })
		move = mouse_data[1]
		zoom = mouse_data[7] / 2
	elseif platform == "mobile" then
		local any_button_pressed = false
		for i = 0, 7 do
			if btn(i) then
				any_button_pressed = true
			end
		end
		if not any_button_pressed then
			mouse_data = ({ mouse() })
			local mobile_threshold = {
				move = 7,
				zoom = 2
			}
			if mouse_data[1] > mobile_threshold.move or mouse_data[1] < -mobile_threshold.move then
				move = mouse_data[1] * 0.75
			elseif mouse_data[2] > mobile_threshold.zoom or mouse_data[2] < -mobile_threshold.zoom then
				zoom = mouse_data[2] * 0.7
			end
		end
	elseif input_mode == "gamepad" and btn(7) then
		if btn(1) then zoom = 0.2 end
		if btn(0) then zoom = zoom - 0.2 end

		if btn(3) then move = 20 end
		if btn(2) then move = move - 20 end
	end

	if tcamera_incline - (zoom * (math.pi / 36)) < math.pi / 6 + math.pi / 16 then
		zoom = 0
	end
	tcamera_angle = (tcamera_angle - (move * delta_time * 0.5)) % (math.pi * 2)

	if not level_trans then
		tcamera_zoom = clamp(tcamera_zoom + zoom, 4, 16)
		tcamera_incline = clamp(
			tcamera_incline - (zoom * (math.pi / 36))
			, math.pi / 6 + math.pi / 16, math.pi / 2 - math.pi / 16
		)
	end

	if input_mode == "" then
		tcamera_angle = camera_angle + 0.3
		camera_zoom = lerp(camera_zoom, tcamera_zoom, delta_time)
		camera_angle = lerp_angle(camera_angle, tcamera_angle, delta_time * 4)
		camera_incline = lerp(camera_incline, tcamera_incline, delta_time * 2)
	else
		camera_zoom = lerp(camera_zoom, tcamera_zoom, delta_time * 2.5)
		camera_angle = lerp_angle(camera_angle, tcamera_angle, delta_time * 4)
		camera_incline = lerp(camera_incline, tcamera_incline, delta_time * 3)
	end

	cc = math.cos(camera_angle)
	ss = math.sin(camera_angle)
	phicos = math.cos(camera_incline)
	phisin = math.sin(camera_incline)
end

--VOXEL RENDERING CODE
function renderVoxelScene()
	local x1, x2, y1, y2
	for layer = 0, num_layers - 1 do
		local tile_offset = layer_map_separation * layer
		local tex_offset = 8 * tile_offset

		x1 = -layer_width * camera_zoom / 2
		x2 = layer_width * camera_zoom / 2
		y1 = -layer_height * camera_zoom / 2
		y2 = layer_height * camera_zoom / 2
		z1 = (layer + 1 - num_layers / 2) * camera_zoom
		z2 = (layer - num_layers / 2) * camera_zoom
		if cc > 0 then
			for ly = 0, layer_height - 1 do
				setTexturesToFace(tile_offset, ly, layer_width, 0, 2)
				if ss > 0 then
					for lx = 0, layer_width - 1 do
						ct = get_tile({ x = lx, y = ly, z = layer })
						if not fget(ct, 3) then
							wallQuad(x1 + camera_zoom * (1 + lx), y1 + camera_zoom * (ly), z1, x1 + camera_zoom * (1 + lx),
								y1 + camera_zoom * (1 + ly), z2, 8 * lx + 7.99 + tex_offset, 8 * ly, 8 * lx + tex_offset, 8 * ly + 7.99,
								fget(ct, 4), fget(ct, 5))
						else
							if debug_mode then nulls = nulls + 1 end
						end
					end
				else
					for lx = layer_width - 1, 0, -1 do
						ct = get_tile({ x = lx, y = ly, z = layer })
						if not fget(ct, 3) then
							wallQuad(x1 + camera_zoom * (lx), y1 + camera_zoom * (1 + ly), z1, x1 + camera_zoom * (lx),
								y1 + camera_zoom * (ly), z2, 8 * lx + tex_offset, 8 * ly, 8 * lx + 7.99 + tex_offset, 8 * ly + 7.99, fget(ct, 4)
								, fget(ct, 5))
						else
							if debug_mode then nulls = nulls + 1 end
						end
					end
				end
				setTexturesToFace(tile_offset, ly, layer_width, 0, 1)
				wallQuad(x1, y1 + camera_zoom * (ly + 1), z1, x2, y1 + camera_zoom * (ly + 1), z2, tex_offset, 8 * ly,
					8 * layer_width + tex_offset, 8 * ly + 7.99)
			end
		else
			for ly = layer_height - 1, 0, -1 do
				setTexturesToFace(tile_offset, ly, layer_width, 0, 2)
				if ss > 0 then
					for lx = 0, layer_width - 1 do
						ct = get_tile({ x = lx, y = ly, z = layer })
						if not fget(ct, 3) then
							wallQuad(x1 + camera_zoom * (1 + lx), y1 + camera_zoom * (ly), z1, x1 + camera_zoom * (1 + lx),
								y1 + camera_zoom * (1 + ly), z2, 8 * lx + 7.99 + tex_offset, 8 * ly, 8 * lx + tex_offset, 8 * ly + 7.99,
								fget(ct, 4), fget(ct, 5))
						else
							if debug_mode then nulls = nulls + 1 end
						end
					end
				else
					for lx = layer_width - 1, 0, -1 do
						ct = get_tile({ x = lx, y = ly, z = layer })
						if not fget(ct, 3) then
							wallQuad(x1 + camera_zoom * (lx), y1 + camera_zoom * (1 + ly), z1, x1 + camera_zoom * (lx),
								y1 + camera_zoom * (ly), z2, 8 * lx + tex_offset, 8 * ly, 8 * lx + 7.99 + tex_offset, 8 * ly + 7.99, fget(ct, 4)
								, fget(ct, 5))
						else
							if debug_mode then nulls = nulls + 1 end
						end
					end
				end
				setTexturesToFace(tile_offset, ly, layer_width, 0, 1)
				wallQuad(x2, y1 + camera_zoom * (ly), z1, x1, y1 + camera_zoom * (ly), z2, 8 * layer_width + tex_offset, 8 * ly,
					tex_offset, 8 * ly + 7.99)
			end
		end

		setTexturesToFace(tile_offset, 0, layer_width, layer_height, 0)

		floorQuad(x1, y1, z1, x2, y2, z1, tex_offset, 0, 8 * layer_width + tex_offset, 8 * layer_height)


	end
end

function wallQuad(x1, y1, z1, x2, y2, z2, u1, v1, u2, v2, plain, trans_enabled)
	if trans_enabled == nil then trans_enabled = true end
	if plain then
		tri(x1 * cc - y1 * ss + 120, (y1 * cc + x1 * ss) * phicos - z1 * phisin + 68, x1 * cc - y1 * ss + 120,
			(y1 * cc + x1 * ss) * phicos - z2 * phisin + 68, x2 * cc - y2 * ss + 120,
			(y2 * cc + x2 * ss) * phicos - z1 * phisin + 68, colors[ct])
		tri(x2 * cc - y2 * ss + 120, (y2 * cc + x2 * ss) * phicos - z2 * phisin + 68, x1 * cc - y1 * ss + 120,
			(y1 * cc + x1 * ss) * phicos - z2 * phisin + 68, x2 * cc - y2 * ss + 120,
			(y2 * cc + x2 * ss) * phicos - z1 * phisin + 68, colors[ct])
		if debug_mode then tris = tris + 1 end
	else
		textri(x1 * cc - y1 * ss + 120, (y1 * cc + x1 * ss) * phicos - z1 * phisin + 68, x1 * cc - y1 * ss + 120,
			(y1 * cc + x1 * ss) * phicos - z2 * phisin + 68, x2 * cc - y2 * ss + 120,
			(y2 * cc + x2 * ss) * phicos - z1 * phisin + 68, u1, v1, u1, v2, u2, v1, true, trans_enabled and transparency or -1)
		textri(x2 * cc - y2 * ss + 120, (y2 * cc + x2 * ss) * phicos - z2 * phisin + 68, x1 * cc - y1 * ss + 120,
			(y1 * cc + x1 * ss) * phicos - z2 * phisin + 68, x2 * cc - y2 * ss + 120,
			(y2 * cc + x2 * ss) * phicos - z1 * phisin + 68, u2, v2, u1, v2, u2, v1, true, trans_enabled and transparency or -1)
		if debug_mode then texs = texs + 1 end
	end
end

function floorQuad(x1, y1, z1, x2, y2, z2, u1, v1, u2, v2)
	textri(x1 * cc - y1 * ss + 120, (y1 * cc + x1 * ss) * phicos - z1 * phisin + 68, x2 * cc - y1 * ss + 120,
		(y1 * cc + x2 * ss) * phicos - z1 * phisin + 68, x1 * cc - y2 * ss + 120,
		(y2 * cc + x1 * ss) * phicos - z2 * phisin + 68, u1, v1, u2, v1, u1, v2, true, transparency)
	textri(x2 * cc - y2 * ss + 120, (y2 * cc + x2 * ss) * phicos - z2 * phisin + 68, x2 * cc - y1 * ss + 120,
		(y1 * cc + x2 * ss) * phicos - z1 * phisin + 68, x1 * cc - y2 * ss + 120,
		(y2 * cc + x1 * ss) * phicos - z2 * phisin + 68, u2, v2, u2, v1, u1, v2, true, transparency)
end

function setTexturesToFace(i1, j1, w, h, faceID)
	for i = i1, i1 + w do
		for j = j1, j1 + h do
			local tile = mget(i, j)
			mset(i, j, tile - (tile % 64) + tile % 16 + 16 * faceID)
		end
	end
end

-- PARTICLE SYSTEMS
particle_systems = {}
function make_psystem(minlife, maxlife, minstartsize, maxstartsize, minendsize, maxendsize)
	local ps = {
		-- global particle system params

		-- if true, automatically deletes the particle system if all of it's particles died
		autoremove = true,

		minlife = minlife,
		maxlife = maxlife,

		minstartsize = minstartsize,
		maxstartsize = maxstartsize,
		minendsize = minendsize,
		maxendsize = maxendsize,

		-- container for the particles
		particles = {},

		-- emittimers dictate when a particle should start
		-- they called every frame, and call emit_particle when they see fit
		-- they should return false if no longer need to be updated
		emittimers = {},

		-- emitters must initialize p.x, p.y, p.vx, p.vy
		emitters = {},

		-- every ps needs a drawfunc
		drawfuncs = {},

		-- affectors affect the movement of the particles
		affectors = {},
	}

	table.insert(particle_systems, ps)

	return ps
end

function update_psystems()
	local timenow = time()
	for key, ps in pairs(particle_systems) do
		update_ps(ps, timenow)
	end
end

function update_ps(ps, timenow)
	for key, et in pairs(ps.emittimers) do
		local keep = et.timerfunc(ps, et.params)
		if (keep == false) then
			table.remove(ps.emittimers, key)
		end
	end

	for key, p in pairs(ps.particles) do
		p.phase = (timenow - p.starttime) / (p.deathtime - p.starttime)

		for key, a in pairs(ps.affectors) do
			a.affectfunc(p, a.params)
		end

		p.x = p.x + p.vx
		p.y = p.y + p.vy

		local dead = false
		if (p.x < 0 or p.x > 240 or p.y < 0 or p.y > 136) then
			dead = true
		end

		if (timenow >= p.deathtime) then
			dead = true
		end

		if (dead == true) then
			table.remove(ps.particles, key)
		end
	end

	if (ps.autoremove == true and #ps.particles <= 0) then
		local psidx = -1
		for pskey, pps in pairs(particle_systems) do
			if pps == ps then
				table.remove(particle_systems, pskey)
				return
			end
		end
	end
end

function draw_psystems()
	for key, ps in pairs(particle_systems) do
		draw_ps(ps)
	end
end

function draw_ps(ps, params)
	for key, df in pairs(ps.drawfuncs) do
		df.drawfunc(ps, df.params)
	end
end

function deleteallps()
	for key, ps in pairs(particle_systems) do
		particle_systems[key] = nil
	end
end

function emit_particle(psystem)
	local p = {}

	local ecount = nil
	local e = psystem.emitters[math.random(#psystem.emitters)]
	e.emitfunc(p, e.params)

	p.phase = 0
	p.starttime = time()
	p.deathtime = time() + frnd(psystem.maxlife - psystem.minlife) + psystem.minlife

	p.startsize = frnd(psystem.maxstartsize - psystem.minstartsize) + psystem.minstartsize
	p.endsize = frnd(psystem.maxendsize - psystem.minendsize) + psystem.minendsize

	table.insert(psystem.particles, p)
end

-- modules
function emittimer_burst(ps, params)
	for i = 1, params.num do
		emit_particle(ps)
	end
	return false
end

function emitter_point(p, params)
	p.x = params.x
	p.y = params.y

	p.vx = frnd(params.maxstartvx - params.minstartvx) + params.minstartvx
	p.vy = frnd(params.maxstartvy - params.minstartvy) + params.minstartvy
end

function emitter_screen(p, params)
	p.ax = math.random(0, 240)
	p.ay = math.random(0, 136)

	p.x = 0
	p.y = 0
	p.vx = 0
	p.vy = 0
end

function affect_wrap(p, params)
	p.x = (p.ax + (camera_angle / (math.pi * 2)) * 240 * 2) % 240
	p.y = (p.ay - (camera_incline / (math.pi * 2)) * 136 * 4) % 136
end

function draw_ps_pix(ps, params)
	for key, p in pairs(ps.particles) do
		c = math.floor(p.phase * #params.colors) + 1
		if #params.colors == 1 then c = 1 end
		pix(p.x, p.y, params.colors[c])
	end
end

function draw_ps_streak(ps, params)
	for key, p in pairs(ps.particles) do
		c = math.floor(p.phase * #params.colors) + 1
		line(p.x, p.y, p.x - p.vx, p.y - p.vy, params.colors[c])
	end
end

-- particles
function sparks(ex, ey)
	local ps = make_psystem(1000, 2000, 0, 0, 0, 0)

	table.insert(ps.emittimers,
		{
			timerfunc = emittimer_burst,
			params = { num = 100 }
		}
	)
	table.insert(ps.emitters,
		{
			emitfunc = emitter_point,
			params = { x = ex, y = ey,
				minstartvx = -3.4, maxstartvx = 3.4,
				minstartvy = -2, maxstartvy = 2
			}
		}
	)
	table.insert(ps.drawfuncs,
		{
			drawfunc = draw_ps_pix,
			params = { colors = { 12, 14, 14, 15, 15, 15 } }
		}
	)
end

function stars()
	local ps = make_psystem(math.huge, math.huge, 0, 0, 0, 0)

	table.insert(ps.emittimers,
		{
			timerfunc = emittimer_burst,
			params = { num = 20 }
		}
	)
	table.insert(ps.emitters,
		{
			emitfunc = emitter_screen,
		}
	)
	table.insert(ps.affectors,
		{
			affectfunc = affect_wrap,
		}
	)
	table.insert(ps.drawfuncs,
		{
			drawfunc = draw_ps_pix,
			params = { colors = { 15 } }
		}
	)
end

stars()
