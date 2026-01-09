-- dungeon generator with pathfinding system
-- mylen

local RoomTemplate = {}
RoomTemplate.__index = RoomTemplate

function RoomTemplate.new(width, height, roomType)
    local self = setmetatable({}, RoomTemplate)
    self.width = width
    self.height = height
    self.roomType = roomType
    self.tiles = {}
    self.doors = {}
    self.enemies = {}
    self.loot = {}
    
    for x = 1, width do
        self.tiles[x] = {}
        for y = 1, height do
            self.tiles[x][y] = 0
        end
    end
    
    return self
end

function RoomTemplate:setTile(x, y, value)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.tiles[x][y] = value
    end
end

function RoomTemplate:getTile(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        return self.tiles[x][y]
    end
    return -1
end

function RoomTemplate:addDoor(x, y, direction)
    table.insert(self.doors, {x = x, y = y, direction = direction})
end

function RoomTemplate:generateBasicRoom()
    for x = 1, self.width do
        for y = 1, self.height do
            if x == 1 or x == self.width or y == 1 or y == self.height then
                self:setTile(x, y, 1)
            else
                self:setTile(x, y, 0)
            end
        end
    end
end

function RoomTemplate:generatePillarRoom()
    self:generateBasicRoom()
    
    local pillarPositions = {
        {math.floor(self.width * 0.3), math.floor(self.height * 0.3)},
        {math.floor(self.width * 0.7), math.floor(self.height * 0.3)},
        {math.floor(self.width * 0.3), math.floor(self.height * 0.7)},
        {math.floor(self.width * 0.7), math.floor(self.height * 0.7)},
    }
    
    for _, pos in ipairs(pillarPositions) do
        self:setTile(pos[1], pos[2], 1)
        self:setTile(pos[1] + 1, pos[2], 1)
        self:setTile(pos[1], pos[2] + 1, 1)
        self:setTile(pos[1] + 1, pos[2] + 1, 1)
    end
end

function RoomTemplate:generateMazeRoom()
    self:generateBasicRoom()
    
    local seed = tick()
    local rand = Random.new(seed)
    
    for x = 3, self.width - 2, 2 do
        for y = 3, self.height - 2, 2 do
            self:setTile(x, y, 1)
            
            local dirs = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
            local chosen = dirs[rand:NextInteger(1, 4)]
            self:setTile(x + chosen[1], y + chosen[2], 1)
        end
    end
end

local DungeonRoom = {}
DungeonRoom.__index = DungeonRoom

function DungeonRoom.new(x, y, template)
    local self = setmetatable({}, DungeonRoom)
    self.x = x
    self.y = y
    self.template = template
    self.connected = {}
    self.visited = false
    self.distanceFromStart = math.huge
    
    return self
end

function DungeonRoom:getCenter()
    return {
        x = self.x + math.floor(self.template.width / 2),
        y = self.y + math.floor(self.template.height / 2)
    }
end

function DungeonRoom:connectTo(other)
    table.insert(self.connected, other)
    table.insert(other.connected, self)
end

function DungeonRoom:isConnectedTo(other)
    for _, room in ipairs(self.connected) do
        if room == other then
            return true
        end
    end
    return false
end

local Pathfinder = {}
Pathfinder.__index = Pathfinder

function Pathfinder.new(dungeon)
    local self = setmetatable({}, Pathfinder)
    self.dungeon = dungeon
    return self
end

function Pathfinder:heuristic(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

function Pathfinder:getNeighbors(pos)
    local neighbors = {}
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    for _, dir in ipairs(directions) do
        local nx = pos.x + dir[1]
        local ny = pos.y + dir[2]
        
        if self.dungeon:isWalkable(nx, ny) then
            table.insert(neighbors, {x = nx, y = ny})
        end
    end
    
    return neighbors
end

function Pathfinder:findPath(start, goal)
    local openSet = {start}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    local function hashPos(pos)
        return pos.x * 10000 + pos.y
    end
    
    gScore[hashPos(start)] = 0
    fScore[hashPos(start)] = self:heuristic(start, goal)
    
    while #openSet > 0 do
        local current = nil
        local lowestF = math.huge
        local lowestIndex = 1
        
        for i, pos in ipairs(openSet) do
            local f = fScore[hashPos(pos)] or math.huge
            if f < lowestF then
                lowestF = f
                current = pos
                lowestIndex = i
            end
        end
        
        if current.x == goal.x and current.y == goal.y then
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = cameFrom[hashPos(current)]
            end
            return path
        end
        
        table.remove(openSet, lowestIndex)
        
        for _, neighbor in ipairs(self:getNeighbors(current)) do
            local tentativeG = (gScore[hashPos(current)] or math.huge) + 1
            
            if tentativeG < (gScore[hashPos(neighbor)] or math.huge) then
                cameFrom[hashPos(neighbor)] = current
                gScore[hashPos(neighbor)] = tentativeG
                fScore[hashPos(neighbor)] = tentativeG + self:heuristic(neighbor, goal)
                
                local inOpen = false
                for _, pos in ipairs(openSet) do
                    if pos.x == neighbor.x and pos.y == neighbor.y then
                        inOpen = true
                        break
                    end
                end
                
                if not inOpen then
                    table.insert(openSet, neighbor)
                end
            end
        end
    end
    
    return nil
end

local Dungeon = {}
Dungeon.__index = Dungeon

function Dungeon.new(width, height, seed)
    local self = setmetatable({}, Dungeon)
    self.width = width
    self.height = height
    self.seed = seed or tick()
    self.rand = Random.new(self.seed)
    self.grid = {}
    self.rooms = {}
    self.corridors = {}
    
    for x = 1, width do
        self.grid[x] = {}
        for y = 1, height do
            self.grid[x][y] = 1
        end
    end
    
    return self
end

function Dungeon:setTile(x, y, value)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.grid[x][y] = value
    end
end

function Dungeon:getTile(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        return self.grid[x][y]
    end
    return 1
end

function Dungeon:isWalkable(x, y)
    return self:getTile(x, y) == 0
end

function Dungeon:canPlaceRoom(x, y, template)
    if x < 1 or y < 1 then return false end
    if x + template.width > self.width then return false end
    if y + template.height > self.height then return false end
    
    for rx = x, x + template.width do
        for ry = y, y + template.height do
            if self:getTile(rx, ry) == 0 then
                return false
            end
        end
    end
    
    return true
end

function Dungeon:placeRoom(room)
    for x = 1, room.template.width do
        for y = 1, room.template.height do
            local tileValue = room.template:getTile(x, y)
            self:setTile(room.x + x - 1, room.y + y - 1, tileValue)
        end
    end
    
    table.insert(self.rooms, room)
end

function Dungeon:createCorridor(room1, room2)
    local c1 = room1:getCenter()
    local c2 = room2:getCenter()
    
    local currentX = c1.x
    local currentY = c1.y
    
    while currentX ~= c2.x do
        self:setTile(currentX, currentY, 0)
        self:setTile(currentX, currentY - 1, 0)
        self:setTile(currentX, currentY + 1, 0)
        
        if currentX < c2.x then
            currentX = currentX + 1
        else
            currentX = currentX - 1
        end
    end
    
    while currentY ~= c2.y do
        self:setTile(currentX, currentY, 0)
        self:setTile(currentX - 1, currentY, 0)
        self:setTile(currentX + 1, currentY, 0)
        
        if currentY < c2.y then
            currentY = currentY + 1
        else
            currentY = currentY - 1
        end
    end
    
    table.insert(self.corridors, {room1, room2})
end

function Dungeon:generate(numRooms)
    local roomTypes = {"basic", "pillar", "maze"}
    local attempts = 0
    local maxAttempts = numRooms * 10
    
    while #self.rooms < numRooms and attempts < maxAttempts do
        attempts = attempts + 1
        
        local width = self.rand:NextInteger(8, 16)
        local height = self.rand:NextInteger(8, 16)
        local x = self.rand:NextInteger(2, self.width - width - 2)
        local y = self.rand:NextInteger(2, self.height - height - 2)
        
        local roomType = roomTypes[self.rand:NextInteger(1, #roomTypes)]
        local template = RoomTemplate.new(width, height, roomType)
        
        if roomType == "basic" then
            template:generateBasicRoom()
        elseif roomType == "pillar" then
            template:generatePillarRoom()
        elseif roomType == "maze" then
            template:generateMazeRoom()
        end
        
        if self:canPlaceRoom(x, y, template) then
            local room = DungeonRoom.new(x, y, template)
            self:placeRoom(room)
        end
    end
    
    for i = 1, #self.rooms - 1 do
        local room1 = self.rooms[i]
        local room2 = self.rooms[i + 1]
        self:createCorridor(room1, room2)
        room1:connectTo(room2)
    end
    
    local extraConnections = math.floor(#self.rooms * 0.3)
    for i = 1, extraConnections do
        local r1 = self.rooms[self.rand:NextInteger(1, #self.rooms)]
        local r2 = self.rooms[self.rand:NextInteger(1, #self.rooms)]
        
        if r1 ~= r2 and not r1:isConnectedTo(r2) then
            self:createCorridor(r1, r2)
            r1:connectTo(r2)
        end
    end
end

function Dungeon:calculateDistances()
    if #self.rooms == 0 then return end
    
    local startRoom = self.rooms[1]
    startRoom.distanceFromStart = 0
    startRoom.visited = true
    
    local queue = {startRoom}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        
        for _, neighbor in ipairs(current.connected) do
            if not neighbor.visited then
                neighbor.visited = true
                neighbor.distanceFromStart = current.distanceFromStart + 1
                table.insert(queue, neighbor)
            end
        end
    end
end

function Dungeon:findFarthestRoom()
    local farthest = nil
    local maxDist = -1
    
    for _, room in ipairs(self.rooms) do
        if room.distanceFromStart > maxDist then
            maxDist = room.distanceFromStart
            farthest = room
        end
    end
    
    return farthest
end

function Dungeon:visualize()
    print("dungeon layout:")
    print(string.rep("=", self.width + 2))
    
    for y = 1, self.height do
        local line = "|"
        for x = 1, self.width do
            local tile = self:getTile(x, y)
            if tile == 1 then
                line = line .. "#"
            else
                line = line .. " "
            end
        end
        print(line .. "|")
    end
    
    print(string.rep("=", self.width + 2))
    print(string.format("rooms: %d, corridors: %d", #self.rooms, #self.corridors))
end

function Dungeon:exportToString()
    local result = ""
    
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self:getTile(x, y)
            result = result .. (tile == 1 and "#" or " ")
        end
        result = result .. "\n"
    end
    
    return result
end

local dungeon = Dungeon.new(100, 100, tick())
dungeon:generate(12)
dungeon:calculateDistances()

local startRoom = dungeon.rooms[1]
local endRoom = dungeon:findFarthestRoom()

print("generated dungeon with proper OOP structure")
print(string.format("start room at (%d, %d)", startRoom.x, startRoom.y))
print(string.format("end room at (%d, %d) - distance: %d", 
    endRoom.x, endRoom.y, endRoom.distanceFromStart))

dungeon:visualize()

local pathfinder = Pathfinder.new(dungeon)
local startPos = startRoom:getCenter()
local endPos = endRoom:getCenter()
local path = pathfinder:findPath(startPos, endPos)

if path then
    print(string.format("found path with %d steps", #path))
    
    for _, pos in ipairs(path) do
        dungeon:setTile(pos.x, pos.y, 2)
    end
else
    print("no path found between rooms")
end

print("\nfinal stats:")
print("room types:")
local typeCounts = {}
for _, room in ipairs(dungeon.rooms) do
    typeCounts[room.template.roomType] = (typeCounts[room.template.roomType] or 0) + 1
end
for roomType, count in pairs(typeCounts) do
    print(string.format("  %s: %d", roomType, count))
end

local dungeonString = dungeon:exportToString()
print("\nexport ready")
