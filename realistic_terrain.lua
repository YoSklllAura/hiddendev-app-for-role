-- procedural terrain generator with hydraulic erosion
-- by mylen
-- generates realistic terrain using perlin noise and simulates water erosion

local terrain = workspace.Terrain
local settings = {
    seed = tick(),
    chunkSize = 128,
    heightScale = 64,
    waterLevel = 32,
    erosionIterations = 150,
    erosionRadius = 3,
    inertia = 0.3,
    sedimentCapacity = 8,
    minSlope = 0.01,
    evaporateSpeed = 0.015,
    depositSpeed = 0.3,
    erodeSpeed = 0.3,
}

local noise = {}
local gradients = {}

-- perlin noise implementation cause roblox doesn't have built-in noise that's good enough
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
    return a + t * (b - a)
end

local function grad(hash, x, y)
    local h = hash % 4
    if h == 0 then return x + y
    elseif h == 1 then return -x + y
    elseif h == 2 then return x - y
    else return -x - y end
end

local function perlin2d(x, y, seed)
    seed = seed or 0
    local xi = math.floor(x) % 256
    local yi = math.floor(y) % 256
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)
    
    local u = fade(xf)
    local v = fade(yf)
    
    -- hash coordinates
    local function hash(i, j)
        return ((i * 374761393 + j * 668265263 + seed) % 256) % 256
    end
    
    local aa = hash(xi, yi)
    local ab = hash(xi, yi + 1)
    local ba = hash(xi + 1, yi)
    local bb = hash(xi + 1, yi + 1)
    
    local x1 = lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u)
    local x2 = lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u)
    
    return lerp(x1, x2, v)
end

-- multi-octave noise for more natural looking terrain
local function fbm(x, y, octaves, persistence, lacunarity, seed)
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    
    for i = 1, octaves do
        total = total + perlin2d(x * frequency, y * frequency, seed + i) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end
    
    return total / maxValue
end

-- heightmap storage
local heightmap = {}
local function getHeight(x, z)
    if not heightmap[x] then return 0 end
    return heightmap[x][z] or 0
end

local function setHeight(x, z, h)
    heightmap[x] = heightmap[x] or {}
    heightmap[x][z] = h
end

-- generate initial heightmap using noise
local function generateHeightmap(size)
    print("generating base heightmap...")
    
    for x = 0, size - 1 do
        for z = 0, size - 1do
            local nx = x / size
            local nz = z / size
            
            -- layer multiple noise octaves
            local height = fbm(nx * 4, nz * 4, 6, 0.5, 2, settings.seed)
            height = height * 0.5 + 0.5
            
            -- add some ridges
            local ridgeNoise = math.abs(perlin2d(nx * 2, nz * 2, settings.seed + 1000))
            height = height * 0.7 + ridgeNoise * 0.3
            
            setHeight(x, z, height * settings.heightScale)
        end
        
        if x % 10 == 0 then
            task.wait()
        end
    end
end

-- bilinear interpolation for smooth height queries
local function getHeightSmooth(x, z)
    local ix = math.floor(x)
    local iz = math.floor(z)
    local fx = x - ix
    local fz = z - iz
    
    local h00 = getHeight(ix, iz)
    local h10 = getHeight(ix + 1, iz)
    local h01 = getHeight(ix, iz + 1)
    local h11 = getHeight(ix + 1, iz + 1)
    
    local h0 = lerp(h00, h10, fx)
    local h1 = lerp(h01, h11, fx)
    
    return lerp(h0, h1, fz)
end

-- calculate gradient at position for erosion
local function calculateGradient(x, z)
    local h = getHeightSmooth(x, z)
    local hx = getHeightSmooth(x + 0.5, z)
    local hz = getHeightSmooth(x, z + 0.5)
    
    return Vector2.new((h - hx) * 2, (h - hz) * 2)
end

-- hydraulic erosion simulation - this is where it gets interesting
local function simulateErosion(size, iterations)
    print("simulating hydraulic erosion...")
    local random = Random.new(settings.seed)
    
    for i = 1, iterations do
        -- spawn random water droplet
        local posX = random:NextNumber(1, size - 2)
        local posZ = random:NextNumber(1, size - 2)
        local dirX = 0
        local dirZ = 0
        local speed = 1
        local water = 1
        local sediment = 0
        
        -- simulate droplet path
        for step = 1, 128 do
            local oldX, oldZ = posX, posZ
            
            -- calculate gradient
            local gradient = calculateGradient(posX, posZ)
            
            -- update direction with inertia
            dirX = dirX * settings.inertia - gradient.X * (1 - settings.inertia)
            dirZ = dirZ * settings.inertia - gradient.Y * (1 - settings.inertia)
            
            local len = math.sqrt(dirX * dirX + dirZ * dirZ)
            if len ~= 0 then
                dirX = dirX / len
                dirZ = dirZ / len
            end
            
            -- move droplet
            posX = posX + dirX
            posZ = posZ + dirZ
            
            if posX < 1 or posX >= size - 1 or posZ < 1 or posZ >= size - 1 then
                break
            end
            
            -- calculate height difference
            local oldHeight = getHeightSmooth(oldX, oldZ)
            local newHeight = getHeightSmooth(posX, posZ)
            local deltaHeight = newHeight - oldHeight
            
            -- calculate sediment capacity
            local capacity = math.max(-deltaHeight, settings.minSlope) * speed * water * settings.sedimentCapacity
            
            -- erode or deposit
            if sediment > capacity or deltaHeight > 0 then
                -- deposit sediment
                local deposit = math.min(sediment, (sediment - capacity) * settings.depositSpeed)
                if deltaHeight > 0 then
                    deposit = math.min(deltaHeight, sediment)
                end
                
                sediment = sediment - deposit
                
                -- deposit around the area
                local ix, iz = math.floor(posX), math.floor(posZ)
                for dx = -1, 1 do
                    for dz = -1, 1 do
                        local wx = ix + dx
                        local wz = iz + dz
                        if wx >= 0 and wx < size and wz >= 0 and wz < size then
                            local dist = math.sqrt(dx*dx + dz*dz)
                            local weight = math.max(0, 1 - dist / 2)
                            setHeight(wx, wz, getHeight(wx, wz) + deposit * weight * 0.25)
                        end
                    end
                end
            else
                -- erode
                local erode = math.min((capacity - sediment) * settings.erodeSpeed, -deltaHeight)
                
                -- erode in radius
                local ix, iz = math.floor(posX), math.floor(posZ)
                for dx = -settings.erosionRadius, settings.erosionRadius do
                    for dz = -settings.erosionRadius, settings.erosionRadius do
                        local wx = ix + dx
                        local wz = iz + dz
                        if wx >= 0 and wx < size and wz >= 0 and wz < size then
                            local dist = math.sqrt(dx*dx + dz*dz)
                            if dist <= settings.erosionRadius then
                                local weight = math.max(0, 1 - dist / settings.erosionRadius)
                                setHeight(wx, wz, getHeight(wx, wz) - erode * weight)
                            end
                        end
                    end
                end
                
                sediment = sediment + erode
            end
            
            -- update speed and evaporate water
            speed = math.sqrt(math.max(0, speed * speed + deltaHeight * 4))
            water = water * (1 - settings.evaporateSpeed)
            
            if water < 0.01 then break end
        end
        
        if i % 10 == 0 then
            task.wait()
        end
    end
end

-- convert heightmap to actual roblox terrain
local function generateTerrain(size)
    print("generating terrain voxels...")
    terrain:Clear()
    
    local region = Region3.new(
        Vector3.new(0, 0, 0),
        Vector3.new(size * 4, settings.heightScale * 2, size * 4)
    )
    region = region:ExpandToGrid(4)
    
    local materials = terrain:ReadVoxels(region, 4)
    local sizeV3 = materials.Size
    
    for x = 0, size - 1 do
        for z = 0, size - 1 do
            local height = getHeight(x, z)
            local worldX = x * 4
            local worldZ = z * 4
            
            -- fill terrain column
            for y = 0, math.floor(height) do
                local vx = math.floor(worldX / 4) + 1
                local vy = math.floor(y / 4) + 1
                local vz = math.floor(worldZ / 4) + 1
                
                if vx >= 1 and vx <= sizeV3.X and vy >= 1 and vy <= sizeV3.Y and vz >= 1 and vz <= sizeV3.Z then
                    local material = Enum.Material.Rock
                    
                    -- add some material variation based on height
                    if y > height - 2 then
                        if height > settings.waterLevel + 8 then
                            material = Enum.Material.Ground
                        else
                            material = Enum.Material.Grass
                        end
                    elseif height > settings.waterLevel + 16 then
                        material = Enum.Material.Rock
                    end
                    
                    materials[vx][vy][vz] = material
                end
            end
        end
        
        if x % 4 == 0 then
            task.wait()
        end
    end
    
    terrain:WriteVoxels(region, 4, materials, materials)
    print("terrain generation complete!")
end

-- main execution
local function main()
    print("starting terrain generation by mylen")
    print("this might take a minute...")
    
    generateHeightmap(settings.chunkSize)
    simulateErosion(settings.chunkSize, settings.erosionIterations)
    generateTerrain(settings.chunkSize)
    
    print("all done!")
end

main()
