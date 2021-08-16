-- title: The GARDEN
-- author: 51ftyone
-- desc: help the garden, the garden helps you
-- script: lua

-- voxel scene variables
	local transparency=13 --transparency mask for voxels and background colour
	local num_layers=7 --the total height of the voxel data
	local layer_width=12
	local layer_height=12
	local layer_map_separation=13

-- camera variables
	camera_angle=math.pi
	camera_incline=0
	scale=0

	-- used for smooth movement
	tcamera_angle=math.pi*1.75
	tcamera_incline=math.pi*0.3
	tscale = 8

-- math
	function clamp(n,low,high)return math.min(math.max(n,low),high)end
	function lerp(a,b,t) return (1-t)*a + t*b end
	function lerp_angle(a, b, t)
		local function rotate(point,angle)return {x=(point.x*math.cos(angle)-point.y*math.sin(angle)),y=(point.y*math.cos(angle)+point.x*math.sin(angle))}end
		local a_vec = rotate({x=0,y=-100},a) b_vec = rotate({x=0,y=-100},b)
		local lerped_vec = {x=lerp(a_vec.x,b_vec.x,t),y=lerp(a_vec.y,b_vec.y,t)}
		return math.pi-math.atan2(lerped_vec.x,lerped_vec.y)
	end

-- game variables
	local t=0
	start_time=time()
	current_level = 0
	watered_plants = 0
	water = 0
	max_water = 3

	-- used for smooth ui animations
	dwatered_plants = 0
	dwater = 0

-- tile data
	tiles = {} -- tile data

	tiles[15] = {
		name = "plant_pot_2",
		run = function(pos)
			if water < 1 then return end

			tile_above = get_tile({x=pos.x,y=pos.y,z=pos.z+1})
			if fget(tile_above,0) then return end

			set_tile({x=pos.x,y=pos.y,z=pos.z+1},128)
			watered_plants = watered_plants + 1
			water = water-1
		end
	}
	tiles[79] = {
		name = "plant_pot_1",
		run = function(pos)
			if water < 1 then return end

			tile_above = get_tile({x=pos.x,y=pos.y,z=pos.z+1})
			if fget(tile_above,0) then return end

			set_tile({x=pos.x,y=pos.y,z=pos.z+1},128)
			set_tile(pos,15)
			watered_plants = watered_plants + 1
			water = water-1
		end
	}
	tiles[14] = {
		name = "bucket",
		run = function(pos)
			if water < max_water then
				water = water+1
				set_tile(pos,13)
			end
		end
	}
	tiles[77] = {
		name = "portal",
		run = function(pos)
			if current_level == #levels then return end
			set_level(current_level+1)
		end
	}

	push_tile = function (pos,direction)

		local target_pos = {
			x = pos.x+direction.x,
			y = pos.y+direction.y,
			z = pos.z+direction.z
		}
		if -- if the target position is out of the level
			target_pos.x < 0 or target_pos.x > layer_width-1
			or target_pos.y < 0 or target_pos.y > layer_height-1
			or target_pos.z < 0 or target_pos.z > num_layers-1
		then
			return
		end
		local target_tile = get_tile(target_pos)


		if fget(target_tile,2) then -- pushable tiles have flag 2 yellow
			push_tile(target_pos,direction)
			target_tile = get_tile(target_pos) -- update the target_tile
		end

		if not fget(target_tile,0) then
			set_tile(target_pos,get_tile(pos))
			set_tile(pos,0)
		end
	end

	function game_to_map(game_pos)
		return {
			x = game_pos.x + (game_pos.z * (layer_width+1)),
			y = game_pos.y
		}
	end
	function map_to_game(map_pos)
		return {
			x = map_pos.x % (layer_width+1),
			y = map_pos.y,
			z = map_pos.x // (layer_width+1)
		}
	end
	function get_tile(pos)
		map_pos = game_to_map(pos)
		return mget(map_pos.x,map_pos.y)
	end
	function set_tile(pos,tile)
		map_pos = game_to_map(pos)
		mset(map_pos.x,map_pos.y,tile)
	end

-- level data
	levels={
		{
			plants = 8
		},
		{
			plants = 1
		},
		{
			plants = 1
		},
		{
			plants = 7
		},
	}

	function set_level(level)

		-- reset the camera
		camera_angle=math.pi
		tcamera_angle=math.pi*1.75
		camera_incline=0
		tcamera_incline=math.pi*0.3
		scale=0
		tscale = 8

		-- reset the game
		watered_plants = 0
		water = 0
		player.pos = {x=2,y=5,z=1}

		-- copy the map data
		for i=0 , layer_height do -- for each row of the level
			memcpy(
				0x08000 + 240*i, -- dest for each row
				( 0x08000 + ((240*17)*(level)) ) + 240*i ,
				(layer_width+1) * num_layers
			)
		end
		current_level = level
	end

-- debug stuff
	lp=0
	np=0
	etg={}
	for i=1,20 do table.insert(etg,0) end
	fps=0
	function FPS()
		if t%12==0 then
			for i=1,19 do
			etg[i]=etg[i+1]
			end
			etg[20]=math.floor(et)
			fps=math.floor(1/(et/1000))
		end
		if fps>60 then fps=60 end
	print("FPS:",5,5,10)
	print(fps,26,5,15)
		rect(4,11,13,7,0)
		print("et:",5,12)
		rect(18,11,21,1,15)
		rect(38,11,1,etg[20]/2+1,9)
		for i=1,20 do
		local c=11
			if etg[i]>20 then c=7 end
			if etg[i]>30 then c=4 end
			if etg[i]>50 then c=2 end
		rect(17+i,12,1,etg[i]/2,c)
		end
		print(math.floor(1000/fps),19,13)
		pix(37,etg[20]/2+11,9)
	end

-- graphics
	function Text(text,x,y,alt)
		local keep = peek4(2*0x03FFC)
		poke4(2*0x03FFC,8)
		font(text,x,y,0,5,8,false,1,alt)
		poke4(2*0x03FFC, keep)
	end
	function Progressbar(x,y,width,height,progress,color)
		rect(x,y,width,height,13) -- background
		rect(x+1,y+1,progress*(width-2),height-2,color) -- progressbar
		line(x+1+(progress*(width-2)),y+1,x+1+(progress*(width-2)),y+height-2,15) -- line showing progress
	end

-- input
	input_mode = "gamepad"

	kbd = {
		W = 23,
		A = 01,
		S = 19,
		D = 04,
		aW = 58,
		aA = 60,
		aS = 59,
		aD = 61,
		Jump = 48,
		Restart = 18,
	}
	btns = {
		W = 0,
		A = 2,
		S = 1,
		D = 3,
		aW = 0,
		aA = 2,
		aS = 1,
		aD = 3,
		Jump = 4,
		Restart = 7,
	}

	function input(action)
		if input_mode == "keyboard" then
			return keyp(kbd[action])
		else
			return btnp(btns[action]) and not btn(6)
		end
	end
--

player = {
	pos = {x=2,y=5,z=1},

	jumping = false,
	jump_allowed = true,

	update = function(self)

		-- check for input
		local dp = {x=0,y=0,z=0} -- the direction the player wants to move

		if fget(get_tile({x=self.pos.x,y=self.pos.y,z=self.pos.z-1}),0) then -- if the player is on solid ground
			self.jump_allowed = true
			self.jumping = false
		else
			if not self.jumping then
				self.jump_allowed = false
				dp.z = -1
			end
		end

		if input("Jump") and self.jump_allowed then
			dp.z = 1
			self.jumping = true
			self.jump_allowed = false
		end

		-- map keyboard buttons to directions based on camera rotation
		local r = math.floor((((camera_angle+(math.pi/4))%(math.pi*2))/(math.pi*2))*4)
		local n,s,e,w -- directons
		if r == 0 then n="W"s="S"e="A"w="D" elseif r == 1 then n="D"s="A"e="W"w="S" elseif r == 2 then n="S"s="W"e="D"w="A" elseif r == 3 then n="A"s="D"e="S"w="W" end

		local moved = true
		if input(n) or input("a"..n) then
			dp.y=-1
		elseif input(s) or input("a"..s) then
			dp.y=1
		elseif input(e) or input("a"..e) then
			dp.x=-1
		elseif input(w) or input("a"..w) then
			dp.x=1
		else
			moved = false
		end

		if moved then
			self.jumping = false
		end

		local target_pos = {
			x = clamp(self.pos.x+dp.x,0,layer_width-1) ,
			y = clamp(self.pos.y+dp.y,0,layer_height-1) ,
			z = clamp(self.pos.z+dp.z,0,num_layers-1)
		}
		local target_tile = get_tile(target_pos)

		if fget(target_tile,2) then -- pushable tiles have flag 2 yellow
			push_tile(target_pos,dp)
			target_tile = get_tile(target_pos) -- update the target_tile
		end

		if fget(target_tile, 1) then -- interactable tiles have flag 1 orange
			tiles[target_tile].run(target_pos)
			target_tile = get_tile(target_pos) -- just in case it changed
		end

		if not fget(target_tile, 0) then -- solid tiles have flag 0 red
			self:move(target_pos)
		end

	end,

	move = function(self,pos)
		set_tile(self.pos,0) -- clear where the player is
		self.pos = pos
		set_tile(self.pos,64) -- draw the player in it's new position
	end
}

-- initialise the game
	set_level(1)
--

function TIC()
	np=time() et=np-lp lp=np -- part of FPS debug

	delta_time=(time()-start_time)*0.001
	start_time=time()

	-- update game
	update_cam()
	if btnp(5) then
		set_level(current_level+1 > #levels and 1 or current_level+1)
	end
	if input("Restart") then set_level(current_level) end
	
	fset(14,2,water >= max_water) -- buckets should be pushable when water is full
	player:update()

	-- spawn a portal when all plants are watered
	if watered_plants == levels[current_level].plants then
		set_tile({x=2,y=5,z=1},77)
	end

	-- iterate over all the tiles in the game
	for x=0 , layer_width-1 do
		for y=0 , layer_height-1 do
			for z=0, num_layers-1 do
				local pos = {x=x,y=y,z=z}
				local tile = get_tile(pos)

				if fget(tile,6) or fget(tile,2) then -- flags 6 (dark blue) means that a block can be affected by gravity
					push_tile(pos,{x=0,y=0,z=-1})
				end

				if tile == 14 and get_tile({x=x,y=y,z=z+1}) == 79 then --if a plant pot is over a bucket
					water = water+1 -- temporarily increase the water
					tiles[79].run({x=x,y=y,z=z+1}) -- try to water the plant

					if get_tile({x=x,y=y,z=z+1}) == 15 then -- if the plant was watered
						set_tile(pos,13)
					else
						water = water-1
					end
				end
			end
		end
	end

	--render game
	cls(transparency)
	poke(0x03FF8,transparency)
	renderVoxelScene()
	dwatered_plants = math.min(lerp(dwatered_plants,watered_plants,0.2),levels[current_level].plants)
	dwater = lerp(dwater,water,0.2)
	Progressbar(230-40,2,40,5,dwatered_plants/levels[current_level].plants, watered_plants == levels[current_level].plants and 14 or 11)
	Progressbar(230-40,10,40,5,dwater/max_water,9)
	-- FPS()
	t=t+1
end


function update_cam()
	local move = {0,0}
	local zoom = 0

	if input_mode == "keyboard" then
		poke(0x7FC3F,1,1) -- mouse capture
		mouse_data = ({mouse()})
		move = {mouse_data[1],mouse_data[2]}
		zoom = mouse_data[7]
	elseif btn(6) then
		if btn(1) then move[2] = 10 end
		if btn(0) then move[2] = move[2] - 10 end

		if btn(3) then move[1] = 20 end
		if btn(2) then move[1] = move[1] - 20 end
		
		if btnp(5) then zoom = 1 end
		if btnp(4) then zoom = zoom - 1 end
	end

	tcamera_incline = clamp(tcamera_incline - (move[2] * delta_time * 0.15),0,math.pi/2)
	tcamera_angle = (tcamera_angle - (move[1] * delta_time * 0.15)) % (math.pi*2)
	tscale= clamp(tscale+zoom,4,16)

	scale = lerp(scale,tscale,delta_time*4)
	camera_angle = lerp_angle(camera_angle,tcamera_angle,delta_time*4)
	camera_incline = lerp_angle(camera_incline,tcamera_incline,delta_time*4)

	cc=math.cos(camera_angle)
	ss=math.sin(camera_angle)
	phicos=math.cos(camera_incline)
	phisin=math.sin(camera_incline)
end

--VOXEL RENDERING CODE
	function renderVoxelScene()
		local x1,x2,y1,y2
		for layer=0,num_layers-1 do
			local tile_offset=layer_map_separation*layer
			local tex_offset=8*tile_offset

			x1=-layer_width*scale/2
			x2=layer_width*scale/2
			y1=-layer_height*scale/2
			y2=layer_height*scale/2
			z1=(layer+1-num_layers/2)*scale
			z2=(layer-num_layers/2)*scale
			if cc>0 then
				for ly=0,layer_height-1 do
					setTexturesToFace(tile_offset,ly,layer_width,0,2)
					if ss>0 then
						for lx=0,layer_width-1 do
							if mget(tile_offset+lx,ly)>0 then
								wallQuad(x1+scale*(1+lx),y1+scale*(ly),z1,x1+scale*(1+lx),y1+scale*(1+ly),z2,8*lx+7.99+tex_offset,8*ly,8*lx+tex_offset,8*ly+7.99)
							end
						end
					else
						for lx=layer_width-1,0,-1 do
							if mget(tile_offset+lx,ly)>0 then
								wallQuad(x1+scale*(lx),y1+scale*(1+ly),z1,x1+scale*(lx),y1+scale*(ly),z2,8*lx+tex_offset,8*ly,8*lx+7.99+tex_offset,8*ly+7.99)
							end
						end
					end
					setTexturesToFace(tile_offset,ly,layer_width,0,1)
					wallQuad(x1,y1+scale*(ly+1),z1,x2,y1+scale*(ly+1),z2,tex_offset,8*ly,8*layer_width+tex_offset,8*ly+7.99)
				end
			else
				for ly=layer_height-1,0,-1 do
					setTexturesToFace(tile_offset,ly,layer_width,0,2)
					if ss>0 then
						for lx=0,layer_width-1 do
							if mget(tile_offset+lx,ly)>0 then
								wallQuad(x1+scale*(1+lx),y1+scale*(ly),z1,x1+scale*(1+lx),y1+scale*(1+ly),z2,8*lx+7.99+tex_offset,8*ly,8*lx+tex_offset,8*ly+7.99)
							end
						end
					else
						for lx=layer_width-1,0,-1 do
							if mget(tile_offset+lx,ly)>0 then
								wallQuad(x1+scale*(lx),y1+scale*(1+ly),z1,x1+scale*(lx),y1+scale*(ly),z2,8*lx+tex_offset,8*ly,8*lx+7.99+tex_offset,8*ly+7.99)
							end
						end
					end
					setTexturesToFace(tile_offset,ly,layer_width,0,1)
					wallQuad(x2,y1+scale*(ly),z1,x1,y1+scale*(ly),z2,8*layer_width+tex_offset,8*ly,tex_offset,8*ly+7.99)
				end
			end

			setTexturesToFace(tile_offset,0,layer_width,layer_height,0)

			floorQuad(x1,y1,z1,x2,y2,z1,tex_offset,0,8*layer_width+tex_offset,8*layer_height)


		end
	end
	function wallQuad(x1,y1,z1,x2,y2,z2,u1,v1,u2,v2)
		textri(x1*cc-y1*ss+120,(y1*cc+x1*ss)*phicos-z1*phisin+68,x1*cc-y1*ss+120,(y1*cc+x1*ss)*phicos-z2*phisin+68,x2*cc-y2*ss+120,(y2*cc+x2*ss)*phicos-z1*phisin+68,u1,v1,u1,v2,u2,v1,true,transparency)
		textri(x2*cc-y2*ss+120,(y2*cc+x2*ss)*phicos-z2*phisin+68,x1*cc-y1*ss+120,(y1*cc+x1*ss)*phicos-z2*phisin+68,x2*cc-y2*ss+120,(y2*cc+x2*ss)*phicos-z1*phisin+68,u2,v2,u1,v2,u2,v1,true,transparency)
	end
	function floorQuad(x1,y1,z1,x2,y2,z2,u1,v1,u2,v2)
		textri(x1*cc-y1*ss+120,(y1*cc+x1*ss)*phicos-z1*phisin+68,x2*cc-y1*ss+120,(y1*cc+x2*ss)*phicos-z1*phisin+68,x1*cc-y2*ss+120,(y2*cc+x1*ss)*phicos-z2*phisin+68,u1,v1,u2,v1,u1,v2,true,transparency)
		textri(x2*cc-y2*ss+120,(y2*cc+x2*ss)*phicos-z2*phisin+68,x2*cc-y1*ss+120,(y1*cc+x2*ss)*phicos-z1*phisin+68,x1*cc-y2*ss+120,(y2*cc+x1*ss)*phicos-z2*phisin+68,u2,v2,u2,v1,u1,v2,true,transparency)
	end
	function setTexturesToFace(i1,j1,w,h,faceID)
		for i=i1,i1+w do
			for j=j1,j1+h do
				local tile=mget(i,j)
				mset(i,j,tile-(tile%64)+tile%16+16*faceID)
			end
		end
	end