-- dynamic weather system with realistic particle effects and environmental changes
-- created by mylen
-- features: rain, snow, thunderstorms, fog, wind simulation, and smooth transitions

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- weather system class handles all weather states and transitions
local WeatherSystem = {}
WeatherSystem.__index = WeatherSystem

-- initialize a new weather system instance with default configuration
function WeatherSystem.new()
    local self = setmetatable({}, WeatherSystem)
    
    -- current active weather state
    self.currentWeather = "clear"
    
    -- whether the system is currently transitioning between weather states
    self.isTransitioning = false
    
    -- duration of weather state transitions in seconds
    self.transitionDuration = 5
    
    -- random number generator seeded with current time for weather variation
    self.random = Random.new(tick())
    
    -- stores all active particle emitters for cleanup and management
    self.activeEmitters = {}
    
    -- tracks lightning strike timing and frequency
    self.lastLightningTime = 0
    self.lightningInterval = 3
    
    -- wind force magnitude affects how objects move in weather
    self.windStrength = 0
    self.windDirection = Vector3.new(1, 0, 0)
    
    -- collection of sound effects for different weather types
    self.sounds = {}
    
    -- cloud coverage affects lighting ambient values
    self.cloudCoverage = 0
    
    -- precipitation intensity from 0 to 1 controls particle emission rates
    self.precipitationIntensity = 0
    
    -- temperature affects whether precipitation is rain or snow
    self.temperature = 20
    
    -- fog density for atmospheric effects
    self.fogDensity = 0
    
    -- initialize atmospheric effects in lighting service
    self:initializeLighting()
    
    -- set up audio components for weather ambience
    self:initializeSounds()
    
    return self
end

-- configure initial lighting properties and create atmosphere instance
function WeatherSystem:initializeLighting()
    -- create atmosphere for realistic sky rendering
    if not Lighting:FindFirstChild("Atmosphere") then
        local atmosphere = Instance.new("Atmosphere")
        atmosphere.Density = 0.3
        atmosphere.Offset = 0.25
        atmosphere.Color = Color3.fromRGB(199, 199, 199)
        atmosphere.Decay = Color3.fromRGB(106, 112, 125)
        atmosphere.Glare = 0
        atmosphere.Haze = 0
        atmosphere.Parent = Lighting
    end
    
    -- create clouds for dynamic sky coverage
    if not Lighting:FindFirstChild("Clouds") then
        local clouds = Instance.new("Clouds")
        clouds.Cover = 0.5
        clouds.Density = 0.5
        clouds.Color = Color3.fromRGB(255, 255, 255)
        clouds.Parent = Lighting
    end
    
    -- store references to lighting components for manipulation
    self.atmosphere = Lighting:FindFirstChild("Atmosphere")
    self.clouds = Lighting:FindFirstChild("Clouds")
    
    -- set baseline lighting properties
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient = Color3.fromRGB(0, 0, 0)
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
end

-- create and configure sound instances for weather ambience
function WeatherSystem:initializeSounds()
    local soundFolder = Instance.new("Folder")
    soundFolder.Name = "WeatherSounds"
    soundFolder.Parent = workspace
    
    -- rain sound provides base ambience for rainy weather
    local rainSound = Instance.new("Sound")
    rainSound.Name = "RainSound"
    rainSound.SoundId = "rbxassetid://1837829565"
    rainSound.Volume = 0
    rainSound.Looped = true
    rainSound.Parent = soundFolder
    rainSound:Play()
    self.sounds.rain = rainSound
    
    -- thunder sound plays during lightning strikes
    local thunderSound = Instance.new("Sound")
    thunderSound.Name = "ThunderSound"
    thunderSound.SoundId = "rbxassetid://2691111892"
    thunderSound.Volume = 0.5
    thunderSound.Parent = soundFolder
    self.sounds.thunder = thunderSound
    
    -- wind sound provides ambient noise during windy conditions
    local windSound = Instance.new("Sound")
    windSound.Name = "WindSound"
    windSound.SoundId = "rbxassetid://2691111892"
    windSound.Volume = 0
    windSound.Looped = true
    windSound.Parent = soundFolder
    windSound:Play()
    self.sounds.wind = windSound
end

-- create particle emitter for rain with realistic falling behavior
function WeatherSystem:createRainEmitter(parent)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "RainEmitter"
    
    -- emission rate determines how many raindrops spawn per second
    emitter.Rate = 100
    
    -- lifetime controls how long each raindrop exists before being destroyed
    emitter.Lifetime = NumberRange.new(2, 3)
    
    -- speed affects how fast raindrops fall
    emitter.Speed = NumberRange.new(50, 60)
    
    -- spread angle creates natural variation in rain direction
    emitter.SpreadAngle = Vector2.new(5, 5)
    
    -- acceleration simulates gravity pulling rain downward
    emitter.Acceleration = Vector3.new(0, -50, 0)
    
    -- texture gives raindrops their visual appearance
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    
    -- size changes over raindrop lifetime for realistic effect
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    
    -- transparency fades raindrops in and out smoothly
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    
    -- color tints raindrops to look like water
    emitter.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
    
    -- lighting properties affect how rain interacts with scene lighting
    emitter.LightEmission = 0.2
    emitter.LightInfluence = 1
    
    emitter.Parent = parent
    return emitter
end

-- create particle emitter for snow with gentle falling pattern
function WeatherSystem:createSnowEmitter(parent)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "SnowEmitter"
    
    -- snow falls slower than rain for realistic effect
    emitter.Rate = 50
    emitter.Lifetime = NumberRange.new(5, 8)
    emitter.Speed = NumberRange.new(5, 10)
    emitter.SpreadAngle = Vector2.new(15, 15)
    
    -- gentle downward acceleration simulates snow drifting
    emitter.Acceleration = Vector3.new(0, -2, 0)
    
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    
    -- snowflakes are larger than raindrops
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0.3)
    })
    
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    
    -- pure white color for snow
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    
    emitter.LightEmission = 0.5
    emitter.LightInfluence = 1
    
    -- rotation creates tumbling snowflake effect
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-50, 50)
    
    emitter.Parent = parent
    return emitter
end

-- spawn particle emitters across the map at player positions
function WeatherSystem:spawnWeatherParticles(weatherType)
    -- clear any existing particle emitters before spawning new ones
    self:clearParticles()
    
    -- iterate through all players to create localized weather effects
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            
            -- create attachment point above player for particles to emit from
            local attachment = Instance.new("Attachment")
            attachment.Name = "WeatherAttachment"
            attachment.Position = Vector3.new(0, 20, 0)
            attachment.Parent = hrp
            
            local emitter
            
            -- spawn appropriate particle type based on weather and temperature
            if weatherType == "rain" or weatherType == "thunderstorm" then
                emitter = self:createRainEmitter(attachment)
                
                -- thunderstorms have heavier rain
                if weatherType == "thunderstorm" then
                    emitter.Rate = 150
                end
            elseif weatherType == "snow" then
                emitter = self:createSnowEmitter(attachment)
            end
            
            -- track emitters for later cleanup
            if emitter then
                table.insert(self.activeEmitters, {
                    emitter = emitter,
                    attachment = attachment,
                    player = player
                })
            end
        end
    end
end

-- remove all active particle emitters from the scene
function WeatherSystem:clearParticles()
    for _, data in ipairs(self.activeEmitters) do
        if data.emitter then
            data.emitter:Destroy()
        end
        if data.attachment then
            data.attachment:Destroy()
        end
    end
    
    -- reset emitter tracking table
    self.activeEmitters = {}
end

-- create realistic lightning strike with light and sound effects
function WeatherSystem:createLightningStrike()
    -- only strike during thunderstorms
    if self.currentWeather ~= "thunderstorm" then return end
    
    -- enforce minimum time between strikes
    local currentTime = tick()
    if currentTime - self.lastLightningTime < self.lightningInterval then return end
    
    self.lastLightningTime = currentTime
    
    -- randomize next strike timing for natural variation
    self.lightningInterval = self.random:NextNumber(2, 8)
    
    -- create brief bright flash in sky lighting
    local originalBrightness = Lighting.Brightness
    local originalOutdoorAmbient = Lighting.OutdoorAmbient
    
    -- instant bright flash
    Lighting.Brightness = 5
    Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 255)
    
    -- play thunder sound effect with slight delay for realism
    task.delay(self.random:NextNumber(0.1, 0.5), function()
        self.sounds.thunder:Play()
    end)
    
    -- fade lighting back to normal over short duration
    task.delay(0.1, function()
        local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        local brightnessTween = TweenService:Create(Lighting, fadeInfo, {
            Brightness = originalBrightness
        })
        brightnessTween:Play()
        
        local ambientTween = TweenService:Create(Lighting, fadeInfo, {
            OutdoorAmbient = originalOutdoorAmbient
        })
        ambientTween:Play()
    end)
    
    -- randomly strike and damage objects in workspace
    local strikeChance = self.random:NextNumber(0, 1)
    if strikeChance > 0.7 then
        self:strikeRandomObject()
    end
end

-- find and damage a random object in the workspace with lightning
function WeatherSystem:strikeRandomObject()
    local descendants = workspace:GetDescendants()
    local validTargets = {}
    
    -- filter for parts that can be struck by lightning
    for _, obj in ipairs(descendants) do
        if obj:IsA("BasePart") and obj.Parent ~= workspace.Terrain then
            -- prioritize tall objects
            if obj.Position.Y > 10 then
                table.insert(validTargets, obj)
            end
        end
    end
    
    -- select random target from valid options
    if #validTargets > 0 then
        local target = validTargets[self.random:NextInteger(1, #validTargets)]
        
        -- create visual lightning bolt effect
        local bolt = Instance.new("Part")
        bolt.Name = "LightningBolt"
        bolt.Size = Vector3.new(0.5, 100, 0.5)
        bolt.Material = Enum.Material.Neon
        bolt.BrickColor = BrickColor.new("Electric blue")
        bolt.Anchored = true
        bolt.CanCollide = false
        
        -- position bolt from sky to target
        bolt.CFrame = CFrame.new(
            target.Position + Vector3.new(0, 50, 0),
            target.Position
        ) * CFrame.new(0, -50, 0)
        
        bolt.Parent = workspace
        
        -- create light source at strike point
        local light = Instance.new("PointLight")
        light.Brightness = 5
        light.Range = 50
        light.Color = Color3.fromRGB(200, 220, 255)
        light.Parent = bolt
        
        -- apply damage or effect to struck object
        if target:FindFirstChild("Humanoid") then
            -- damage players or NPCs
            target.Humanoid:TakeDamage(20)
        elseif target:IsA("BasePart") then
            -- char or discolor parts
            target.BrickColor = BrickColor.new("Black")
            
            -- create small explosion effect
            local explosion = Instance.new("Explosion")
            explosion.Position = target.Position
            explosion.BlastRadius = 10
            explosion.BlastPressure = 100000
            explosion.Parent = workspace
        end
        
        -- remove lightning bolt after brief display
        Debris:AddItem(bolt, 0.2)
    end
end

-- smoothly transition between weather states over time
function WeatherSystem:transitionToWeather(weatherType)
    if self.isTransitioning then return end
    
    self.isTransitioning = true
    self.currentWeather = weatherType
    
    print("transitioning to weather:", weatherType)
    
    -- define target values for each weather type
    local weatherConfigs = {
        clear = {
            cloudCoverage = 0.2,
            fogDensity = 0,
            brightness = 2,
            outdoorAmbient = Color3.fromRGB(128, 128, 128),
            precipitation = 0,
            windStrength = 5,
            temperature = 25,
            rainVolume = 0,
            windVolume = 0.1,
        },
        cloudy = {
            cloudCoverage = 0.7,
            fogDensity = 0,
            brightness = 1.5,
            outdoorAmbient = Color3.fromRGB(100, 100, 100),
            precipitation = 0,
            windStrength = 15,
            temperature = 20,
            rainVolume = 0,
            windVolume = 0.3,
        },
        rain = {
            cloudCoverage = 0.9,
            fogDensity = 0.1,
            brightness = 1,
            outdoorAmbient = Color3.fromRGB(80, 85, 90),
            precipitation = 0.6,
            windStrength = 20,
            temperature = 15,
            rainVolume = 0.5,
            windVolume = 0.4,
        },
        thunderstorm = {
            cloudCoverage = 1,
            fogDensity = 0.15,
            brightness = 0.8,
            outdoorAmbient = Color3.fromRGB(60, 60, 70),
            precipitation = 0.9,
            windStrength = 35,
            temperature = 12,
            rainVolume = 0.8,
            windVolume = 0.6,
        },
        snow = {
            cloudCoverage = 0.85,
            fogDensity = 0.2,
            brightness = 1.8,
            outdoorAmbient = Color3.fromRGB(200, 210, 220),
            precipitation = 0.5,
            windStrength = 10,
            temperature = -5,
            rainVolume = 0,
            windVolume = 0.3,
        },
        fog = {
            cloudCoverage = 0.6,
            fogDensity = 0.8,
            brightness = 1.2,
            outdoorAmbient = Color3.fromRGB(150, 150, 150),
            precipitation = 0,
            windStrength = 3,
            temperature = 18,
            rainVolume = 0,
            windVolume = 0.1,
        },
    }
    
    local config = weatherConfigs[weatherType]
    if not config then
        warn("unknown weather type:", weatherType)
        self.isTransitioning = false
        return
    end
    
    -- create tween for smooth value transitions
    local tweenInfo = TweenInfo.new(
        self.transitionDuration,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut
    )
    
    -- tween lighting properties
    local lightingTween = TweenService:Create(Lighting, tweenInfo, {
        Brightness = config.brightness,
        OutdoorAmbient = config.outdoorAmbient,
        FogEnd = 1000 - (config.fogDensity * 900),
        FogStart = 0,
    })
    lightingTween:Play()
    
    -- tween cloud coverage
    if self.clouds then
        local cloudTween = TweenService:Create(self.clouds, tweenInfo, {
            Cover = config.cloudCoverage,
            Density = config.cloudCoverage * 0.8,
        })
        cloudTween:Play()
    end
    
    -- tween sound volumes
    local rainTween = TweenService:Create(self.sounds.rain, tweenInfo, {
        Volume = config.rainVolume,
    })
    rainTween:Play()
    
    local windTween = TweenService:Create(self.sounds.wind, tweenInfo, {
        Volume = config.windVolume,
    })
    windTween:Play()
    
    -- update internal state values
    self.cloudCoverage = config.cloudCoverage
    self.fogDensity = config.fogDensity
    self.precipitationIntensity = config.precipitation
    self.windStrength = config.windStrength
    self.temperature = config.temperature
    
    -- spawn appropriate particles based on precipitation
    if config.precipitation > 0 then
        self:spawnWeatherParticles(weatherType)
    else
        self:clearParticles()
    end
    
    -- wait for transition to complete
    lightingTween.Completed:Wait()
    self.isTransitioning = false
end

-- randomly select next weather state based on current conditions
function WeatherSystem:getRandomWeather()
    local weatherTypes = {"clear", "cloudy", "rain", "thunderstorm", "snow", "fog"}
    local weights = {}
    
    -- weight selection based on current weather for realistic progression
    if self.currentWeather == "clear" then
        weights = {clear = 30, cloudy = 40, rain = 20, thunderstorm = 5, snow = 3, fog = 2}
    elseif self.currentWeather == "cloudy" then
        weights = {clear = 25, cloudy = 20, rain = 35, thunderstorm = 10, snow = 5, fog = 5}
    elseif self.currentWeather == "rain" then
        weights = {clear = 15, cloudy = 30, rain = 20, thunderstorm = 25, snow = 5, fog = 5}
    elseif self.currentWeather == "thunderstorm" then
        weights = {clear = 10, cloudy = 20, rain = 40, thunderstorm = 15, snow = 5, fog = 10}
    elseif self.currentWeather == "snow" then
        weights = {clear = 20, cloudy = 25, rain = 5, thunderstorm = 3, snow = 35, fog = 12}
    elseif self.currentWeather == "fog" then
        weights = {clear = 30, cloudy = 30, rain = 15, thunderstorm = 5, snow = 10, fog = 10}
    end
    
    -- calculate total weight for random selection
    local totalWeight = 0
    for _, weight in pairs(weights) do
        totalWeight = totalWeight + weight
    end
    
    -- select random weather based on weights
    local random = self.random:NextNumber(0, totalWeight)
    local cumulative = 0
    
    for weatherType, weight in pairs(weights) do
        cumulative = cumulative + weight
        if random <= cumulative then
            return weatherType
        end
    end
    
    return "clear"
end

-- update weather particles to follow players as they move
function WeatherSystem:updateParticlePositions()
    for i = #self.activeEmitters, 1, -1 do
        local data = self.activeEmitters[i]
        
        -- remove emitters for disconnected players
        if not data.player.Parent or not data.player.Character then
            if data.emitter then data.emitter:Destroy() end
            if data.attachment then data.attachment:Destroy() end
            table.remove(self.activeEmitters, i)
        else
            -- update attachment position to follow player
            local character = data.player.Character
            local hrp = character:FindFirstChild("HumanoidRootPart")
            
            if hrp and data.attachment then
                data.attachment.WorldPosition = hrp.Position + Vector3.new(0, 20, 0)
            end
        end
    end
end

-- apply wind force to loose objects in the world
function WeatherSystem:applyWindForces()
    -- only apply wind if strength is significant
    if self.windStrength < 5 then return end
    
    -- randomly vary wind direction over time
    local timeOffset = tick() * 0.1
    self.windDirection = Vector3.new(
        math.sin(timeOffset) * self.windStrength,
        0,
        math.cos(timeOffset) * self.windStrength
    )
    
    -- find all unanchored parts that can be affected by wind
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.Anchored and obj:FindFirstChild("BodyVelocity") == nil then
            -- only affect lightweight objects
            if obj.AssemblyMass < 50 then
                -- apply force proportional to wind strength and object mass
                local force = self.windDirection * (self.windStrength / obj.AssemblyMass) * 0.5
                obj.AssemblyLinearVelocity = obj.AssemblyLinearVelocity + force
            end
        end
    end
end

-- main update loop handles all weather system logic
function WeatherSystem:update(deltaTime)
    -- trigger lightning strikes during thunderstorms
    if self.currentWeather == "thunderstorm" then
        self:createLightningStrike()
    end
    
    -- update particle emitter positions to follow players
    self:updateParticlePositions()
    
    -- apply environmental wind forces to objects
    self:applyWindForces()
end

-- start automatic weather cycling with random intervals
function WeatherSystem:startWeatherCycle(minDuration, maxDuration)
    minDuration = minDuration or 60
    maxDuration = maxDuration or 180
    
    local function cycle()
        while true do
            -- wait random duration before changing weather
            local waitTime = self.random:NextNumber(minDuration, maxDuration)
            task.wait(waitTime)
            
            -- transition to new random weather
            local nextWeather = self:getRandomWeather()
            self:transitionToWeather(nextWeather)
        end
    end
    
    -- run weather cycle in separate thread
    task.spawn(cycle)
end

-- initialize weather system and begin operation
local weatherSystem = WeatherSystem.new()

-- start with clear weather
weatherSystem:transitionToWeather("clear")

-- begin automatic weather cycling every 1-3 minutes
weatherSystem:startWeatherCycle(60, 180)

-- connect update loop to run every frame
RunService.Heartbeat:Connect(function(deltaTime)
    weatherSystem:update(deltaTime)
end)

-- handle new players joining to add weather particles
game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        -- wait for character to fully load
        task.wait(1)
        
        -- respawn weather particles for new player
        if weatherSystem.precipitationIntensity > 0 then
            weatherSystem:spawnWeatherParticles(weatherSystem.currentWeather)
        end
    end)
end)

print("weather system initialized by mylen")
print("current weather:", weatherSystem.currentWeather)
print("automatic cycling enabled")
