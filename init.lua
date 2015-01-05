local load_time_start = os.clock()

local singleplayer,log = minetest.is_singleplayer()
if singleplayer then
	function log(txt)
		minetest.log(txt)
		minetest.chat_send_all(txt)
	end
else
	function log(txt)
		minetest.log(txt)
	end
end

-- gets content ids
local c_air, c_ignore, c_stone, done
local function load_contents()
	if done then
		return
	end
	c_air = minetest.get_content_id("air")
	c_ignore = minetest.get_content_id("ignore")
	c_stone = minetest.get_content_id("default:stone")
	done = true
end

-- gets the lowest allowed height
local bottom
local function get_bottom(y)
	if y > 50 then
		bottom = y-50
	elseif y > 0 then
		bottom = 0
	else
		bottom = y
	end
end

local width

local function is_surrounded(data, area, x,y,z, pos)
	if x >= pos.x-1
	and x <= pos.x+1
	and z >= pos.z-1
	and z <= pos.z+1 then
		return false
	end
	for i = -1,1,2 do
		for _,s in pairs({{x+i,y,z}, {x,y+i,z}, {x,y,z+i}}) do
			local x,y,z = unpack(s)
			local nd = data[area:index(x,y,z)]
			if nd == c_air
			or nd == c_ignore then
				return false
			end
		end
	end
	return true
end

-- gets the environment
local exs_solids = {}
local function get_solids_around(pos, h)
	log("searching environment…")
	local min = vector.subtract(pos, width)
	local max = vector.add(pos, width)
	min.y = bottom
	max.y = h

	local manip = minetest.get_voxel_manip()
	local e1, e2 = manip:read_from_map(min, max)
	local area = VoxelArea:new({MinEdge=e1, MaxEdge=e2})
	local data = manip:get_data()

	load_contents()
	local count = 0
	for z = min.z,max.z do
		for y = min.y,max.y do
			for x = min.x,max.x do
				local nd = data[area:index(x,y,z)]
				if nd ~= c_air
				and nd ~= c_ignore
				and not is_surrounded(data, area, x,y,z, pos) then
					exs_solids[x-pos.x.." "..y-pos.y.." "..z-pos.z] = true
					count = count+1
				end
			end
		end
	end
	log(count.." solids found")
end

-- current solids
local hard_nds = {}

-- current liquids
local flows = {w={}, l={}}

-- get a solid
local function is_hard(x,y,z)
	local maxv = math.max(math.abs(x), math.abs(z))
	if maxv > width then
		return true
	end
	if y < bottom then
		return true
	end
	--[[local dist = math.hypot(x,z)
	if dist > hole_size then
		return true
	end
	local v = hole_size/(hole_size-dist)-5
	if y <= hole_size/(hole_size-dist)-5 then
		return true
	end
	if math.random(2) == 1
	and y <= hole_size/(hole_size-dist*2)-5 then
		return true
	end]]
	local pstr = x.." "..y.." "..z
	if exs_solids[pstr]
	or hard_nds[pstr] then
		return true
	end
	return false
end

-- sets the tower for the volcano
local function get_tower(h)
	log("creating tower…")
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
	for i = -1,1 do
		for j = -1,1 do
			for k = -1,1 do
				if flows.w[x+i.." "..y+j.." "..z+k] then
					return true
				end
			end
		end
		--[[for _,s in pairs({x+i.." "..y.." "..z, x.." "..y+i.." "..z, x.." "..y.." "..z+i}) do
			if flows.w[s] then
				return true
			end
		end]]
	end
	return false
end

-- cools the lava
local function cool()
	log("cooling…")
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
	log("flowing "..a.."…")
	local b = inverts[a]
	flows[a]["0 "..y.." 0"] = 8
	local todo = {{0,y,0}}
	while todo[1] do
		for n,current in pairs(todo) do
			local x,y,z = unpack(current)
			y = y-1
			if not is_hard(x,y,z)
			and not flows[b][x.." "..y.." "..z] then
			-- it flows a bit down if air is under it
				local l = 1
				for i = y-1,y-500,-1 do
					if is_hard(x,i,z)
					or flows[b][x.." "..i.." "..z] then
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
				flows[a][x.." "..y.." "..z] = 8
				table.insert(todo, {x,y,z})
			else
				y = y+1
				local v = flows[a][x.." "..y.." "..z] - 1
				if v > 0 then
				-- it spreads if its param is > 1
					for _,d in pairs({{-1,0}, {2,0}, {-1,1}, {0,-2}}) do
						x = x+d[1]
						z = z+d[2]
						local pstr = x.." "..y.." "..z
						if not flows[b][pstr]
						and not is_hard(x,y,z) then
							local cv = flows[a][pstr]
							if not cv
							or cv < v then
								flows[a][pstr] = v
								table.insert(todo, {x,y,z})
							end
						end
					end
				end
			end
			todo[n] = nil
		end
	end
end

-- creates one
local function spawn_volcano(pos, h)
	width = h*2
--	width = h*8

-- gets the bottom position
	get_bottom(pos.y)

-- sets the "tower"
	get_tower(h-2)

-- gets environment
	get_solids_around(pos, h)

-- calculates the mountain
	width = h
	local ending
	local lq = "w"
	for y = 1,h,2 do
		if not ending
		and y <= h-2 then
			ending = true
			width = h*2
		end
		flow_lq(y, lq)
		cool()
		--[[if lq == "l" then
			flow_lq(y-2, "w")
			flow_lq(y, lq)
			cool()
		end]]
		lq = inverts[lq]
	end

-- reset current liquids
	flows = {w={}, l={}}

-- reset current environment info
	exs_solids = {}

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

-- reset current solids
	hard_nds = {}

-- places the mountain
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(min, max)
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local data = manip:get_data()

	load_contents()
	for _,p in pairs(ps) do
		p = area:index(p[1], p[2], p[3])
		if data[p] == c_air then
			data[p] = c_stone
		end
	end

	manip:set_data(data)
	manip:write_to_map()
	manip:update_map()
end


local function chatcmd(name)
	if not name
	or name == "" then
		return
	end
	local pos = vector.round(minetest.get_player_by_name(name):getpos())
	log("spawning mountain")
	spawn_volcano(pos, 50)
	log("done")
end

minetest.register_chatcommand('vulkan',{
	description = 'MAUNTEN',
	params = "",
	privs = {},
	func = chatcmd
})





minetest.log("info", string.format("[vulkane] loaded after ca. %.2fs", os.clock() - load_time_start))
