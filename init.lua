local load_time_start = os.clock()

local log
if minetest.is_singleplayer() then
	function log(txt)
		minetest.log("action", txt)
		minetest.chat_send_all(txt)
	end
else
	function log(txt)
		minetest.log("action", txt)
	end
end

-- gets content ids
local c_air, c_stone, done
local function load_contents()
	if done then
		return
	end
	c_air = minetest.get_content_id"air"
	--~ c_ignore = minetest.get_content_id"ignore"
	c_stone = minetest.get_content_id"default:stone"
	done = true
end

-- gets the lowest allowed height
local bottom, bottom_rel
local function get_bottom(y)
	bottom = y-100
	bottom_rel = bottom-y
end

local function is_surrounded(data, area, x,y,z)
	--[[if x >= pos.x-1
	and x <= pos.x+1
	and z >= pos.z-1
	and z <= pos.z+1 then
		return false
	end--]]
	--for i = -1,1,2 do
		--[[for _,s in pairs({{x+i,y,z}, {x,y+i,z}, {x,y,z+i}}) do
			local x,y,z = unpack(s)
			local nd = data[area:index(x,y,z)]
			if nd == c_air
			or nd == c_ignore then
				return false
			end
		end]]
	local vi = area:index(x,y,z)
	for i = -1,1,2 do
		if data[vi + i] == c_air
		or data[vi + i * area.ystride] == c_air
		or data[vi + i * area.zstride] == c_air then
			return false
		end
	end
	return true
end

local function save(t, z, y, x, v)
	t[minetest.hash_node_position{x=x, y=y, z=z}] = v
end
local function get(t, z, y, x)
	return t[minetest.hash_node_position{x=x, y=y, z=z}]
end

local width

-- gets the environment
local exs_solids = {}
local function get_solids_around(pos, h)
	log"searching environment…"
	local min = vector.subtract(pos, width)
	local max = vector.add(pos, width)
	min.y = bottom
	max.y = pos.y+h

	local manip = minetest.get_voxel_manip()
	local e1, e2 = manip:read_from_map(min, max)
	local area = VoxelArea:new{MinEdge=e1, MaxEdge=e2}
	local data = manip:get_data()

	load_contents()

	local pz,py,px = pos.z, pos.y, pos.x
	local minz,miny,minx = min.z, min.y, min.x
	local maxz,maxy,maxx = max.z, max.y, max.x

	local count = 0
	for z = minz,maxz do
		for y = miny,maxy do
			for x = minx,maxx do
				--local nd = data[area:index(x,y,z)]
				if data[area:index(x,y,z)] ~= c_air
				--and nd ~= c_ignore
				and not is_surrounded(data, area, x,y,z) then
					save(exs_solids, z-pz,y-py,x-px, true)
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
	if math.max(math.abs(x), math.abs(z)) > width
	or y < bottom_rel then
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
	return get(exs_solids, z,y,x)
		or get(hard_nds, z,y,x)
end

-- sets the tower for the volcano
local function get_tower(h)
	log"creating tower…"
	for y = 0,h,2 do
		for x = -2,2 do
			for z = -2,2 do
				if not is_hard(x,y,z)
				and math.random(2) == 1 then
					save(hard_nds, z,y,x, true)
				end
			end
		end
	end
end

-- searches for water around it
local function find_water(x,y,z)
	for i = -1,1 do
		for j = -1,1 do
			for k = -1,1 do
				if get(flows.w, z+i,y+j,x+k) then
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
	log"cooling…"
	local toremove,n = {},0
	for i in pairs(flows.l) do
		local pos = minetest.get_position_from_hash(i)
		local z,y,x = pos.z, pos.y, pos.x
		if find_water(x,y,z) then
			n = n+1
			toremove[n] = i
			save(hard_nds, z,y,x, true)
		end
	end
	for i = 1,n do
		flows.l[toremove[i]] = nil
	end
end

-- the opposite liquids
local inverts = {w="l", l="w"}

-- simulates a liquid flowing down
local function flow_lq(y, a)
	log("flowing "..a.."…")
	local lava = a == "l"
	local b = inverts[a]
	save(flows[a], 0,y,0, 8)
	local todo = {{0,y,0}}
	local n = 1
	while n do
		local x,y,z = unpack(todo[n])
		y = y-1
		if not is_hard(x,y,z)
		and not get(flows[b], z,y,x) then
		-- it flows a bit down if air is under it
			local l = 1
			for i = y-1,y-500,-1 do
				if is_hard(x,i,z)
				or get(flows[b], z,i,x) then
					break
				end
				l = l+1
			end
			y = y+1
			if l ~= 1 then
				local l = math.min(l, 20)
				if lava then
				-- cooled lava somehow stops in air maybe because water flows faster
					l = math.floor(l/math.random(1,l)+0.5)
				end
				for i = 1,l do
					save(flows[a], z,y-i,x, 1)
				end
			end
			y = y-l
			if y > bottom_rel then
				local num
				if l == 1 then
				-- liquid flows 4 nodes far if it flow down just 1 node, else 8
					num = 4
				else
					num = 8
				end
				save(flows[a], z,y,x, num)
				table.insert(todo, {x,y,z})
			end
		else
			y = y+1
			local v = get(flows[a], z,y,x) - 1
			if v > 0 then
			-- it spreads if its param is > 1
				for _,d in ipairs{{-1,0}, {2,0}, {-1,1}, {0,-2}} do
					x = x+d[1]
					z = z+d[2]
					if not get(flows[b], z,y,x)
					and not is_hard(x,y,z)
					and (lava or math.max(math.abs(x), math.abs(z)) < width) then
						local cv = get(flows[a], z,y,x)
						if not cv
						or cv < v then
							save(flows[a], z,y,x, v)
							todo[#todo+1] = {x,y,z}
						end
					end
				end
			end
		end

		todo[n] = nil
		n = next(todo)
	end
end

-- creates one
local function spawn_volcano(pos, h)
	width = h*2
--	width = h*8

-- gets the bottom position
	get_bottom(pos.y)

	load_contents()
-- gets environment
	get_solids_around(pos, h)

-- sets the "tower"
	get_tower(h-2)

-- calculates the mountain
	log"calculating mountain:"
	width = h
	local ending
	local lq = "w"
	for y = 1,h,2 do
		if not ending
		and y <= h-2 then
			ending = true
			width = h*2
			--flows = {w={}, l={}}
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

-- reset current liquids and current environment info
	flows = {w={}, l={}}
	exs_solids = {}

	log("setting nodes…")

-- gets informations
	local min, max
	local ps,n = {},0
	for i in pairs(hard_nds) do
		local pos = minetest.get_position_from_hash(i)
		n = n+1
		ps[n] = pos
		if min then
			max.x = math.max(max.x, pos.x)
			max.y = math.max(max.y, pos.y)
			max.z = math.max(max.z, pos.z)
			min.x = math.min(min.x, pos.x)
			min.y = math.min(min.y, pos.y)
			min.z = math.min(min.z, pos.z)
		else
			min = vector.new(pos)
			max = vector.new(pos)
		end
	end

	min = vector.add(min, pos)
	max = vector.add(max, pos)

-- reset current solids
	hard_nds = {}

	collectgarbage()

-- places the mountain
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(min, max)
	local area = VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
	local data = manip:get_data()

	--local occupied = 0

	local z,y,x = pos.z, pos.y, pos.x
	for i = 1,n do
		local p = ps[i]
		local vi = area:index(p.x + x, p.y + y, p.z + z)
		assert(data[vi] == c_air, "vulkan tried to replace non air")
		data[vi] = c_stone
		--if data[p] == c_air then
		--[[
		else
			occupied = occupied+1
		end--]]
	end

	manip:set_data(data)
	manip:write_to_map()

	--[[ just a few nodes in the middle of the tower are affected only when spawning a mountain while being inside sth
	if occupied ~= 0 then
		log(occupied.." node(s) were not set because there's already hard")
	end--]]

	return n
end


local function chatcmd(name)
	if not name
	or name == "" then
		minetest.log("error", "Who???")
		return
	end
	local pos = vector.round(minetest.get_player_by_name(name):getpos())
	log"spawning mountain"
	local count = spawn_volcano(pos, 50)
	log("done, "..count.." stones set")
end

minetest.register_chatcommand('vulkan',{
	description = 'MAUNTEN',
	params = "",
	privs = {server = true},
	func = chatcmd
})





minetest.log("info", string.format("[vulkane] loaded after ca. %.2fs", os.clock() - load_time_start))
