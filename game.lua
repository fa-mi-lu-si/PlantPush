-- title:  voxel renderer
-- author: petet
-- desc:   build voxel scenes in the map editor
-- script: lua

--[[ TODO

change levels
hud that changes with the scale

--]]

-- voxel scene variables
	local transparency=13 --transparency mask for all voxels
	local num_layers=6 --the total height of the voxel data
	local layer_width=12
	local layer_height=12
	local layer_map_separation=13
-- camera variables
	local camera_angle=math.pi/6
	local camera_incline=math.pi/3
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
-- level data
	levels={
		{
			bg=13,
			bgspr=0,
		},
	}
--

player = {
	pos = {x=15,y=5},
	update = function(self)
		dp = {x=0,y=0}

		r = math.floor((((camera_angle+(math.pi/4))%(math.pi*2))/(math.pi*2))*4)
		if r == 0 then n=0;s=1;e=2;w=3 elseif r == 1 then n=3;s=2;e=0;w=1 elseif r == 2 then n=1;s=0;e=3;w=2 elseif r == 3 then n=2;s=3;e=1;w=0 end

		if btnp(n) then dp.y=-1
		elseif btnp(s) then dp.y=1
		elseif btnp(e) then dp.x=-1
		elseif btnp(w) then dp.x=1 end

		mset(self.pos.x,self.pos.y,0) -- clear where the player is

		if mget(self.pos.x+dp.x,self.pos.y+dp.y)==0 then
			self.pos.x = self.pos.x+dp.x
			self.pos.y = self.pos.y+dp.y
		end

		mset(self.pos.x,self.pos.y,64) -- draw the player in it's new position
	end
}

function TIC()
	delta_time=(time()-start_time)*0.001
	start_time=time()
	mouse:update()

	-- update game
	update_cam()
	player:update()

	--render game
	cls(transparency)
	poke(0x03FF8,transparency)
	poke(0x03FFB,0) -- hide the cursor
	renderVoxelScene()

	t=t+1
end


mouse={ -- a better interface to the TIC-80 mouse
	pos={x=0,y=0}, -- mouse position on screen
	fetch_data = mouse,
	scroll = {x=0,y=0},

	update = function (self)

		self.pos.x, self.pos.y, -- position
		self.L, self.M, self.R, -- buttons
		self.scroll.x,self.scroll.y
		= mouse.fetch_data() -- mouse reurns all nececary values

		-- a small bugfix
		if self.pos.x == 255 then self.pos.x = 0 end
		if self.pos.y == 255 then self.pos.y = 0 end
		self.pos.x = clamp(self.pos.x,0,240)
		self.pos.y = clamp(self.pos.y,0,136)
	end,
}
function update_cam()
	camera_incline = (1-(mouse.pos.y/136))*(math.pi/2)
	camera_angle = ((1-(mouse.pos.x/240))*2)*(math.pi*2)
	scale = clamp(scale+mouse.scroll.y,4,32)

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