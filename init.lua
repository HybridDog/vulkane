-- current solids
local hard_nds = {}

-- current liquids
local flows = {w={}, l={}}

-- get a solid
local function is_hard(x,y,z)
	if y <= -5 then
		return true
	end
	return hard_nds[x.." "..y.." "..z] or false
end

-- sets the tower for the volcano
local function get_tower(h)
	for y = 0,h,2 do
		for x = -2,2 do
			for z = -2,2 do
				if math.random(2) == 1 then
					hard_nds[x.." "..y.." "..z] = true
				end
			end
		end
	end
end

-- searches for water around it
local function find_water(p)
	local x,y,z = unpack(string.split(p, " "))
	for i = -1,1,2 do
		for _,s in pairs({x+i.." "..y.." "..z, x.." "..y+i.." "..z, x.." "..y.." "..z+i}) do
			if flows.w[s] then
				return true
			end
		end
	end
end

-- cools the lava
local function cool()
	for p in pairs(flows.l) do
		if find_water(p) then
			flows.l[p] = nil
			hard_nds[p] = true
		end
	end
end

-- the opposite liquids
local inverts = {w="l", l="w"}

-- simulates a liquid flowing down
local function flow_lq(y, a)
	local b = inverts[a]
	flows[a]["0 "..y.." 0"] = 9
	local todos = {{0,y,0}}
	while todo[1] do
		for n,current in pairs(todo) do
			local x,y,z = unpack(current)
			y = y-1
			if not is_hard(x,y,z)
			and not flows[b][x.." "..y.." "..z] then
			-- it flows a bit down if air is under it
				local l = 1
				for i = y-1,y-500,-1 do
					if is_hard(x,i,z) then
						break
					end
					l = l+1
				end
				y = y+1
				if l ~= 1 then
					local l = l
					if a == "l" then
					-- lava doesn't somehow stops in air
						l = math.floor(l/math.random(1,l)+0.5)
					end
					for i = 1,l do
						flows[a][x.." "..y-i.." "..z] = 1
					end
				end
				y = y-l
				flows[a][x.." "..y.." "..z] = 9
				table.insert(todo, {x,y,z})
			else
				y = y+1
				local v = flows[a][x.." "..y.." "..z] - 1
				if v > 0 then
				-- it spreads if its param is > 1
					for _,d in pairs({-1,0}, {2,0}, {-1,1}, {0,-2}) do
						x = x+d[1]
						z = z+d[2]
						local cv = flows[a][x.." "..y.." "..z]
						if cv < v then
							flows[a][x.." "..y.." "..z] = v
							table.insert(todo, {x,y,z})
						end
					end
				end
			end
			todo[n] = nil
		end
	end
end

local c_air, c_stone, done
local function load_contents()
	if done then
		return
	end
	c_air = minetest.get_content_id("air")
	c_stone = minetest.get_content_id("default:stone")
	done = true
end

-- creates one
local function spawn_volcano(pos, h)
-- reset current solids
	hard_nds = {}

-- reset current liquids
	flows = {w={}, l={}}

-- sets the "tower"
	get_tower(h)

-- calculates the mountain
	local lq = "w"
	for y = 1,h+1,2 do
		flow_lq(y, lq)
		cool()
		lq = inverts[lq]
	end

-- gets informations
	local ps,n = {},1
	local min = vector.new(pos)
	local max = vector.new(pos)
	for p in pairs(hard_nds) do

	-- get coordinates
		local x,y,z = unpack(string.split(p, " "))
		x = x+pos.x
		y = y+pos.y
		z = z+pos.z

	-- update min and max position
		min.x = math.min(min.x,x)
		min.y = math.min(min.y,y)
		min.z = math.min(min.z,z)
		max.x = math.max(max.x,x)
		max.y = math.max(max.y,y)
		max.z = math.max(max.z,z)

	-- put it into another table
		ps[n] = {x,y,z}
		n = n+1
	end

-- places the mountain
	load_contents()
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(min, max)
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	for _,p in pairs(ps) do
		p = area:index(p[1], p[2], p[3])
		if data[p] == c_air then
			data[p] = c_stone
		end
	end

	manip:set_data(nodes)
	manip:write_to_map()
	manip:update_map()
end








