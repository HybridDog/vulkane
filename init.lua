-- current solids
local hard_nds = {}
local flows = {}

-- set a solid
local function set_hard(x,y,z)
	if not y then
	-- x can be a minetest vector
		x,y,z = x.x,x.y,x.z
	end
	hard_nds[x.." "..y.." "..z] = true
end

-- get a solid
local function is_hard(x,y,z)
	if not y then
	-- x can be a minetest vector
		x,y,z = x.x,x.y,x.z
	end
	return hard_nds[x.." "..y.." "..z] or false
end

-- current flowing water
flows.w = {}

-- set flowing water
local function set_water(x,y,z, v)
	flows.w[x.." "..y.." "..z] = v
end

-- get flowing water
local function get_water(x,y,z)
	return flows.w[x.." "..y.." "..z]
end

-- flowing water flows
local function spray_water(x,y,z, v)
	v = v-1
	for _,d in pairs({-1,0}, {2,0}, {-1,1}, {0,-2}) do
		x = x+d[1]
		z = z+d[2]
		local cv = flows.w[x.." "..y.." "..z]
		if cv < v then
			flows.w[x.." "..y.." "..z] = v
		end
	end
end

-- current flowing lava
flows.l = {}

-- set flowing lava
local function set_lava(x,y,z, v)
	flows.l[x.." "..y.." "..z] = v
end

-- get flowing water
local function get_lava(x,y,z)
	return flows.l[x.." "..y.." "..z]
end

-- sets the tower for the volcano
local function get_tower(h)
	for y = 0,h do
		for x = -2,2 do
			for z = -2,2 do
				if math.random(2) == 1 then
					set_hard(x,y,z)
				end
			end
		end
	end
end

local inverts = {w="l", l="w"}
local function flow_lq(y, typ)
	local a = typ
	local b = inverts[a]
	flows[a]["0 "..y.." 0"] = 9
	local todos = {{0,y,0}}
	while todo[1] do
		for n,current in pairs(todo) do
			local x,y,z = unpack(current)
			y = y-1
			local pstr = x.." "..y.." "..z
			if not hard_nds[pstr]
			and not flows[b][pstr] then
			-- it flows down if air is under it
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








