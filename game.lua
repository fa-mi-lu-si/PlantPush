-- title: The GARDEN
-- author: 51ftyone
-- desc: help the garden, the garden helps you
-- script: lua

--[[ TODO

hud that changes with the scale

--]]

-- voxel scene variables
	local transparency=13 --transparency mask for voxels and background colour
	local num_layers=7 --the total height of the voxel data
	local layer_width=12
	local layer_height=12
	local layer_map_separation=13
-- camera variables
	local camera_angle=math.pi*1.75
	local camera_incline=math.pi/3
	local rotate_speed = 0.15
	local scale=8 --tile size when rendered, in pixels
	local cc,ss,phicos,phisin
	cc=math.cos(camera_angle)
	ss=math.sin(camera_angle)
	phicos=math.cos(camera_incline)
	phisin=math.sin(camera_incline)
-- math
	clamp =function(n,low,high)return math.min(math.max(n,low),high)end
-- game variables
	local t=0
	start_time=time()
	coins = 0
-- tile data
	tiles = {} -- tile data

	tiles[65] = {
		name = "chest",
		run = function() coins = coins + 1  end
	}
-- level data
	levels={
		{
		},
		{
		},
		{
		},
	}

	current_level = 0

	function set_level(level)
		for i=0 , layer_height do -- for each row of the level
			memcpy(
				0x08000 + 240*i, -- dest for each row
				( 0x08000 + ((240*17)*(level)) ) + 240*i ,
				(layer_width+1) * num_layers
			)
		end
		current_level = level
	end

	set_level(1)
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
	rect(0,0,40,60,13)
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
-- keyboard
	kbd = {
		A = 01,
		B = 02,
		C = 03,
		D = 04,
		E = 05,
		F = 06,
		G = 07,
		H = 08,
		I = 09,
		J = 10,
		K = 11,
		L = 12,
		M = 13,
		N = 14,
		O = 15,
		P = 16,
		Q = 17,
		R = 18,
		S = 19,
		T = 20,
		U = 21,
		V = 22,
		W = 23,
		X = 24,
		Y = 25,
		Z = 26,

		MINUS = 37,
		EQUALS = 38,
		LEFTBRACKET = 39,
		RIGHTBRACKET = 40,
		BACKSLASH = 41,
		SEMICOLON = 42,
		APOSTROPHE = 43,
		GRAVE = 44,
		COMMA = 45,
		PERIOD = 46,
		SLASH = 47,

		SPACE = 48,
		TAB = 49,

		RETURN = 50,
		BACKSPACE = 51,
		DELETE = 52,
		INSERT = 53,

		PAGEUP = 54,
		PAGEDOWN = 55,
		HOME = 56,
		END = 57,
		UP = 58,
		DOWN = 59,
		LEFT = 60,
		RIGHT = 61,

		CAPSLOCK = 62,
		CTRL = 63,
		SHIFT = 64,
		ALT = 65,
	}
	alt_kbd={ -- alternate buttons
		W = "UP",
		A = "LEFT",
		S = "DOWN"	,
		D = "RIGHT",
	}
	for i=0,9 do
		kbd[i]=27+i
	end
--

player = {
	pos = {x=15,y=5},
	update = function(self)
		local dp = {x=0,y=0} -- the direction the player wants to move

		-- map keyboard buttons to directions based on camera rotation
		local r = math.floor((((camera_angle+(math.pi/4))%(math.pi*2))/(math.pi*2))*4)
		local n,s,e,w
		if r == 0 then n="W";s="S";e="A";w="D" elseif r == 1 then n="D";s="A";e="W";w="S" elseif r == 2 then n="S";s="W";e="D";w="A" elseif r == 3 then n="A";s="D";e="S";w="W" end

		if keyp(kbd[n]) or keyp(kbd[alt_kbd[n]]) then
			dp.y=-1
		elseif keyp(kbd[s]) or keyp(kbd[alt_kbd[s]]) then
			dp.y=1
		elseif keyp(kbd[e]) or keyp(kbd[alt_kbd[e]]) then
			dp.x=-1
		elseif keyp(kbd[w]) or keyp(kbd[alt_kbd[w]]) then
			dp.x=1
		end

		local target_pos = {x = self.pos.x+dp.x , y = self.pos.y+dp.y} -- the position the player wants to move into
		local target_tile = mget(target_pos.x,target_pos.y) -- the tile in the target position

		if not fget(target_tile, 0) then -- solid tiles have flag 0 red
			mset(self.pos.x,self.pos.y,0) -- clear where the player is
			self.pos = target_pos
			mset(self.pos.x,self.pos.y,64) -- draw the player in it's new position
		end
		if fget(target_tile, 1) then -- interactable tiles have flag 1 orange
			tiles[target_tile].run()
		end
	end
}

function TIC()
	np=time() et=np-lp lp=np -- part of FPS debug

	delta_time=(time()-start_time)*0.001
	start_time=time()
	mouse:update()

	-- update game
	update_cam()
	player:update()
	if btnp(5) then
		set_level(current_level+1 > #levels and 1 or current_level+1)
	end

	--render game
	cls(transparency)
	poke(0x03FF8,transparency)
	renderVoxelScene()

	Text(
		"X : " .. player.pos.x .."\n"..
		"Y : " .. player.pos.y .."\n"..
		"Coins : " .. coins .."\n"
	,180,0,false)
	FPS()
	t=t+1
end


mouse={
	x=0, y=0, -- movement
	fetch_data = mouse,
	sx=0, sy=0, -- scroll

	update = function (self)
		poke(0x7FC3F,1,1) -- mouse capture
		poke(0x03FFB,0) -- hide the cursor

		self.x, self.y, -- position
		self.L, self.M, self.R, -- buttons
		self.sx,self.sy
		= mouse.fetch_data() -- mouse reurns all nececary values

	end,
}
function update_cam()
	camera_incline = clamp(camera_incline - (mouse.y * delta_time * rotate_speed),0,math.pi/2)
	camera_angle = (camera_angle - (mouse.x * delta_time * rotate_speed)) % (math.pi*2)
	scale = clamp(scale+mouse.sy,4,16)

	cc=math.cos(camera_angle)
	ss=math.sin(camera_angle)
	phicos=math.cos(camera_incline)
	phisin=math.sin(camera_incline)
end

--VOXEL RENDERING CODE
	function renderVoxelScene()
		local x1,x2,y1,y2,z
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